using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Net.Http;
using Microsoft.Build.Framework;
using Microsoft.Build.Utilities;

namespace Microsoft.AspNetCore.Build.Tasks
{
    public class DownloadFile : Task
    {
        [Required]
        public string SourceUrl { get; set; }

        [Required]
        public string DestinationFile { get; set; }

        public override bool Execute()
        {
            if (File.Exists(DestinationFile))
            {
                Log.LogError("Destination file already exists: {0}", DestinationFile);
                return false;
            }

            var client = new HttpClient();
            Log.LogMessage("Downloading from {0}", SourceUrl);
            var resp = client.GetAsync(SourceUrl).Result;
            if (!resp.IsSuccessStatusCode)
            {
                Log.LogError("Error downloading {0}. HTTP response code {1} indicates failure", SourceUrl, (int)resp.StatusCode);
            }

            using (var body = resp.Content.ReadAsStreamAsync().Result)
            using (var file = new FileStream(DestinationFile, FileMode.Create, FileAccess.ReadWrite, FileShare.None))
            {
                Log.LogMessage("Saving to {0}", DestinationFile);
                body.CopyTo(file);
            }
            return true;
        }
    }
}
