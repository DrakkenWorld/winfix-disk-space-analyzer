using System.Globalization;
using System.Net;
using System.Text;
using System.Text.RegularExpressions;

namespace WinFix.Core;

public sealed record ReportFiles(string Html, string FilesCsv, string FoldersCsv);
public static class Reports
{
    public static string Text(string language, string en, string fr) => language == "fr" ? fr : en;
    public static string Size(long bytes, string language)
    {
        string[] units = language == "fr" ? ["o", "Ko", "Mo", "Go", "To", "Po"] : ["B", "KB", "MB", "GB", "TB", "PB"];
        double value = bytes; int unit = 0;
        while (value >= 1024 && unit < units.Length - 1) { value /= 1024; unit++; }
        return value.ToString(unit == 0 ? "N0" : "N2", CultureInfo.GetCultureInfo(language == "fr" ? "fr-FR" : "en-US")) + " " + units[unit];
    }
    public static string CsvText(string value)
    {
        if (Regex.IsMatch(value, @"^\s*[=+@-]|^[\t\r\n]")) value = "'" + value;
        return "\"" + value.Replace("\"", "\"\"") + "\"";
    }
    public static ReportFiles Write(ScanResult result, string directory, string language)
    {
        if (language is not ("en" or "fr")) throw new ArgumentException(nameof(language));
        directory = Scanner.Normalize(directory);
        if (string.Equals(directory, Scanner.Normalize(result.Path), StringComparison.OrdinalIgnoreCase))
            throw new ArgumentException("OutputIsRoot");
        Directory.CreateDirectory(directory);
        string stamp = DateTime.Now.ToString("yyyy-MM-dd_HH-mm-ss-fff", CultureInfo.InvariantCulture) + "_" + Guid.NewGuid().ToString("N")[..8];
        var paths = new ReportFiles(System.IO.Path.Combine(directory, $"DiskSpaceReport_{stamp}.html"),
            System.IO.Path.Combine(directory, $"LargestFiles_{stamp}.csv"), System.IO.Path.Combine(directory, $"TopLevelFolders_{stamp}.csv"));
        var fileLines = new List<string> { "\"Name\",\"FullName\",\"LengthBytes\",\"Size\",\"LastWriteTime\"" };
        fileLines.AddRange(result.LargestFiles.Select(f => string.Join(",", CsvText(f.Name), CsvText(f.FullName),
            f.LengthBytes.ToString(CultureInfo.InvariantCulture), CsvText(Size(f.LengthBytes, language)), CsvText(f.LastWriteTime.ToString("o", CultureInfo.InvariantCulture)))));
        var folderLines = new List<string> { "\"Folder\",\"LengthBytes\",\"Size\",\"FilesFound\"" };
        folderLines.AddRange(result.LargestFolders.Select(f => string.Join(",", CsvText(f.Folder),
            f.LengthBytes.ToString(CultureInfo.InvariantCulture), CsvText(Size(f.LengthBytes, language)), f.FilesFound.ToString(CultureInfo.InvariantCulture))));
        // Each unique report is create-only; incomplete exports are removed on failure.
        var written = new List<string>();
        try
        {
            WriteNew(paths.FilesCsv, string.Join(Environment.NewLine, fileLines) + Environment.NewLine, written);
            WriteNew(paths.FoldersCsv, string.Join(Environment.NewLine, folderLines) + Environment.NewLine, written);
            WriteNew(paths.Html, Html(result, language), written);
        }
        catch
        {
            foreach (var path in written) { try { File.Delete(path); } catch (IOException) { } catch (UnauthorizedAccessException) { } }
            throw;
        }
        return paths;
    }
    private static void WriteNew(string path, string content, List<string> written)
    {
        using var stream = new FileStream(path, FileMode.CreateNew, FileAccess.Write, FileShare.None);
        written.Add(path);
        using var writer = new StreamWriter(stream, new UTF8Encoding(true));
        writer.Write(content);
    }
    private static string Html(ScanResult r, string lang)
    {
        string T(string en, string fr) => Text(lang, en, fr);
        string E(string text) => WebUtility.HtmlEncode(text);
        var html = new StringBuilder($"<!doctype html><html lang=\"{lang}\"><head><meta charset=\"utf-8\"><meta name=\"viewport\" content=\"width=device-width, initial-scale=1\"><title>WinFix Kit</title><style>body{{max-width:1200px;margin:auto;padding:28px;background:#0b1020;color:#f3f6ff;font:16px/1.6 Segoe UI,Arial,sans-serif}}h1,h2{{color:#6be0d2}}table{{width:100%;border-collapse:collapse}}td,th{{padding:10px;text-align:left;border-bottom:1px solid #26334d;overflow-wrap:anywhere}}.table{{overflow-x:auto}}.notice{{padding:16px;background:#111a2d;border-left:3px solid #6be0d2}}li{{overflow-wrap:anywhere}}</style></head><body>");
        html.Append($"<h1>WinFix Kit — {T("Disk Space Analyzer", "Analyseur d’espace disque")}</h1><p>{E(r.Path)}</p>");
        html.Append($"<p class=\"notice\">{T("Read-only scan. No scanned file is changed, deleted or uploaded. Reports contain private names and paths; review before sharing.", "Analyse en lecture seule. Aucun fichier analysé n’est modifié, supprimé ou téléversé. Les rapports contiennent des noms et chemins privés : vérifiez-les avant de les partager.")}</p>");
        html.Append($"<p>{T("Files found", "Fichiers trouvés")} : {r.Files} · {T("Total", "Total")} : {Size(r.Bytes, lang)} ({r.Bytes} {T("bytes", "octets")}) · {T("Errors", "Erreurs")} : {r.Errors.Count} · {r.Duration.TotalSeconds.ToString("N1", CultureInfo.GetCultureInfo(lang))} s</p>");
        html.Append($"<h2>{T("Largest files", "Fichiers les plus volumineux")}</h2><div class=\"table\"><table><thead><tr><th>{T("Name", "Nom")}</th><th>{T("Full path", "Chemin complet")}</th><th>{T("Size", "Taille")}</th></tr></thead><tbody>");
        foreach (var f in r.LargestFiles) html.Append($"<tr><td>{E(f.Name)}</td><td>{E(f.FullName)}</td><td>{E(Size(f.LengthBytes, lang))}</td></tr>");
        if (r.LargestFiles.Count == 0) html.Append($"<tr><td colspan=\"3\">{T("No files found.", "Aucun fichier trouvé.")}</td></tr>");
        html.Append($"</tbody></table></div><h2>{T("Largest direct subfolders", "Sous-dossiers directs les plus volumineux")}</h2><div class=\"table\"><table><thead><tr><th>{T("Folder", "Dossier")}</th><th>{T("Size", "Taille")}</th><th>{T("Files", "Fichiers")}</th></tr></thead><tbody>");
        foreach (var f in r.LargestFolders) html.Append($"<tr><td>{E(f.Folder)}</td><td>{E(Size(f.LengthBytes, lang))}</td><td>{f.FilesFound}</td></tr>");
        if (r.LargestFolders.Count == 0) html.Append($"<tr><td colspan=\"3\">{T("No subfolders found.", "Aucun sous-dossier trouvé.")}</td></tr>");
        html.Append($"</tbody></table></div><h2>{T("Scan errors (first 100)", "Erreurs d’analyse (100 premières)")}</h2><ul>");
        foreach (var e in r.Errors.Take(100)) html.Append($"<li>{E(e.Path)} : {E(e.Message)}</li>");
        if (r.Errors.Count == 0) html.Append($"<li>{T("No scan errors.", "Aucune erreur d’analyse.")}</li>");
        html.Append($"</ul><p>{T("Totals may be incomplete when access is denied. Reparse points are skipped. Logical file sizes are not reclaimable space.", "Les totaux peuvent être incomplets en cas d’accès refusé. Les points de réanalyse sont ignorés. La taille logique des fichiers n’est pas l’espace que vous pouvez libérer.")}</p></body></html>");
        return html.ToString();
    }
}
