// Copyright (c) .NET Foundation. All rights reserved.
// Licensed under the Apache License, Version 2.0. See License.txt in the project root for license information.

using Microsoft.Extensions.CommandLineUtils;
using System.Collections.Generic;
using System.Threading.Tasks;

namespace KoreBuild.Console.Commands
{
    internal class PushToNugetCommand : SubCommandBase
    {
        private CommandArgument FeedArgument{ get; set; }
        private CommandArgument APIKeyArgument { get; set; }
        private CommandOption PackagesOption { get; set; }
        private CommandOption RetriesOption { get; set; }
        private CommandOption MaxParallelOption { get; set; }

        public string Feed => FeedArgument.Value;
        public string APIKey => APIKeyArgument.Value;
        public List<string> Packages => PackagesOption.Values;
        public int Retries => RetriesOption.HasValue() ? int.Parse(RetriesOption.Value()) : 5;
        public int MaxParallel => MaxParallelOption.HasValue() ? int.Parse(MaxParallelOption.Value()) : 4;

        public override void Configure(CommandLineApplication application)
        {
            FeedArgument = application.Argument("feed", "The feed we'll be pushing to.");
            APIKeyArgument = application.Argument("apikey", "The APIKey used to push packages.");
            PackagesOption = application.Option("--packages", "The packages to be uploaded", CommandOptionType.MultipleValue);
            RetriesOption = application.Option("--retries", "The number of times to retry package upload", CommandOptionType.SingleValue);
            MaxParallelOption = application.Option("--maxParallel", "The maximum number of attempts to make in parallel.", CommandOptionType.SingleValue);

            base.Configure(application);
        }

        protected override bool IsValid()
        {
            if(string.IsNullOrEmpty(Feed))
            {
                return false;
            }
            if(Packages == null || Packages.Count < 1)
            {
                return false;
            }

            return true;
        }

        protected override int Execute()
        {
            var parallelOptions = new ParallelOptions {
                MaxDegreeOfParallelism = MaxParallel
            };

            var success = true;

            Parallel.ForEach(Packages, parallelOptions, (package, state) =>
            {
                bool packageSuccess = false;
                var retry = 0;
                while(retry < Retries)
                {
                    var args = new List<string> {
                        "nuget", "push", package,
                        "--source", Feed,
                        "--timeout", "300"
                    };

                    if(!string.IsNullOrEmpty(APIKey))
                    {
                        args.AddRange(new string[]{ "--api-key", APIKey });
                    }

                    var pushResult = RunDotnet(args.ToArray());

                    if(pushResult != 0)
                    {
                        Log($"Exit code {pushResult}. Failed to push '{package}' on attempt {retry}");
                        retry++;
                    }
                    else
                    {
                        success = true;
                        break;
                    }
                }

                if(!success)
                {
                    Log($"Failed to upload {package} after {Retries} retries.");
                    success = false;
                    state.Break();
                }
            });

            return success ? 0 : 1;
        }
    }
}
