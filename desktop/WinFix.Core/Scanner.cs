using System.Diagnostics;

namespace WinFix.Core;

public sealed record ScanOptions(string Path, string OutputDirectory, int TopFiles = 25, int TopFolders = 20);
public sealed record FileRow(string Name, string FullName, long LengthBytes, DateTime LastWriteTime);
public sealed record FolderRow(string Folder, long LengthBytes, long FilesFound);
public sealed record ScanError(string Path, string Message);
public sealed record ScanProgress(long Files, long Bytes, int Errors, string CurrentDirectory);
public sealed record ScanResult(string Path, long Files, long Bytes, TimeSpan Duration,
    IReadOnlyList<FileRow> LargestFiles, IReadOnlyList<FolderRow> LargestFolders, IReadOnlyList<ScanError> Errors);

public static class Scanner
{
    public static string Normalize(string path) => System.IO.Path.TrimEndingDirectorySeparator(System.IO.Path.GetFullPath(path));
    public static ScanResult Scan(ScanOptions options, IProgress<ScanProgress>? progress = null, CancellationToken cancellation = default)
    {
        if (options.TopFiles is < 1 or > 500 || options.TopFolders is < 1 or > 200)
            throw new ArgumentOutOfRangeException(nameof(options));
        if (string.IsNullOrWhiteSpace(options.Path) || string.IsNullOrWhiteSpace(options.OutputDirectory))
            throw new ArgumentException("Choose both directories.");
        string root = Normalize(options.Path), output = Normalize(options.OutputDirectory);
        if (!Directory.Exists(root)) throw new DirectoryNotFoundException(root);
        if ((File.GetAttributes(root) & FileAttributes.ReparsePoint) != 0)
            throw new ArgumentException("ReparseRoot");
        if (string.Equals(root, output, StringComparison.OrdinalIgnoreCase)) throw new ArgumentException("OutputIsRoot");

        var timer = Stopwatch.StartNew();
        var largest = new PriorityQueue<FileRow, long>();
        var folders = new Dictionary<string, (long Bytes, long Count)>(StringComparer.OrdinalIgnoreCase);
        var errors = new List<ScanError>();
        var stack = new Stack<(string Directory, string? Top)>();
        stack.Push((root, null));
        long count = 0, bytes = 0, lastProgress = -200;
        while (stack.Count > 0)
        {
            cancellation.ThrowIfCancellationRequested();
            var current = stack.Pop();
            if (string.Equals(Normalize(current.Directory), output, StringComparison.OrdinalIgnoreCase)) continue;
            try
            {
                foreach (string entry in Directory.EnumerateFileSystemEntries(current.Directory))
                {
                    cancellation.ThrowIfCancellationRequested();
                    try
                    {
                        var attributes = File.GetAttributes(entry);
                        if ((attributes & FileAttributes.ReparsePoint) != 0) continue;
                        if (string.Equals(Normalize(entry), output, StringComparison.OrdinalIgnoreCase)) continue;
                        if ((attributes & FileAttributes.Directory) != 0)
                        {
                            var top = current.Top ?? entry;
                            folders.TryAdd(top, (0, 0));
                            stack.Push((entry, top));
                        }
                        else
                        {
                            var info = new FileInfo(entry);
                            long length = info.Length;
                            count++; bytes += length;
                            if (current.Top is not null)
                            {
                                var value = folders[current.Top];
                                folders[current.Top] = (value.Bytes + length, value.Count + 1);
                            }
                            var row = new FileRow(info.Name, info.FullName, length, info.LastWriteTime);
                            if (largest.Count < options.TopFiles) largest.Enqueue(row, length);
                            else if (largest.TryPeek(out _, out long smallest) && length > smallest)
                                largest.DequeueEnqueue(row, length);
                        }
                    }
                    catch (Exception ex) when (ex is IOException or UnauthorizedAccessException)
                    { errors.Add(new(entry, ex.Message)); }
                    if (timer.ElapsedMilliseconds - lastProgress >= 150)
                    {
                        progress?.Report(new(count, bytes, errors.Count, current.Directory));
                        lastProgress = timer.ElapsedMilliseconds;
                    }
                }
            }
            catch (Exception ex) when (ex is IOException or UnauthorizedAccessException)
            {
                if (current.Top is null) throw;
                errors.Add(new(current.Directory, ex.Message));
            }
        }
        cancellation.ThrowIfCancellationRequested();
        timer.Stop();
        progress?.Report(new(count, bytes, errors.Count, root));
        return new(root, count, bytes, timer.Elapsed,
            largest.UnorderedItems.Select(x => x.Element).OrderByDescending(x => x.LengthBytes).ToArray(),
            folders.Select(x => new FolderRow(x.Key, x.Value.Bytes, x.Value.Count))
                .OrderByDescending(x => x.LengthBytes).Take(options.TopFolders).ToArray(), errors.ToArray());
    }
}
