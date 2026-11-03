using System.Diagnostics;
using System.IO.Compression;
using System.Security.Cryptography;
using System.Text.Json;

namespace VoiceNew;

static class SelfTest
{
    public static async Task Run()
    {
        var originalRoot = Environment.GetEnvironmentVariable("VOICENEW_DATA_DIR");
        var root = Path.Combine(Path.GetTempPath(), "VOICENEW-tests-" + Guid.NewGuid().ToString("N"));
        Environment.SetEnvironmentVariable("VOICENEW_DATA_DIR", root);
        Directory.CreateDirectory(root);
        var passed = new List<string>();
        void Check(bool ok, string name) { if (!ok) throw new Exception("Teste falhou: " + name); passed.Add(name); }
        void Reject(Action action, string name)
        {
            bool rejected = false; try { action(); } catch { rejected = true; }
            Check(rejected, name);
        }
        try
        {
            Check(Updater.IsNewer("0.4.1", "0.4.0"), "nova versão");
            Check(!Updater.IsNewer("0.4.0", "0.4.1"), "não faz downgrade");
            Check(!Updater.IsNewer("0.4.0", "0.4.0"), "não reinstala versão igual");
            Check(Updater.IsNewer("0.4.0", ""), "primeira instalação");
            var manifest = new GameRelease("0.4.1", Updater.Repository + "/releases/download/test/missing.zip", new string('a', 64), "Jogo/jogo.exe", new string('b', 64), 100);
            Updater.ValidateRelease(manifest);
            Reject(() => Updater.ValidateRelease(manifest with { PackageUrl = "https://github.com.evil.test/file.zip" }), "recusa outra origem");
            Reject(() => Updater.ValidateRelease(manifest with { Sha256 = "123" }), "recusa digest inválido");
            Reject(() => Updater.IsNewer("../pasta", "0.4.0"), "recusa versão inválida");
            var settings = new Settings { GameExe = "caminho com espaços e acentuação/jogo-anterior.exe", Version = "0.4.0" };
            Settings.Save(settings); Check(Settings.Load().GameExe == settings.GameExe, "configuração UTF-8 e gravação atômica");
            var saved = File.ReadAllText(Path.Combine(root, "settings.json"));
            try { await Updater.Apply(manifest with { Sha256 = "inválido" }, settings, new Progress<string>()); } catch { }
            Check(File.ReadAllText(Path.Combine(root, "settings.json")) == saved && settings.GameExe.EndsWith("jogo-anterior.exe"), "falha preserva instalação ativa");
            settings.GameExe = Environment.ProcessPath!;
            Check(Updater.IsGameRunning(settings), "reconhece jogo em execução sem abri-lo");
            var hashfile = Path.Combine(root, "hash.txt"); await File.WriteAllTextAsync(hashfile, "arquivo íntegro");
            var hash = Convert.ToHexString(SHA256.HashData(await File.ReadAllBytesAsync(hashfile)));
            await Updater.VerifyHash(hashfile, hash); passed.Add("aceita download íntegro");
            bool badHash = false; try { await Updater.VerifyHash(hashfile, new string('0', 64)); } catch { badHash = true; }
            Check(badHash, "recusa download corrompido");
            foreach (var bad in new[] { "../escapou.txt", "..\\escapou.txt", "C:/fora.txt", "/absoluto.txt" })
            {
                string zipPath = Path.Combine(root, Guid.NewGuid() + ".zip");
                using (var zip = ZipFile.Open(zipPath, ZipArchiveMode.Create)) { using var writer = new StreamWriter(zip.CreateEntry(bad).Open()); writer.Write("bad"); }
                Reject(() => Updater.Extract(zipPath, Path.Combine(root, Guid.NewGuid().ToString("N"))), "recusa caminho " + bad);
            }
            string good = Path.Combine(root, "bom.zip"), target = Path.Combine(root, "extraído");
            using (var zip = ZipFile.Open(good, ZipArchiveMode.Create)) { using var writer = new StreamWriter(zip.CreateEntry("mod-h6/arquivo.txt").Open()); writer.Write("ok"); }
            Updater.Extract(good, target); Check(File.ReadAllText(Path.Combine(target, "mod-h6/arquivo.txt")) == "ok", "extrai pacote válido");
            bool failedProcess = false;
            try { await Updater.Run(Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.System), "cmd.exe"), ["/d", "/c", "exit 7"], root, "failed.log"); } catch { failedProcess = true; }
            Check(failedProcess, "recusa compilação com falha");
            string result = JsonSerializer.Serialize(new { passed = passed.Count, tests = passed, gameOpened = false, directory = root }, Settings.Json);
            await File.WriteAllTextAsync(Path.Combine(root, "result.json"), result);
            if (originalRoot != null) { Directory.CreateDirectory(originalRoot); await File.WriteAllTextAsync(Path.Combine(originalRoot, "self-test.json"), result); }
        }
        finally { Environment.SetEnvironmentVariable("VOICENEW_DATA_DIR", originalRoot); }
    }
}
