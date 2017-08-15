// Copyright (c) .NET Foundation. All rights reserved.
// Licensed under the Apache License, Version 2.0. See License.txt in the project root for license information.

using Microsoft.Extensions.CommandLineUtils;
using System;

namespace KoreBuild.Console.Commands
{
    internal class MSBuildCommand : SubCommandBase
    {
        public override void Configure(CommandLineApplication application)
        {
            base.Configure(application);
        }

        protected override int Execute()
        {
            throw new NotImplementedException();
        }
    }
}
