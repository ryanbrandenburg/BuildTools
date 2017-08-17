// Copyright (c) .NET Foundation. All rights reserved.
// Licensed under the Apache License, Version 2.0. See License.txt in the project root for license information.

using Microsoft.Extensions.CommandLineUtils;
using System;
using System.IO;
using System.Linq;
using System.Runtime.InteropServices;

namespace KoreBuild.Console.Commands
{
    internal class SubCommandBase : CommandBase
    {
        protected string KoreBuildDir => FindKoreBuildDirectory();

        private string DefaultToolsSource = "https://aspnetcore.blob.core.windows.net/buildtools";
        private CommandOption RepoPathOption { get; set; }
        private CommandOption DotNetHomeOption { get; set; }
        private CommandOption ToolsSourceOption { get; set; }

        public string RepoPath => RepoPathOption.HasValue() ? RepoPathOption.Value() : Directory.GetCurrentDirectory();

        public string DotNetHome => GetDotNetHome();

        public string ToolsSource => ToolsSourceOption.HasValue() ? ToolsSourceOption.Value() : DefaultToolsSource;
        public string SDKVersion => GetDotnetSDKVersion();

        public override void Configure(CommandLineApplication application)
        {
            ToolsSourceOption = application.Option("--toolsSource", "The source to draw tools from.", CommandOptionType.SingleValue);
            RepoPathOption = application.Option("--repoPath", "The path to the repo to work on.", CommandOptionType.SingleValue);
            DotNetHomeOption = application.Option("--dotNetHome", "The place where dotnet lives", CommandOptionType.SingleValue);

            base.Configure(application);
        }

        private string GetDotnetSDKVersion()
        {
            var sdkVersionEnv = Environment.GetEnvironmentVariable("KOREBUILD_DOTNET_VERSION");
            if (sdkVersionEnv != null)
            {
                return sdkVersionEnv;
            }
            else
            {
                var sdkVersionPath = Path.Combine(KoreBuildDir, "config", "sdk.version");
                return File.ReadAllText(sdkVersionPath).Trim();
            }
        }

        private string GetDotNetHome()
        {
            var dotnetHome = Environment.GetEnvironmentVariable("DOTNET_HOME");
            var userProfile = Environment.GetEnvironmentVariable("USERPROFILE");
            var home = Environment.GetEnvironmentVariable("HOME");

            var dotnetFolderName = ".dotnet"; 

            var result = Path.Combine(Directory.GetCurrentDirectory(), dotnetFolderName);
            if (DotNetHomeOption.HasValue())
            {
                result = DotNetHomeOption.Value();
            }
            else if (!string.IsNullOrEmpty(dotnetHome))
            {
                result = dotnetHome;
            }
            else if (!string.IsNullOrEmpty(userProfile))
            {
                result = Path.Combine(userProfile, dotnetFolderName);
            }
            else if (!string.IsNullOrEmpty(home))
            {
                result = home;
            }

            return result;
        }

        private string FindKoreBuildDirectory()
        {
            var currentDir = Directory.GetCurrentDirectory();

            while (true)
            {
                var dirs = Directory.EnumerateDirectories(currentDir);

                if (dirs.Any(s => s.EndsWith("files")))
                {
                    return Path.Combine(currentDir, "files", "KoreBuild");
                }

                if (Path.GetDirectoryName(currentDir) == "KoreBuild")
                {
                    return currentDir;
                }

                currentDir = Directory.GetParent(currentDir).FullName;
            }
        }

        protected string GetDotNetInstallDir()
        {
            var dotnetDir = DotNetHome;
            if (IsWindows())
            {
                dotnetDir = Path.Combine(dotnetDir, GetArchitecture());
            }

            return dotnetDir;
        }

        protected string GetDotNetExecutable()
        {
            var dotnetDir = GetDotNetInstallDir();

            var dotnetFile = "dotnet";

            if (IsWindows())
            {
                dotnetFile += ".exe";
            }

            return Path.Combine(dotnetDir, dotnetFile);
        }

        protected static string GetArchitecture()
        {
            return Environment.GetEnvironmentVariable("KOREBUILD_DOTNET_ARCH") ?? "x64";
        }

        protected static bool IsWindows()
        {
            return RuntimeInformation.IsOSPlatform(OSPlatform.Windows);
        }
    }
}
