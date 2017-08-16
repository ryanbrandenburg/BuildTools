// Copyright (c) .NET Foundation. All rights reserved.
// Licensed under the Apache License, Version 2.0. See License.txt in the project root for license information.

using Microsoft.Extensions.CommandLineUtils;
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Runtime.InteropServices;

namespace KoreBuild.Console.Commands
{
    internal class InstallToolsCommand : SubCommandBase
    {
        private string KoreBuildSkipRuntimeInstall => Environment.GetEnvironmentVariable("KOREBUILD_SKIP_RUNTIME_INSTALL");
        private string PathENV => Environment.GetEnvironmentVariable("PATH");
        private string DotNetInstallDir => Environment.GetEnvironmentVariable("DOTNET_INSTALL_DIR");

        public override void Configure(CommandLineApplication application)
        {
            base.Configure(application);
        }

        protected override int Execute()
        {
            var installDir = DotNetHome;
            if (IsWindows())
            {
                installDir = Path.Combine(installDir, GetArchitecture());
            }
            System.Console.WriteLine($"Installing tools to '{installDir}'");
            
            if(DotNetInstallDir != null && DotNetInstallDir != installDir)
            {
                System.Console.WriteLine($"installDir = {installDir}");
                System.Console.WriteLine($"DOTNET_INSTALL_DIR = {DotNetInstallDir}");
                System.Console.WriteLine("The environment variable DOTNET_INSTALL_DIR is deprecated. The recommended alternative is DOTNET_HOME.");
            }
            var dotnetFile = "dotnet";

            if(IsWindows())
            {
                dotnetFile += ".exe";
            }

            var dotnet = Path.Combine(installDir, dotnetFile);
            var dotnetOnPath = GetCommandFromPath("dotnet");

            if(dotnetOnPath != null && (dotnetOnPath != dotnet))
            {
                System.Console.WriteLine($"dotnet found on the system PATH is '{dotnetOnPath}' but KoreBuild will use '{dotnet}'");
            }

            var pathPrefix = Directory.GetParent(dotnet);
            if (PathENV.StartsWith($"{pathPrefix};"))
            {
                System.Console.WriteLine($"Adding {pathPrefix} to PATH");
                Environment.SetEnvironmentVariable("PATH", $"{pathPrefix};{PathENV}");
            }
            
            if(KoreBuildSkipRuntimeInstall == "1")
            {
                System.Console.WriteLine("Skipping runtime installation because KOREBUILD_SKIP_RUNTIME_INSTALL = 1");
                return 0;
            }

            var scriptExtension = IsWindows() ? "ps1" : "sh";

            var scriptPath = Path.Combine(Directory.GetCurrentDirectory(), "dotnet-install." + scriptExtension);

            if (!IsWindows())
            {
                var args = ArgumentEscaper.EscapeAndConcatenate(new string[] { "+x", scriptPath });
                var psi = new ProcessStartInfo
                {
                    FileName = "chmod",
                    Arguments = args
                };

                var process = Process.Start(psi);
                process.WaitForExit();
            }

            var channel = GetChannel();
            var runtimeChannel = GetRuntimeChannel();
            var sdkVersion = GetDotnetSDKVersion();
            var runtimeVersion = GetRuntimeVersion();

            var runtimesToInstall = new List<Tuple<string, string>>
            {
                new Tuple<string, string>("1.0.5", "preview"),
                new Tuple<string, string>("1.1.2", "release/1.1.0")
            };

            if(runtimeVersion != null)
            {
                runtimesToInstall.Add(new Tuple<string, string>(runtimeVersion, runtimeChannel));
            }

            var architecture = GetArchitecture();

            foreach(var runtime in runtimesToInstall)
            {
                InstallSharedRuntime(scriptPath, installDir, architecture, runtime.Item1, runtime.Item2);
            }

            InstallCLI(scriptPath, installDir, architecture, sdkVersion, channel);

            return 0;
        }

        private static void InstallCLI(string script, string installDir, string architecture, string version, string channel)
        {
            var sdkPath = Path.Combine(installDir, "sdk", version, "dotnet.dll");

            if (!File.Exists(sdkPath))
            {
                System.Console.WriteLine($"Installing dotnet {version} to {installDir}");

                var args = ArgumentEscaper.EscapeAndConcatenate(new string[] {
                    "-Channel", channel,
                    "-Version", version,
                    "-Architecture", architecture,
                    "-InstallDir", installDir
                });

                var psi = new ProcessStartInfo
                {
                    FileName = script,
                    Arguments = args
                };

                var process = Process.Start(psi);
                process.WaitForExit();
            }
            else
            {
                System.Console.WriteLine($".NET Core SDK {version} is already installed. Skipping installation.");
            }
        }

        private static void InstallSharedRuntime(string script, string installDir, string architecture, string version, string channel)
        {
            var sharedRuntimePath = Path.Combine(installDir, "shared", "Microsoft.NETCore.App", version);

            if(!File.Exists(sharedRuntimePath))
            {
                var args = ArgumentEscaper.EscapeAndConcatenate(new string[]
                {
                    "-Channel", channel,
                    "-SharedRuntime",
                    "-Version", version,
                    "-Architecture", architecture,
                    "-InstallDir", installDir
                });

                var psi = new ProcessStartInfo
                {
                    FileName = script,
                    Arguments = args
                };

                var process = Process.Start(psi);
                process.WaitForExit();
            }
            else
            {
                System.Console.WriteLine(".NET Core runtime $version is already installed. Skipping installation.");
            }
        }

        private static string GetChannel()
        {
            var channel = "preview";
            var channelEnv = Environment.GetEnvironmentVariable("KOREBUILD_DOTNET_CHANNEL");
            if(channelEnv != null)
            {
                channel = channelEnv;
            }

            return channel;
        }

        private static string GetRuntimeChannel()
        {
            var runtimeChannel = "master";
            var runtimeEnv = Environment.GetEnvironmentVariable("KOREBUILD_DOTNET_SHARED_RUNTIME_CHANNEL");
            if(runtimeEnv != null)
            {
                runtimeChannel = runtimeEnv;
            }

            return runtimeChannel;
        }

        private static string GetRuntimeVersion()
        {
            var runtimeVersionPath = Path.Combine(Directory.GetCurrentDirectory(), "..", "config", "runtime.version");
            return File.ReadAllText(runtimeVersionPath);
        }

        private static string GetDotnetSDKVersion()
        {
            var sdkVersionEnv = Environment.GetEnvironmentVariable("KOREBUILD_DOTNET_VERSION");
            if(sdkVersionEnv != null)
            {
                return sdkVersionEnv;
            }
            else
            {
                var sdkVersionPath = Path.Combine(Directory.GetCurrentDirectory(), "..", "config", "sdk.version");
                return File.ReadAllText(sdkVersionPath);
            }
        }

        private static string GetArchitecture()
        {
            return Environment.GetEnvironmentVariable("KOREBUILD_DOTNET_ARCH") ?? "x64";
        }

        private static bool IsWindows()
        {
            return RuntimeInformation.IsOSPlatform(OSPlatform.Windows);
        }

        private static string GetCommandFromPath(string command)
        {
            var values = Environment.GetEnvironmentVariable("PATH");
            foreach (var path in values.Split(';'))
            {
                var fullPath = Path.Combine(path, command);
                if (File.Exists(fullPath))
                    return fullPath;
            }
            return null;
        }
    }
}
