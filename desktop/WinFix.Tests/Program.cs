using System.Diagnostics;
using System.Security.AccessControl;
using System.Security.Cryptography;
using System.Security.Principal;
using System.Text;
using Microsoft.VisualBasic.FileIO;
using WinFix.Core;

string temp = Path.GetFullPath(Path.GetTempPath());
string root = Path.Combine(temp, "WinFixNative-" + Guid.NewGuid().ToString("N"));
Directory.CreateDirectory(root);
int passed = 0;
void Check(bool value, string reason) { if (!value) throw new Exception(reason); }
void Test(string name, Action test) { test(); passed++; Console.WriteLine("PASS: " + name); }
string Dir(string name) { string path = Path.Combine(root, name); Directory.CreateDirectory(path); return path; }
void FileOf(string path, int length) => File.WriteAllBytes(path, new byte[length]);
void Throws<T>(Action action) where T : Exception
{ try { action(); } catch (T) { return; } throw new Exception("Expected " + typeof(T).Name); }
List<string[]> Csv(string path)
{
    using var parser = new TextFieldParser(path, Encoding.UTF8) { HasFieldsEnclosedInQuotes = true };
    parser.SetDelimiters(","); var rows = new List<string[]>();
    while (!parser.EndOfData) rows.Add(parser.ReadFields()!);
    return rows;
}
try
{
    Test("Missing path, root output and invalid limits are rejected", () =>
    {
        Throws<DirectoryNotFoundException>(() => Scanner.Scan(new(Path.Combine(root, "missing"), Dir("out"))));
        string d = Dir("invalid");
        Throws<ArgumentException>(() => Scanner.Scan(new(d, d)));
        Throws<ArgumentOutOfRangeException>(() => Scanner.Scan(new(d, Dir("out"), 0)));
    });
    Test("Empty reports have stable CSV headers and translated HTML", () =>
    {
        var r = Scanner.Scan(new(Dir("empty"), Dir("out")));
        Check(r.Files == 0 && r.Bytes == 0 && r.Errors.Count == 0, "Empty totals");
        var paths = Reports.Write(r, Dir("empty-reports"), "fr");
        Check(Csv(paths.FilesCsv).Count == 1, "Header only CSV");
        string html = File.ReadAllText(paths.Html);
        Check(html.Contains("lang=\"fr\"") && html.Contains("Aucun fichier") && html.Contains("Aucun sous-dossier"), "French empty report");
        Check(Csv(paths.FilesCsv)[0].SequenceEqual(new[] { "Name", "FullName", "LengthBytes", "Size", "LastWriteTime" }), "CSV schema");
    });
    Test("Exact totals, root files, nested folders, hidden files, ordering and limits", () =>
    {
        string d = Dir("known"), a = Dir("known/a"), b = Dir("known/b/deep");
        FileOf(Path.Combine(d, "root.bin"), 7); FileOf(Path.Combine(a, "small.bin"), 20);
        FileOf(Path.Combine(a, "large.bin"), 100); FileOf(Path.Combine(b, "middle.bin"), 50);
        string hidden = Path.Combine(d, "hidden.bin"); FileOf(hidden, 3); File.SetAttributes(hidden, FileAttributes.Hidden);
        var hashes = Directory.GetFiles(d, "*", System.IO.SearchOption.AllDirectories).ToDictionary(x => x, x => Convert.ToHexString(SHA256.HashData(File.ReadAllBytes(x))));
        var r = Scanner.Scan(new(d, Dir("known-out"), 2, 1));
        Check(r.Files == 5 && r.Bytes == 180 && r.Errors.Count == 0, "Exact totals");
        Check(r.LargestFiles.Select(x => x.LengthBytes).SequenceEqual(new long[] { 100, 50 }), "Numeric ordering");
        Check(r.LargestFolders.Count == 1 && r.LargestFolders[0].LengthBytes == 120 && r.LargestFolders[0].FilesFound == 2, "Recursive direct folder totals");
        Check(hashes.All(x => x.Value == Convert.ToHexString(SHA256.HashData(File.ReadAllBytes(x.Key)))), "Source contents preserved");
    });
    Test("Unicode, CSV quoting, formula defense, HTML escaping and UTF-8 BOM", () =>
    {
        string d = Dir("encoding"); FileOf(Path.Combine(d, "é,a&b.bin"), 2048); FileOf(Path.Combine(d, "=1+1.bin"), 10);
        var r = Scanner.Scan(new(d, Dir("encoding-out")));
        var paths = Reports.Write(r, Dir("encoding-out"), "fr");
        var rows = Csv(paths.FilesCsv);
        Check(rows[1][0] == "é,a&b.bin" && rows[1][2] == "2048" && rows[1][3] == "2,00 Ko", "Localized display and exact CSV");
        Check(rows[2][0] == "'=1+1.bin", "Formula neutralized");
        Check(File.ReadAllBytes(paths.FilesCsv).Take(3).SequenceEqual(new byte[] { 239, 187, 191 }), "BOM");
        Check(DateTime.TryParse(rows[1][4], null, System.Globalization.DateTimeStyles.RoundtripKind, out _), "ISO date");
        string html = File.ReadAllText(paths.Html);
        Check(html.Contains("a&amp;b.bin") && html.Contains("Fichiers les plus volumineux"), "HTML encoding and translation");
        var english = Reports.Write(r, Dir("encoding-out"), "en");
        Check(Csv(english.FilesCsv)[1][3] == "2.00 KB", "English formatting");
        Check(File.ReadAllText(english.Html).Contains("Largest files"), "English report");
    });
    Test("Dedicated nested output excluded and reports never overwritten", () =>
    {
        string d = Dir("repeated"), output = Dir("repeated/nested/reports"); FileOf(Path.Combine(d, "data.bin"), 11);
        var first = Scanner.Scan(new(d, output)); var a = Reports.Write(first, output, "en");
        var second = Scanner.Scan(new(d, output)); var b = Reports.Write(second, output, "en");
        Check(second.Files == 1 && second.Bytes == 11, "Old reports excluded");
        Check(a.Html != b.Html && File.Exists(a.Html), "Unique report names");
        Throws<ArgumentException>(() => Reports.Write(second, d, "en"));
    });
    Test("Cancellation stops a running scan and preserves source", () =>
    {
        string d = Dir("cancel"); for (int i = 0; i < 100; i++) FileOf(Path.Combine(d, i + ".bin"), 1);
        using var cts = new CancellationTokenSource();
        var updates = new InlineProgress(_ => cts.Cancel());
        Throws<OperationCanceledException>(() => Scanner.Scan(new(d, Path.Combine(root, "cancel-output")), updates, cts.Token));
        Check(Directory.GetFiles(d).Length == 100 && !Directory.Exists(Path.Combine(root, "cancel-output")), "No reports on cancellation");
    });
    Test("Junction loops are skipped and junction roots rejected", () =>
    {
        string d = Dir("junction"), link = Path.Combine(d, "loop"); FileOf(Path.Combine(d, "one.bin"), 13);
        var start = new ProcessStartInfo("cmd.exe") { UseShellExecute = false, CreateNoWindow = true, RedirectStandardOutput = true, RedirectStandardError = true };
        foreach (string arg in new[] { "/c", "mklink", "/J", link, d }) start.ArgumentList.Add(arg);
        using var process = Process.Start(start)!; process.WaitForExit();
        Check(process.ExitCode == 0, "Fixture junction creation");
        try
        {
            var r = Scanner.Scan(new(d, Dir("junction-out")));
            Check(r.Files == 1 && r.Bytes == 13, "No junction traversal");
            Throws<ArgumentException>(() => Scanner.Scan(new(link, Dir("junction-out"))));
        }
        finally { Directory.Delete(link); }
    });
    Test("Actual access denial continues with incomplete totals and an error", () =>
    {
        string d = Dir("access"); var blocked = new DirectoryInfo(Dir("access/blocked"));
        FileOf(Path.Combine(d, "readable.bin"), 12); FileOf(Path.Combine(blocked.FullName, "hidden.bin"), 99);
        var original = blocked.GetAccessControl(); var denied = blocked.GetAccessControl();
        var rule = new FileSystemAccessRule(WindowsIdentity.GetCurrent().User!, FileSystemRights.ListDirectory, AccessControlType.Deny);
        try
        {
            denied.AddAccessRule(rule); blocked.SetAccessControl(denied);
            var r = Scanner.Scan(new(d, Dir("access-out")));
            Check(r.Files == 1 && r.Bytes == 12 && r.Errors.Count == 1, "Accessible data counted; denied folder recorded");
        }
        finally
        {
            var restored = new DirectorySecurity();
            restored.SetSecurityDescriptorBinaryForm(original.GetSecurityDescriptorBinaryForm(), AccessControlSections.Access);
            blocked.SetAccessControl(restored);
        }
        Check(blocked.GetFiles().Length == 1, "Fixture permissions restored");
    });
    Test("5000 files have exact 2750000 byte total with bounded result metadata", () =>
    {
        string d = Dir("scale");
        for (int i = 1; i <= 50; i++)
        {
            string sub = Dir("scale/folder" + i);
            for (int j = 1; j <= 100; j++) FileOf(Path.Combine(sub, j + ".bin"), (j % 10 + 1) * 100);
        }
        var r = Scanner.Scan(new(d, Dir("scale-out"), 10, 200));
        Check(r.Files == 5000 && r.Bytes == 2750000 && r.Errors.Count == 0, "Exact scale totals");
        Check(r.LargestFiles.Count == 10 && r.LargestFolders.Sum(x => x.FilesFound) == 5000 && r.LargestFolders.Sum(x => x.LengthBytes) == 2750000, "Limits independent of totals");
    });
    Console.WriteLine($"All {passed} native engine/report tests passed on {Environment.OSVersion}.");
}
finally
{
    string resolved = Path.GetFullPath(root);
    if (Path.GetDirectoryName(resolved) == Path.TrimEndingDirectorySeparator(temp) && Path.GetFileName(resolved).StartsWith("WinFixNative-"))
        Directory.Delete(resolved, true);
}

sealed class InlineProgress(Action<ScanProgress> action) : IProgress<ScanProgress>
{ public void Report(ScanProgress value) => action(value); }
