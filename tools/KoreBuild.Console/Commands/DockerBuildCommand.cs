// Copyright (c) .NET Foundation. All rights reserved.
// Licensed under the Apache License, Version 2.0. See License.txt in the project root for license information.

using Microsoft.Extensions.CommandLineUtils;
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;

namespace KoreBuild.Console.Commands
{
    internal class DockerBuildCommand : SubCommandBase
    {
        private CommandArgument Platform { get; set; }

        private List<string> Arguments { get; set; }

        private string ContainerName { get; set; } = "testcontainer";

        public override void Configure(CommandLineApplication application)
        {
            Platform = application.Argument("platform", "The docker platform to run on.");
            Arguments = application.RemainingArguments;

            base.Configure(application);
        }

        protected override bool IsValid()
        {
            return !string.IsNullOrEmpty(Platform.Value);
        }

        protected override int Execute()
        {
            // TODO: Check path for docker
            var dockerFileName = $"{Platform.Value}.dockerFile";
            var dockerFileDestination = Path.Combine(RepoPath, dockerFileName);
            var dockerFileSource = Path.Combine(Directory.GetCurrentDirectory(), "Commands", "DockerFiles" , dockerFileName);

            File.Copy(dockerFileSource, dockerFileDestination, true);

            var buildArgs = new List<string> { "build" };

            buildArgs.AddRange(new string[] { "-t", ContainerName, "-f", dockerFileDestination, RepoPath });
            var buildResult = RunDockerCommand(buildArgs);

            if(buildResult != 0)
            {
                return buildResult;
            }

            var runArgs = new List<string> { "run", "--rm", "-it", "--name", ContainerName, ContainerName };

            if (Arguments != null && Arguments.Count > 0)
            {
                var argString = String.Join(" ", Arguments);
                runArgs.Add(argString);
            }

            return RunDockerCommand(runArgs);
        }

        private int RunDockerCommand(List<string> arguments)
        {
            var args = ArgumentEscaper.EscapeAndConcatenate(arguments.ToArray());
            System.Console.WriteLine($"Running 'docker {args}'");

            var psi = new ProcessStartInfo
            {
                FileName = "docker",
                Arguments = args
            };

            var process = Process.Start(psi);
            process.WaitForExit();

            return process.ExitCode;
        }
    }
}
