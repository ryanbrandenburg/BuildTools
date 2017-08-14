// Copyright (c) .NET Foundation. All rights reserved.
// Licensed under the Apache License, Version 2.0. See License.txt in the project root for license information.

using Microsoft.Extensions.CommandLineUtils;
using System.Collections.Generic;

namespace KoreBuild.Commands
{
    public class DockerBuildCommand : CommandBase
    {
        private CommandArgument Platform { get; set; }
        private List<string> Arguments { get; set; }

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
            Process cmd = new Process();
        }
    }
}
