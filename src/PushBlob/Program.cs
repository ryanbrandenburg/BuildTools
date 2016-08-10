using System;
using System.IO;
using Microsoft.WindowsAzure.Storage;

namespace PushBlob
{
    public class Program
    {
        public static int Main(string[] args)
        {
            if(args.Length != 3)
            {
                Console.Error.WriteLine("Usage: PushBlob [filename] [container] [connectionstring]");
                return 1;
            }

            var fileName = args[0];
            var containerName = args[1];
            var connectionString = args[2];

            if(!File.Exists(fileName))
            {
                Console.Error.WriteLine("File not found: " + fileName);
                return 1;
            }

            CloudStorageAccount account;
            if(!CloudStorageAccount.TryParse(connectionString, out account))
            {
                Console.Error.WriteLine("Invalid connection string");
                return 1;
            }

            var blobClient = account.CreateCloudBlobClient();
            var container = blobClient.GetContainerReference(containerName);
            container.CreateIfNotExistsAsync().Wait();

            var blob = container.GetBlockBlobReference(Path.GetFileName(fileName));
            Console.WriteLine($"Uploading {fileName} to {blob.Uri}");
            blob.UploadFromFileAsync(fileName).Wait();
            Console.WriteLine($"Uploaded {fileName} to {blob.Uri}");
            return 0;
        }
    }
}
