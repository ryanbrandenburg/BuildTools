// Copyright (c) .NET Foundation. All rights reserved.
// Licensed under the Apache License, Version 2.0. See License.txt in the project root for license information.

using System;
using System.IO;
using System.Linq;
using Microsoft.Build.Framework;
using Microsoft.Build.Utilities;
using Newtonsoft.Json.Linq;
using NuGet.Frameworks;

namespace Microsoft.AspNetCore.Build.Tasks
{
    public class GatherProjectMetadata : Task
    {
        [Required]
        public ITaskItem[] Projects { get; set; }

        [Output]
        public ITaskItem[] UpdatedProjects { get; set; }

        public override bool Execute()
        {
            UpdatedProjects = new ITaskItem[Projects.Length];
            for (var i = 0; i < Projects.Length; i++)
            {
                var project = new TaskItem(Projects[i]);
                AddProjectMetadata(project);
                UpdatedProjects[i] = project;
            }
            Log.LogMessage($"Collected metadata for {Projects.Length} projects");
            return true;
        }

        private void AddProjectMetadata(TaskItem project)
        {
            var fullPath = project.GetMetadata("FullPath");

            // Target Framework
            var json = JObject.Parse(File.ReadAllText(fullPath));
            var frameworks = json["frameworks"];
            if (frameworks != null && frameworks.Type == JTokenType.Object)
            {
                var frameworkNames = ((JObject)frameworks).Properties().Select(p => Tuple.Create(p.Name, NuGetFramework.Parse(p.Name)));
                project.SetMetadata("TargetFrameworks", string.Join(";", frameworkNames.Select(f => f.Item1)));
                foreach (var framework in frameworkNames)
                {
                    project.SetMetadata($"TFM_{framework.Item1.Replace('.', '_')}", "true");
                }

                // Add version-less items
                foreach(var framework in frameworkNames.Select(f => f.Item2.Framework).Distinct())
                {
                    project.SetMetadata($"TFM_FX_{framework.Replace('.', '_')}", "true");
                }

                // Check if there are non-desktop TFMs
                var nonDesktopTfms = frameworkNames.Where(t => !t.Item2.IsDesktop()).ToList();
                project.SetMetadata("NonDesktopTargetFrameworks", string.Join(";", nonDesktopTfms.Select(f => f.Item1)));
            }

            // Paths and stuff (directories have trailing '\' to match MSBuild conventions)
            var dir = Path.GetDirectoryName(fullPath);
            project.SetMetadata("ProjectDir", dir + Path.DirectorySeparatorChar);
            project.SetMetadata("ProjectName", Path.GetFileName(dir));
            project.SetMetadata("SharedSourcesDir", Path.Combine(dir, "shared") + Path.DirectorySeparatorChar);
            project.SetMetadata("GeneratedBuildInfoFile", Path.Combine(dir, "BuildInfo.generated.cs"));

            // Determine output type
            var buildOptions = json["buildOptions"];
            if (buildOptions != null && buildOptions.Type == JTokenType.Object)
            {
                var emitEntryPoint = ((JObject)buildOptions)["emitEntryPoint"];
                if (emitEntryPoint != null && emitEntryPoint.Value<bool>())
                {
                    project.SetMetadata("EmitEntryPoint", "true");
                }
            }

            var group = Path.GetFileName(Path.GetDirectoryName(dir));
            project.SetMetadata("ProjectGroup", group);
        }
    }
}
