using System.Diagnostics;
using System.Text.Json;
using Velopack;

namespace VoiceNew;

static class Program
{
    [STAThread]
    static int Main(string[] args)
    {
        VelopackApp.Build().Run();
        try
        {
            // These modes never create a window or launch the game.
            if (args.Contains("--self-test")) { SelfTest.Run().GetAwaiter().GetResult(); return 0; }
            if (args.Length == 2 && args[0] == "--import-settings")
            {
                var settings = JsonSerializer.Deserialize<Settings>(File.ReadAllText(args[1]), Settings.Json) ?? throw new Exception("Configuração inválida.");
                if (!File.Exists(settings.GameExe)) throw new Exception("Jogo não encontrado.");
                Settings.Save(settings); return 0;
            }
            if (args.Length == 2 && args[0] == "--check")
            {
                var release = Updater.FetchRelease().GetAwaiter().GetResult();
                File.WriteAllText(args[1], JsonSerializer.Serialize(release, Settings.Json)); return 0;
            }
            if (args.Length == 2 && args[0] == "--apply")
            {
                var release = JsonSerializer.Deserialize<GameRelease>(File.ReadAllText(args[1]), Settings.Json) ?? throw new Exception("Manifesto inválido.");
                Updater.Apply(release, Settings.Load(), new Progress<string>()).GetAwaiter().GetResult(); return 0;
            }
            if (args.Length == 3 && args[0] == "--test-launcher-update")
            {
                var manager = new UpdateManager(args[1]);
                var next = manager.CheckForUpdatesAsync().GetAwaiter().GetResult() ?? throw new Exception("Nenhuma atualização para testar.");
                manager.DownloadUpdatesAsync(next).GetAwaiter().GetResult();
                manager.ApplyUpdatesAndRestart(next, ["--launcher-result", args[2]]); return 0;
            }
            if (args.Length == 2 && args[0] == "--launcher-result")
            {
                File.WriteAllText(args[1], new UpdateManager(Updater.Repository).CurrentVersion?.ToString() ?? "uninstalled"); return 0;
            }
            ApplicationConfiguration.Initialize();
            if (args.Length == 2 && args[0] == "--preview")
            {
                using var form = new MainForm(false) { Opacity = 0, ShowInTaskbar = false };
                form.Show(); Application.DoEvents();
                using var bitmap = new Bitmap(form.Width, form.Height);
                form.DrawToBitmap(bitmap, new Rectangle(Point.Empty, form.Size)); bitmap.Save(args[1]); return 0;
            }
            using var instance = new Mutex(true, "Local\\CJCarrao.VOICENEW.Launcher", out bool isFirst);
            if (!isFirst) return 0;
            Application.Run(new MainForm());
            return 0;
        }
        catch (Exception ex)
        {
            Directory.CreateDirectory(Settings.Root);
            File.WriteAllText(Path.Combine(Settings.Root, "ultimo-erro.txt"), ex.ToString());
            return 1;
        }
    }
}

sealed class MainForm : Form
{
    Settings settings = Settings.Load();
    readonly Label status = new() { AutoSize = false, Width = 480, Height = 70 };
    readonly Label version = new() { AutoSize = true };
    readonly Button play = new() { Text = "Jogar", Width = 150, Height = 46 };
    readonly Button update = new() { Text = "Atualizar", Width = 150, Height = 46 };
    readonly Button folder = new() { Text = "Abrir pasta", Width = 150, Height = 46 };
    readonly CheckBox automatic = new() { Text = "Atualizar automaticamente ao abrir", AutoSize = true };
    readonly ProgressBar progress = new() { Width = 480, Height = 10, Style = ProgressBarStyle.Marquee, Visible = false };
    bool busy;

    public MainForm(bool checkOnShow = true)
    {
        Text = "VOICENEW"; ClientSize = new(530, 310); StartPosition = FormStartPosition.CenterScreen;
        FormBorderStyle = FormBorderStyle.FixedSingle; MaximizeBox = false;
        Font = new("Segoe UI", 10); BackColor = Color.FromArgb(24, 27, 34); ForeColor = Color.WhiteSmoke;
        var title = new Label { Text = "VOICENEW", Font = new("Segoe UI", 23, FontStyle.Bold), AutoSize = true, Location = new(22, 15) };
        version.Location = new(25, 65); status.Location = new(25, 91);
        var actions = new FlowLayoutPanel { Location = new(22, 163), Width = 490, Height = 55 };
        foreach (var button in new[] { play, update, folder }) { button.ForeColor = Color.Black; button.BackColor = Color.WhiteSmoke; actions.Controls.Add(button); }
        automatic.Location = new(25, 222); automatic.Checked = settings.Automatic;
        progress.Location = new(25, 258);
        var config = new LinkLabel { Text = "Configurar", AutoSize = true, Location = new(423, 224), LinkColor = Color.LightSkyBlue };
        var credit = new LinkLabel { Text = "LAVOICE por Tsomyst · Somyst Game Studio", AutoSize = true, Font = new("Segoe UI", 8), Location = new(25, 284), LinkColor = Color.Silver };
        credit.LinkClicked += (_, _) => Process.Start(new ProcessStartInfo("https://tsomyst.itch.io/lavoice") { UseShellExecute = true });
        Controls.AddRange([title, version, status, actions, automatic, progress, config, credit]);
        play.Click += (_, _) =>
        {
            try
            {
                if (!File.Exists(settings.GameExe)) { Configure(); return; }
                Process.Start(new ProcessStartInfo(settings.GameExe) { WorkingDirectory = Path.GetDirectoryName(settings.GameExe)!, UseShellExecute = true });
            }
            catch (Exception ex) { ShowError(ex); }
        };
        folder.Click += (_, _) =>
        {
            var path = File.Exists(settings.GameExe) ? Path.GetDirectoryName(settings.GameExe)! : Settings.Root;
            Directory.CreateDirectory(path); Process.Start(new ProcessStartInfo("explorer.exe", path) { UseShellExecute = true });
        };
        update.Click += async (_, _) => await UpdateGame();
        automatic.CheckedChanged += (_, _) => { settings.Automatic = automatic.Checked; Settings.Save(settings); };
        config.LinkClicked += (_, _) => { if (!busy) Configure(); };
        FormClosing += (_, e) => { if (busy) { e.Cancel = true; status.Text = "Aguarde a atualização terminar. A versão atual continua preservada."; } };
        RefreshVersion();
        Shown += async (_, _) => { if (checkOnShow && settings.Automatic && File.Exists(settings.GameExe)) await UpdateGame(); };
    }

    void RefreshVersion()
    {
        version.Text = string.IsNullOrEmpty(settings.Version) ? "Jogo ainda não instalado" : "Jogo " + settings.Version;
        status.Text = File.Exists(settings.GameExe) ? "Pronto para jogar." : "Clique em Instalar jogo para baixar pelo nosso GitHub.";
        update.Text = File.Exists(settings.GameExe) ? "Atualizar" : "Instalar jogo";
        play.Enabled = File.Exists(settings.GameExe);
    }

    void Configure()
    {
        using var dialog = new SettingsForm(settings);
        if (dialog.ShowDialog(this) == DialogResult.OK) { settings = dialog.Value; Settings.Save(settings); automatic.Checked = settings.Automatic; RefreshVersion(); }
    }

    async Task UpdateGame()
    {
        if (busy) return;
        busy = true; play.Enabled = update.Enabled = false; progress.Visible = true;
        try
        {
            var reporter = new Progress<string>(s => status.Text = s);
            if (Updater.IsGameRunning(settings)) { status.Text = "Feche o jogo para atualizar. Sua partida continua normalmente."; return; }
            status.Text = "Procurando atualizações…";
            // Velopack updates this small launcher; game versions remain outside its directory.
            var manager = new UpdateManager(Updater.FeedUrl);
            if (manager.IsInstalled)
            {
                var newer = await manager.CheckForUpdatesAsync();
                if (newer != null)
                {
                    status.Text = "Atualizando o iniciador…";
                    await manager.DownloadUpdatesAsync(newer);
                    manager.ApplyUpdatesAndRestart(newer); return;
                }
            }
            var release = await Updater.FetchRelease();
            if (File.Exists(settings.GameExe) && !Updater.IsNewer(release.GameVersion, settings.Version)) { status.Text = "Tudo atualizado. Pronto para jogar!"; return; }
            await Updater.Apply(release, settings, reporter);
            version.Text = "Jogo " + settings.Version; update.Text = "Atualizar"; status.Text = "Atualização concluída. Pronto para jogar!";
        }
        catch (Exception ex) { ShowError(ex); }
        finally { busy = false; play.Enabled = File.Exists(settings.GameExe); update.Enabled = true; progress.Visible = false; }
    }

    void ShowError(Exception ex)
    {
        Directory.CreateDirectory(Settings.Root);
        File.WriteAllText(Path.Combine(Settings.Root, "ultimo-erro.txt"), ex.ToString());
        status.Text = "Não foi possível atualizar: " + ex.Message;
    }
}

sealed class SettingsForm : Form
{
    public Settings Value { get; private set; }
    public SettingsForm(Settings settings)
    {
        Value = JsonSerializer.Deserialize<Settings>(JsonSerializer.Serialize(settings))!;
        Text = "Configurar VOICENEW"; ClientSize = new(640, 170); StartPosition = FormStartPosition.CenterParent;
        Font = new("Segoe UI", 9); FormBorderStyle = FormBorderStyle.FixedDialog; MaximizeBox = MinimizeBox = false;
        Controls.Add(new Label { Text = "Já tem o jogo? Selecione o EXE abaixo. Caso contrário, use Instalar jogo na tela inicial.", Location = new(16, 16), Size = new(605, 42) });
        var field = new TextBox { Text = Value.GameExe, Location = new(16, 65), Width = 544 }; Controls.Add(field);
        var browse = new Button { Text = "…", Location = new(568, 64), Width = 48 };
        browse.Click += (_, _) => { using var dlg = new OpenFileDialog { Filter = "Executável|*.exe" }; if (dlg.ShowDialog() == DialogResult.OK) field.Text = dlg.FileName; };
        Controls.Add(browse);
        var save = new Button { Text = "Salvar", Location = new(496, 120), Width = 120, Height = 30 };
        save.Click += (_, _) =>
        {
            Value.GameExe = field.Text.Trim();
            DialogResult = DialogResult.OK;
        }; Controls.Add(save);
    }
}
