// Copyright (c) .NET Foundation. All rights reserved.
// Licensed under the Apache License, Version 2.0. See License.txt in the project root for license information.

using Microsoft.Extensions.CommandLineUtils;
using System.IO;

namespace KoreBuild.Console.Commands
{
    internal class SubCommandBase : CommandBase
    {
        private CommandOption RepoPathOption { get; set; }

        public string RepoPath
        {
            get
            {
                return RepoPathOption.HasValue() ? RepoPathOption.Value() : Directory.GetCurrentDirectory();
            }
        }

        public override void Configure(CommandLineApplication application)
        {
            var toolSource = application.Option("--toolsSource", "The source to draw tools from.", CommandOptionType.SingleValue);
            RepoPathOption = application.Option("--repoPath", "The path to the repo to work on.", CommandOptionType.SingleValue);
            var dotNetHome = application.Option("--dotNetHome", "The place where dotnet lives", CommandOptionType.SingleValue);

            base.Configure(application);
        }
    }
}
