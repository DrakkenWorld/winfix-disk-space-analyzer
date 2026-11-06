using System.Diagnostics;
using System.Globalization;
using WinFix.Core;

namespace WinFix.Desktop;

internal static class Program
{
    [STAThread]
    private static void Main()
    {
        Application.SetHighDpiMode(HighDpiMode.PerMonitorV2);
        Application.EnableVisualStyles();
        Application.SetCompatibleTextRenderingDefault(false);
        Application.SetDefaultFont(new Font("Segoe UI", 10));
        Application.SetColorMode(SystemColorMode.Dark);
        Application.Run(new MainForm());
    }
}

public sealed class MainForm : Form
{
    private readonly ComboBox language = new() { DropDownStyle = ComboBoxStyle.DropDownList, Width = 130, AccessibleName = "Language / Langue" };
    private readonly TextBox source = new() { Dock = DockStyle.Fill, Name = "ScanPath" };
    private readonly TextBox destination = new() { Dock = DockStyle.Fill, Name = "ReportPath" };
    private readonly Button browse = new() { AutoSize = true, Name = "Browse" };
    private readonly Button browseOutput = new() { AutoSize = true };
    private readonly Button scan = new() { AutoSize = true, MinimumSize = new(150, 40), Name = "Scan" };
    private readonly Button cancel = new() { AutoSize = true, MinimumSize = new(100, 40), Enabled = false, Name = "CancelScan" };
    private readonly Button open = new() { AutoSize = true, MinimumSize = new(150, 36), Enabled = false, Name = "OpenReport" };
    private readonly Button export = new() { AutoSize = true, MinimumSize = new(150, 36), Enabled = false, Name = "ExportReports" };
    private readonly Button about = new() { AutoSize = true, MinimumSize = new(90, 36) };
    private readonly CheckBox advanced = new() { AutoSize = true };
    private readonly NumericUpDown topFiles = new() { Minimum = 1, Maximum = 500, Value = 25, Width = 80 };
    private readonly NumericUpDown topFolders = new() { Minimum = 1, Maximum = 200, Value = 20, Width = 80 };
    private readonly Label title = new() { AutoSize = true, Font = new("Segoe UI", 23, FontStyle.Bold), ForeColor = Color.FromArgb(107, 224, 210) };
    private readonly Label notice = new() { AutoSize = true, Dock = DockStyle.Fill, Padding = new(0, 4, 0, 12) };
    private readonly Label sourceLabel = new() { AutoSize = true, Anchor = AnchorStyles.Left };
    private readonly Label outputLabel = new() { AutoSize = true, Anchor = AnchorStyles.Left };
    private readonly Label filesLabel = new() { AutoSize = true, Anchor = AnchorStyles.Left };
    private readonly Label foldersLabel = new() { AutoSize = true, Anchor = AnchorStyles.Left };
    private readonly Label status = new() { AutoSize = false, Dock = DockStyle.Fill, Height = 32, AutoEllipsis = true, Name = "ScanStatus" };
    private readonly Label summary = new() { AutoSize = true, Dock = DockStyle.Fill, Padding = new(0, 8, 0, 8), Font = new("Segoe UI", 11, FontStyle.Bold), Name = "ScanSummary" };
    private readonly ProgressBar progress = new() { Dock = DockStyle.Fill, Height = 8, Style = ProgressBarStyle.Continuous, Name = "ScanProgress" };
    private readonly TabControl tabs = new() { Dock = DockStyle.Fill, MinimumSize = new(200, 160) };
    private readonly DataGridView filesGrid = Grid("LargestFiles"), foldersGrid = Grid("LargestFolders"), errorsGrid = Grid("ScanErrors");
    private readonly TableLayoutPanel advancedPanel = new() { Dock = DockStyle.Fill, AutoSize = true, ColumnCount = 3, Visible = false };
    private CancellationTokenSource? cancellation;
    private ScanResult? result;
    private ScanOptions? scannedOptions;
    private ReportFiles? reportFiles;
    private string? reportLanguage;
    private string state = "ready";
    private bool closeWhenIdle;
    private bool exporting;
    private string Lang => language.SelectedIndex == 0 ? "fr" : "en";
    private string T(string en, string fr) => Reports.Text(Lang, en, fr);

    public MainForm()
    {
        Text = "WinFix Kit"; Name = "WinFixMainWindow";
        ClientSize = new(1080, 800); MinimumSize = new(780, 650);
        StartPosition = FormStartPosition.CenterScreen; AutoScaleMode = AutoScaleMode.Dpi;
        BackColor = Color.FromArgb(11, 16, 32); ForeColor = Color.FromArgb(243, 246, 255);
        var root = new TableLayoutPanel { Dock = DockStyle.Fill, ColumnCount = 1, Padding = new(24), RowCount = 10 };
        for (int i = 0; i < 10; i++) root.RowStyles.Add(new(i == 8 ? SizeType.Percent : SizeType.AutoSize, i == 8 ? 100 : 0));
        var heading = new TableLayoutPanel { Dock = DockStyle.Fill, AutoSize = true, ColumnCount = 2 };
        heading.ColumnStyles.Add(new(SizeType.Percent, 100)); heading.ColumnStyles.Add(new(SizeType.AutoSize));
        heading.Controls.Add(title, 0, 0); heading.Controls.Add(language, 1, 0);
        root.Controls.Add(heading, 0, 0); root.Controls.Add(notice, 0, 1);
        var paths = new TableLayoutPanel { Dock = DockStyle.Fill, AutoSize = true, ColumnCount = 3 };
        paths.ColumnStyles.Add(new(SizeType.AutoSize)); paths.ColumnStyles.Add(new(SizeType.Percent, 100)); paths.ColumnStyles.Add(new(SizeType.AutoSize));
        paths.Controls.Add(sourceLabel, 0, 0); paths.Controls.Add(source, 1, 0); paths.Controls.Add(browse, 2, 0);
        root.Controls.Add(paths, 0, 2); root.Controls.Add(advanced, 0, 3);
        advancedPanel.ColumnStyles.Add(new(SizeType.AutoSize)); advancedPanel.ColumnStyles.Add(new(SizeType.Percent, 100)); advancedPanel.ColumnStyles.Add(new(SizeType.AutoSize));
        advancedPanel.Controls.Add(outputLabel, 0, 0); advancedPanel.Controls.Add(destination, 1, 0); advancedPanel.Controls.Add(browseOutput, 2, 0);
        var limits = new FlowLayoutPanel { AutoSize = true, Dock = DockStyle.Fill, Padding = new(0, 4, 0, 8) };
        limits.Controls.AddRange([filesLabel, topFiles, foldersLabel, topFolders]);
        advancedPanel.Controls.Add(limits, 0, 1); advancedPanel.SetColumnSpan(limits, 3);
        root.Controls.Add(advancedPanel, 0, 4);
        var actions = new FlowLayoutPanel { AutoSize = true, Dock = DockStyle.Fill, Padding = new(0, 8, 0, 8) };
        actions.Controls.AddRange([scan, cancel]); root.Controls.Add(actions, 0, 5);
        var activity = new TableLayoutPanel { AutoSize = true, Dock = DockStyle.Fill, ColumnCount = 1 };
        activity.Controls.Add(progress, 0, 0); activity.Controls.Add(status, 0, 1);
        root.Controls.Add(activity, 0, 6); root.Controls.Add(summary, 0, 7);
        foreach (var grid in new[] { filesGrid, foldersGrid, errorsGrid })
        { var page = new TabPage(); page.Controls.Add(grid); tabs.TabPages.Add(page); }
        root.Controls.Add(tabs, 0, 8);
        var reports = new FlowLayoutPanel { AutoSize = true, Dock = DockStyle.Fill, Padding = new(0, 12, 0, 0) };
        reports.Controls.AddRange([open, export, about]); root.Controls.Add(reports, 0, 9); Controls.Add(root);
        string documents = Environment.GetFolderPath(Environment.SpecialFolder.MyDocuments);
        source.Text = Directory.Exists(documents) ? documents : Environment.GetFolderPath(Environment.SpecialFolder.UserProfile);
        destination.Text = Path.Combine(source.Text, "WinFixReports");
        language.Items.AddRange(["Français", "English"]);
        language.SelectedIndex = CultureInfo.CurrentUICulture.TwoLetterISOLanguageName == "fr" ? 0 : 1;
        language.SelectedIndexChanged += (_, _) => { UpdateLanguage(); if (result is not null) ShowResults(); };
        advanced.CheckedChanged += (_, _) => advancedPanel.Visible = advanced.Checked;
        browse.Click += (_, _) => PickFolder(source);
        browseOutput.Click += (_, _) => PickFolder(destination);
        destination.TextChanged += (_, _) => { reportFiles = null; reportLanguage = null; };
        source.TextChanged += (_, _) =>
        {
            if (cancellation is not null) return;
            result = null; reportFiles = null; scannedOptions = null; state = "ready";
            filesGrid.Rows.Clear(); foldersGrid.Rows.Clear(); errorsGrid.Rows.Clear(); summary.Text = "";
            open.Enabled = export.Enabled = false; SetStatus();
        };
        scan.Click += async (_, _) => await ScanAsync();
        cancel.Click += (_, _) => { cancellation?.Cancel(); cancel.Enabled = false; status.Text = T("Cancelling…", "Annulation en cours…"); };
        open.Click += async (_, _) => await ExportAsync(true);
        export.Click += async (_, _) => await ExportAsync(false);
        about.Click += (_, _) => ShowAbout();
        FormClosing += (_, e) =>
        {
            if (cancellation is not null) { e.Cancel = true; closeWhenIdle = true; cancellation.Cancel(); }
            if (exporting) e.Cancel = true;
        };
        AcceptButton = scan; UpdateLanguage();
    }
    private static DataGridView Grid(string name) => new()
    {
        Name = name, Dock = DockStyle.Fill, ReadOnly = true, AllowUserToAddRows = false,
        AllowUserToDeleteRows = false, AutoGenerateColumns = false, RowHeadersVisible = false,
        AutoSizeColumnsMode = DataGridViewAutoSizeColumnsMode.Fill, SelectionMode = DataGridViewSelectionMode.FullRowSelect,
        BackgroundColor = Color.FromArgb(17, 26, 45), BorderStyle = BorderStyle.None
    };
    private static void Columns(DataGridView grid, params string[] headers)
    {
        grid.Columns.Clear();
        foreach (string header in headers) grid.Columns.Add(new DataGridViewTextBoxColumn { HeaderText = header, SortMode = DataGridViewColumnSortMode.NotSortable });
    }
    private void UpdateLanguage()
    {
        Text = "WinFix Kit — " + T("Disk Space Analyzer", "Analyseur d’espace disque");
        title.Text = T("Understand your disk space", "Comprendre votre espace disque");
        notice.Text = T("Read-only analysis · No scanned file is changed or deleted · No data uploaded", "Analyse en lecture seule · Aucun fichier analysé modifié ou supprimé · Aucun envoi de données");
        sourceLabel.Text = T("Folder to scan", "Dossier à analyser"); browse.Text = T("Choose…", "Choisir…");
        source.AccessibleName = sourceLabel.Text; destination.AccessibleName = T("Report folder", "Dossier des rapports");
        browseOutput.Text = T("Choose…", "Choisir…"); outputLabel.Text = T("Report folder", "Dossier des rapports");
        advanced.Text = T("Advanced options", "Options avancées");
        filesLabel.Text = T("Largest files", "Fichiers affichés"); foldersLabel.Text = T("Folders", "Dossiers affichés");
        scan.Text = T("Analyze", "Analyser"); cancel.Text = T("Cancel", "Annuler");
        open.Text = T("Open HTML report", "Ouvrir le rapport HTML"); export.Text = T("Export HTML + CSV", "Exporter HTML + CSV");
        about.Text = T("About", "À propos");
        tabs.TabPages[0].Text = T("Largest files", "Fichiers volumineux"); tabs.TabPages[1].Text = T("Direct subfolders", "Sous-dossiers directs"); tabs.TabPages[2].Text = T("Access errors", "Erreurs d’accès");
        Columns(filesGrid, T("Name", "Nom"), T("Full path", "Chemin complet"), T("Size", "Taille"));
        filesGrid.Columns[1].FillWeight = 220;
        Columns(foldersGrid, T("Folder", "Dossier"), T("Size", "Taille"), T("Files", "Fichiers"));
        foldersGrid.Columns[0].FillWeight = 250;
        Columns(errorsGrid, T("Path", "Chemin"), T("Details (Windows language)", "Détails (langue de Windows)"));
        if (cancellation is null) SetStatus();
    }
    private void PickFolder(TextBox target)
    {
        using var dialog = new FolderBrowserDialog { UseDescriptionForTitle = true, Description = target == source ? sourceLabel.Text : outputLabel.Text, ShowNewFolderButton = target == destination };
        if (Directory.Exists(target.Text)) dialog.SelectedPath = target.Text;
        if (dialog.ShowDialog(this) == DialogResult.OK) target.Text = dialog.SelectedPath;
    }
    private void ShowAbout()
    {
        var assembly = typeof(MainForm).Assembly;
        string notices = "WinFix Kit 1.2.0\r\nhttps://github.com/DrakkenWorld/winfix-disk-space-analyzer\r\n\r\n";
        foreach (string name in new[] { "WinFix.AppLicense", "WinFix.RuntimeNotices" })
        {
            using var stream = assembly.GetManifestResourceStream(name);
            if (stream is not null) { using var reader = new StreamReader(stream); notices += reader.ReadToEnd() + "\r\n\r\n"; }
        }
        using var dialog = new Form { Text = about.Text + " — WinFix Kit", Size = new(740, 540), MinimumSize = new(450, 350), StartPosition = FormStartPosition.CenterParent, ShowInTaskbar = false };
        var text = new TextBox { Multiline = true, ReadOnly = true, Dock = DockStyle.Fill, ScrollBars = ScrollBars.Both, WordWrap = false, Text = notices, AccessibleName = T("Software licenses", "Licences du logiciel") };
        dialog.Controls.Add(text); dialog.ShowDialog(this);
    }
    private void SetStatus() => status.Text = state switch
    {
        "complete" => result?.Errors.Count > 0 ? T("Complete with access errors. Totals may be incomplete.", "Terminée avec des erreurs d’accès. Les totaux peuvent être incomplets.") : T("Analysis complete. You can open or export your report.", "Analyse terminée. Vous pouvez ouvrir ou exporter le rapport."),
        "cancelled" => T("Analysis cancelled. No report was generated.", "Analyse annulée. Aucun rapport n’a été généré."),
        "failed" => T("Analysis failed. Choose an accessible folder and try again.", "L’analyse a échoué. Choisissez un dossier accessible puis réessayez."),
        _ => T("Choose a folder, then click Analyze.", "Choisissez un dossier, puis cliquez sur Analyser.")
    };
    private void SetBusy(bool busy)
    {
        scan.Enabled = browse.Enabled = source.Enabled = advanced.Enabled = advancedPanel.Enabled = language.Enabled = !busy;
        cancel.Enabled = busy; open.Enabled = export.Enabled = !busy && result is not null;
        progress.Style = busy ? ProgressBarStyle.Marquee : ProgressBarStyle.Continuous;
        progress.Value = busy ? 0 : state == "complete" ? 100 : 0;
    }
    private async Task ScanAsync()
    {
        if (cancellation is not null) return;
        result = null; reportFiles = null; scannedOptions = null; reportLanguage = null;
        filesGrid.Rows.Clear(); foldersGrid.Rows.Clear(); errorsGrid.Rows.Clear(); summary.Text = "";
        var options = new ScanOptions(source.Text, destination.Text, (int)topFiles.Value, (int)topFolders.Value);
        using var local = new CancellationTokenSource(); cancellation = local; SetBusy(true);
        status.Text = T("Starting analysis…", "Démarrage de l’analyse…");
        var updates = new Progress<ScanProgress>(value =>
        {
            if (cancellation != local || local.IsCancellationRequested) return;
            status.Text = $"{value.Files:N0} {T("files", "fichiers")} · {Reports.Size(value.Bytes, Lang)} · {value.CurrentDirectory}";
        });
        try
        {
            result = await Task.Run(() => Scanner.Scan(options, updates, local.Token));
            scannedOptions = options; state = "complete"; ShowResults();
        }
        catch (OperationCanceledException) { state = "cancelled"; }
        catch (Exception ex) when (ex is IOException or UnauthorizedAccessException or ArgumentException or NotSupportedException or System.Security.SecurityException)
        {
            state = "failed";
            string message = ex.Message.Contains("OutputIsRoot") ? T("Choose a report folder different from the folder being scanned.", "Choisissez un dossier de rapports différent du dossier à analyser.")
                : ex.Message.Contains("ReparseRoot") ? T("Choose a regular folder, not a junction or symbolic link.", "Choisissez un dossier ordinaire, pas une jonction ni un lien symbolique.")
                : ex is ArgumentException or NotSupportedException ? T("Choose valid scan and report directories.", "Choisissez des chemins de dossiers valides pour l’analyse et les rapports.")
                : T("The folder could not be read. Check the path and your access permissions.", "Impossible de lire ce dossier. Vérifiez le chemin et vos droits d’accès.") + "\n\n" + ex.Message;
            if (ex.Message.Contains("OutputIsRoot")) advanced.Checked = true;
            MessageBox.Show(this, message, T("Cannot analyze this folder", "Impossible d’analyser ce dossier"), MessageBoxButtons.OK, MessageBoxIcon.Information);
        }
        finally { cancellation = null; SetBusy(false); SetStatus(); if (closeWhenIdle) Close(); }
    }
    private void ShowResults()
    {
        if (result is null) return;
        filesGrid.Rows.Clear(); foldersGrid.Rows.Clear(); errorsGrid.Rows.Clear();
        foreach (var f in result.LargestFiles) filesGrid.Rows.Add(f.Name, f.FullName, Reports.Size(f.LengthBytes, Lang));
        foreach (var f in result.LargestFolders) foldersGrid.Rows.Add(f.Folder, Reports.Size(f.LengthBytes, Lang), f.FilesFound);
        // Keep the UI bounded even if a drive contains thousands of inaccessible paths.
        foreach (var e in result.Errors.Take(1000)) errorsGrid.Rows.Add(e.Path, e.Message);
        summary.Text = $"{result.Files:N0} {T("files", "fichiers")}   ·   {Reports.Size(result.Bytes, Lang)}   ·   {result.Errors.Count:N0} {T("errors", "erreurs")}   ·   {result.Duration.TotalSeconds:N1} s";
        if (result.Errors.Count > 1000) summary.Text += T(" (first 1,000 errors shown)", " (1 000 premières erreurs affichées)");
    }
    private async Task ExportAsync(bool openReport)
    {
        if (result is null || scannedOptions is null || exporting) return;
        exporting = true; open.Enabled = export.Enabled = scan.Enabled = language.Enabled = false;
        source.Enabled = browse.Enabled = advanced.Enabled = advancedPanel.Enabled = false;
        string lang = Lang;
        try
        {
            if (reportFiles is null || reportLanguage != lang)
            {
                var data = result; var output = destination.Text;
                reportFiles = await Task.Run(() => Reports.Write(data, output, lang)); reportLanguage = lang;
            }
            string target = openReport ? reportFiles.Html : Path.GetDirectoryName(reportFiles.Html)!;
            Process.Start(new ProcessStartInfo(target) { UseShellExecute = true });
            status.Text = T("Reports saved locally: ", "Rapports enregistrés localement : ") + Path.GetDirectoryName(reportFiles.Html);
        }
        catch (Exception ex) when (ex is IOException or UnauthorizedAccessException or ArgumentException or NotSupportedException or System.Security.SecurityException or System.ComponentModel.Win32Exception)
        {
            MessageBox.Show(this, T("Could not save or open the report. Check the report folder in Advanced options, then run a new analysis if necessary.", "Impossible d’enregistrer ou d’ouvrir le rapport. Vérifiez le dossier des rapports dans les options avancées, puis relancez l’analyse si nécessaire.") + "\n\n" + ex.Message,
                T("Report unavailable", "Rapport indisponible"), MessageBoxButtons.OK, MessageBoxIcon.Information);
        }
        finally
        {
            exporting = false;
            open.Enabled = export.Enabled = scan.Enabled = language.Enabled = true;
            source.Enabled = browse.Enabled = advanced.Enabled = advancedPanel.Enabled = true;
        }
    }
}
