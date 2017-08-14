// Copyright (c) .NET Foundation. All rights reserved.
// Licensed under the Apache License, Version 2.0. See License.txt in the project root for license information.

using Microsoft.Extensions.CommandLineUtils;
using System.Reflection;

namespace KoreBuild.Commands
{
    public class RootCommand : CommandBase
    {
        public override void Configure(CommandLineApplication application)
        {
            application.FullName = "korebuild";

            application.Command("docker-build", new DockerBuildCommand().Configure);
            application.Command("install-tools", new InstallToolsCommand().Configure);
            application.Command("msbuild", new MsBuild().Configure);
            // more commands

            application.VersionOption("--version", GetVersion);
            base.Configure(application);
        }

        private static string GetVersion()
                => typeof(RootCommand).GetTypeInfo().Assembly.GetCustomAttribute<AssemblyInformationalVersionAttribute>()
                    .InformationalVersion;
    }

}
