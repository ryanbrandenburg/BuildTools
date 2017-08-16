// Copyright (c) .NET Foundation. All rights reserved.
// Licensed under the Apache License, Version 2.0. See License.txt in the project root for license information.

using Microsoft.Extensions.CommandLineUtils;
using System;
using System.IO;

namespace KoreBuild.Console.Commands
{
    internal class SubCommandBase : CommandBase
    {
        private string DefaultToolsSource = "https://aspnetcore.blob.core.windows.net/buildtools";
        private CommandOption RepoPathOption { get; set; }
        private CommandOption DotNetHomeOption { get; set; }
        private CommandOption ToolsSourceOption { get; set; }

        public string RepoPath => RepoPathOption.HasValue() ? RepoPathOption.Value() : Directory.GetCurrentDirectory();

        public string DotNetHome => GetDotNetHome();

        public string ToolsSource => ToolsSourceOption.HasValue() ? ToolsSourceOption.Value() : DefaultToolsSource;

        public override void Configure(CommandLineApplication application)
        {
            var toolSource = application.Option("--toolsSource", "The source to draw tools from.", CommandOptionType.SingleValue);
            RepoPathOption = application.Option("--repoPath", "The path to the repo to work on.", CommandOptionType.SingleValue);
            DotNetHomeOption = application.Option("--dotNetHome", "The place where dotnet lives", CommandOptionType.SingleValue);

            base.Configure(application);
        }

        private string GetDotNetHome()
        {
            var dotnetHome = Environment.GetEnvironmentVariable("DOTNET_HOME");
            var userProfile = Environment.GetEnvironmentVariable("USERPROFILE");
            var home = Environment.GetEnvironmentVariable("HOME");

            var result = Path.Combine(Directory.GetCurrentDirectory(), ".dotnet");
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
                result = userProfile;
            }
            else if (!string.IsNullOrEmpty(home))
            {
                result = home;
            }

            return result;
        }
    }
}
