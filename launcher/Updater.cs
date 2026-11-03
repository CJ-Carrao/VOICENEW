using System.Diagnostics;
using System.IO.Compression;
using System.Security.Cryptography;
using System.Text.Json;

namespace VoiceNew;

sealed class Settings
{
    public static string Root => Environment.GetEnvironmentVariable("VOICENEW_DATA_DIR") ?? Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "VOICENEW-Data");
    public static readonly JsonSerializerOptions Json = new() { WriteIndented = true, PropertyNameCaseInsensitive = true, PropertyNamingPolicy = JsonNamingPolicy.CamelCase };
    public string GameExe { get; set; } = "";
    public string Version { get; set; } = "";
    public bool Automatic { get; set; } = true;
    public static Settings Load()
    {
        var path = Path.Combine(Root, "settings.json");
        if (!File.Exists(path)) return new();
        try { return JsonSerializer.Deserialize<Settings>(File.ReadAllText(path), Json) ?? new(); }
        catch { return new(); }
    }
    public static void Save(Settings value)
    {
        Directory.CreateDirectory(Root);
        var temp = Path.Combine(Root, "settings-" + Guid.NewGuid().ToString("N") + ".tmp");
        File.WriteAllText(temp, JsonSerializer.Serialize(value, Json));
        File.Move(temp, Path.Combine(Root, "settings.json"), true);
    }
}

sealed record GameRelease(string GameVersion, string PackageUrl, string Sha256, string ExePath, string ExeSha256, long Size);

static class Updater
{
    public const string Repository = "https://github.com/CJ-Carrao/VOICENEW";
    public const string FeedUrl = Repository + "/releases/download/componentes-v041/";
    const string DownloadPrefix = Repository + "/releases/download/";
    static readonly HttpClient Http = CreateHttp();
    static HttpClient CreateHttp()
    {
        var client = new HttpClient { Timeout = TimeSpan.FromMinutes(30) };
        client.DefaultRequestHeaders.UserAgent.ParseAdd("VOICENEW-Launcher/0.4.1");
        return client;
    }
    public static bool IsNewer(string incoming, string current)
    {
        if (!Version.TryParse(incoming.TrimStart('v'), out var next)) throw new Exception("Versão recebida inválida.");
        return !Version.TryParse(current.TrimStart('v'), out var installed) || next > installed;
    }
    public static void ValidateRelease(GameRelease release)
    {
        _ = IsNewer(release.GameVersion, "0.0.0");
        if (!release.PackageUrl.StartsWith(DownloadPrefix, StringComparison.Ordinal) || !Uri.TryCreate(release.PackageUrl, UriKind.Absolute, out var uri) || uri.Host != "github.com" || uri.Scheme != "https") throw new Exception("Origem de atualização inválida.");
        foreach (var hash in new[] { release.Sha256, release.ExeSha256 })
            if (hash == null || hash.Length != 64 || !hash.All(Uri.IsHexDigit)) throw new Exception("Verificação de integridade inválida.");
        _ = SafePath(Path.GetTempPath(), release.ExePath);
        if (!release.ExePath.EndsWith(".exe", StringComparison.OrdinalIgnoreCase) || release.Size <= 0 || release.Size > 2L * 1024 * 1024 * 1024) throw new Exception("Pacote inválido.");
    }
    public static async Task<GameRelease> FetchRelease()
    {
        var data = await Http.GetByteArrayAsync(FeedUrl + "game-update.json");
        if (data.Length > 16384) throw new Exception("Manifesto grande demais.");
        var manifest = JsonSerializer.Deserialize<GameRelease>(data, Settings.Json) ?? throw new Exception("Manifesto inválido.");
        ValidateRelease(manifest); return manifest;
    }
    public static bool IsGameRunning(Settings settings)
    {
        var current = Path.GetFileNameWithoutExtension(settings.GameExe);
        foreach (var process in Process.GetProcesses())
        {
            using (process)
            {
                try
                {
                    var name = process.ProcessName;
                    if ((!string.IsNullOrEmpty(current) && name.Equals(current, StringComparison.OrdinalIgnoreCase)) || name.StartsWith("LAVOICE", StringComparison.OrdinalIgnoreCase) || name.StartsWith("VOICENEW-H6", StringComparison.OrdinalIgnoreCase)) return true;
                }
                catch (InvalidOperationException) { }
            }
        }
        return false;
    }
    public static async Task VerifyHash(string file, string expected)
    {
        await using var stream = File.OpenRead(file);
        var hash = Convert.ToHexString(await SHA256.HashDataAsync(stream));
        if (!hash.Equals(expected, StringComparison.OrdinalIgnoreCase)) throw new Exception("O download está incompleto ou foi alterado. A versão atual foi preservada.");
    }
    public static string SafePath(string target, string entry)
    {
        if (string.IsNullOrWhiteSpace(entry)) throw new Exception("Caminho vazio no pacote.");
        string root = Path.GetFullPath(target).TrimEnd(Path.DirectorySeparatorChar) + Path.DirectorySeparatorChar;
        string normalized = entry.Replace('\\', '/');
        string path = Path.GetFullPath(Path.Combine(target, normalized));
        if (!path.StartsWith(root, StringComparison.OrdinalIgnoreCase) || normalized.Contains(':')) throw new Exception("Caminho inválido dentro do pacote.");
        return path;
    }
    public static void Extract(string archive, string target)
    {
        Directory.CreateDirectory(target);
        using var zip = ZipFile.OpenRead(archive);
        long size = 0;
        if (zip.Entries.Count > 10000) throw new Exception("Pacote grande demais.");
        foreach (var entry in zip.Entries)
        {
            size = checked(size + entry.Length);
            if (size > 4L * 1024 * 1024 * 1024) throw new Exception("Pacote grande demais.");
            string path = SafePath(target, entry.FullName);
            if (((entry.ExternalAttributes >> 16) & 0xF000) == 0xA000) throw new Exception("Link inválido dentro do pacote.");
            if (entry.FullName.Replace('\\', '/').EndsWith('/')) { Directory.CreateDirectory(path); continue; }
            Directory.CreateDirectory(Path.GetDirectoryName(path)!);
            entry.ExtractToFile(path, false);
        }
    }
    public static async Task Apply(GameRelease release, Settings settings, IProgress<string> progress)
    {
        ValidateRelease(release);
        Directory.CreateDirectory(Settings.Root);
        await using var updateLock = new FileStream(Path.Combine(Settings.Root, "update.lock"), FileMode.OpenOrCreate, FileAccess.ReadWrite, FileShare.None);
        if (IsGameRunning(settings)) throw new Exception("Feche o jogo para atualizar.");
        string work = Path.Combine(Settings.Root, "versions", release.GameVersion + "-" + Guid.NewGuid().ToString("N"));
        Directory.CreateDirectory(work);
        string archive = Path.Combine(work, "jogo.zip");
        using (var response = await Http.GetAsync(release.PackageUrl, HttpCompletionOption.ResponseHeadersRead))
        {
            response.EnsureSuccessStatusCode();
            if (response.Content.Headers.ContentLength is long size && size != release.Size) throw new Exception("Tamanho do download incorreto.");
            await using var input = await response.Content.ReadAsStreamAsync();
            await using var output = File.Create(archive);
            var buffer = new byte[262144]; long total = 0; int count; var timer = Stopwatch.StartNew();
            while ((count = await input.ReadAsync(buffer)) > 0)
            {
                total += count; if (total > release.Size) throw new Exception("Download grande demais.");
                await output.WriteAsync(buffer.AsMemory(0, count));
                if (timer.ElapsedMilliseconds > 250) { progress.Report($"Baixando jogo: {100 * total / release.Size}% ({total / 1048576} de {release.Size / 1048576} MB)…"); timer.Restart(); }
            }
            if (total != release.Size) throw new Exception("O download foi interrompido. Tente novamente.");
        }
        progress.Report("Conferindo o download…"); await VerifyHash(archive, release.Sha256);
        string game = Path.Combine(work, "game");
        progress.Report("Instalando o jogo…"); await Task.Run(() => Extract(archive, game));
        var exe = SafePath(game, release.ExePath);
        await VerifyHash(exe, release.ExeSha256);
        if (IsGameRunning(settings)) throw new Exception("O jogo foi aberto durante a atualização. Feche-o e tente novamente.");
        var next = new Settings { GameExe = exe, Version = release.GameVersion, Automatic = settings.Automatic };
        if (File.Exists(settings.GameExe)) File.WriteAllText(Path.Combine(Settings.Root, "versao-anterior.json"), JsonSerializer.Serialize(settings, Settings.Json));
        Settings.Save(next); settings.GameExe = next.GameExe; settings.Version = next.Version;
        File.Delete(archive);
    }
    public static async Task Run(string executable, string[] args, string work, string log, TimeSpan? timeout = null)
    {
        var start = new ProcessStartInfo(executable) { WorkingDirectory = work, UseShellExecute = false, CreateNoWindow = true, RedirectStandardOutput = true, RedirectStandardError = true };
        foreach (var arg in args) start.ArgumentList.Add(arg);
        using var process = Process.Start(start) ?? throw new Exception("Não foi possível iniciar a etapa.");
        var output = process.StandardOutput.ReadToEndAsync(); var error = process.StandardError.ReadToEndAsync();
        try { await process.WaitForExitAsync(new CancellationTokenSource(timeout ?? TimeSpan.FromMinutes(15)).Token); }
        catch { if (!process.HasExited) process.Kill(true); throw new Exception("A etapa demorou demais."); }
        var text = await output + "\n" + await error;
        await File.WriteAllTextAsync(Path.Combine(work, log), text);
        if (process.ExitCode != 0 || text.Contains("SCRIPT ERROR:") || text.Split('\n').Any(line => line.TrimStart().StartsWith("ERROR:"))) throw new Exception("Uma etapa falhou. Consulte " + log + ".");
    }
}
