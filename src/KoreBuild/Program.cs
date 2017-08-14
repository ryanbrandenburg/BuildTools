// Copyright (c) .NET Foundation. All rights reserved.
// Licensed under the Apache License, Version 2.0. See License.txt in the project root for license information.

using KoreBuild.Commands;
using Microsoft.Extensions.CommandLineUtils;
using System;

namespace KoreBuild
{
    class Program
    {
        static int Main(string[] args)
        {
            var application = new CommandLineApplication()
            {
                Name = "korebuild"
            };

            new RootCommand().Configure(application);

            try
            {
                return application.Execute(args);
            }
            catch (Exception)
            {
                return 1;
            }
        }
    }
}
