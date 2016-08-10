using System.IO;
using System.IO.Compression;
using Microsoft.Build.Framework;
using Microsoft.Build.Utilities;

namespace Microsoft.AspNetCore.Build.Tasks
{
    // We could use MSBuild Community Tasks (which have a Zip task) but they haven't been ported to Core.
    // Which is also why this is a very simple zipping task designed to fit only our needs :).
    public class ZipDirectory : Task
    {
        [Required]
        public string SourceDirectory { get; set; }

        [Required]
        public string DestinationFile { get; set; }

        public override bool Execute()
        {
            // We want to use the correct path separator ('/', since it is supported on Windows and POSIX)
            // so we don't use ZipFile.CreateFromDirectory
            if(File.Exists(DestinationFile))
            {
                Log.LogError("Destination file already exists: {0}", DestinationFile);
                return false;
            }

            using (var file = new FileStream(DestinationFile, FileMode.CreateNew, FileAccess.ReadWrite, FileShare.None))
            using (var archive = new ZipArchive(file, ZipArchiveMode.Create))
            {
                AddDirectory(archive, SourceDirectory, relativePath: string.Empty);
            }

            return true;
        }

        private void AddDirectory(ZipArchive archive, string directory, string relativePath)
        {
            foreach(var file in Directory.EnumerateFiles(directory))
            {
                var name = Path.GetFileName(file);
                var entryName = relativePath + name;
                archive.CreateEntryFromFile(file, entryName, CompressionLevel.Optimal);
                Log.LogMessage(MessageImportance.Low, "Added {0} to {1} as {2}", file, DestinationFile, entryName);
            }

            foreach(var dir in Directory.EnumerateDirectories(directory))
            {
                AddDirectory(archive, dir, relativePath + Path.GetFileName(dir) + "/");
            }
        }
    }
}
