using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using Microsoft.Build.Framework;

namespace Microsoft.AspNetCore.Build
{
    public class TeamCityLogger : INodeLogger
    {
        public string Parameters { get; set; }

        public LoggerVerbosity Verbosity { get; set; }

        public void Initialize(IEventSource eventSource)
        {
            DoInitialize(eventSource);
        }

        public void Initialize(IEventSource eventSource, int nodeCount)
        {
            DoInitialize(eventSource);
        }

        public void Shutdown()
        {
        }

        private void DoInitialize(IEventSource eventSource)
        {
            eventSource.BuildFinished += EventSource_BuildFinished;
            eventSource.BuildStarted += EventSource_BuildStarted;
            eventSource.ErrorRaised += EventSource_ErrorRaised;
            eventSource.MessageRaised += EventSource_MessageRaised;
            eventSource.ProjectFinished += EventSource_ProjectFinished;
            eventSource.ProjectStarted += EventSource_ProjectStarted;
            eventSource.TargetFinished += EventSource_TargetFinished;
            eventSource.TargetStarted += EventSource_TargetStarted;
            eventSource.TaskFinished += EventSource_TaskFinished;
            eventSource.TaskStarted += EventSource_TaskStarted;
            eventSource.WarningRaised += EventSource_WarningRaised;
        }

        private void EventSource_TaskStarted(object sender, TaskStartedEventArgs e)
        {
            WriteTeamCityEvent("blockOpened", e.BuildEventContext, new Dictionary<string, string>() {
                { "name", $"Task:{e.TaskName}" }
            });
        }

        private void EventSource_TaskFinished(object sender, TaskFinishedEventArgs e)
        {
            WriteTeamCityEvent("blockClosed", e.BuildEventContext, new Dictionary<string, string>() {
                { "name", $"Task:{e.TaskName}" }
            });
        }

        private void EventSource_TargetStarted(object sender, TargetStartedEventArgs e)
        {
            WriteTeamCityEvent("blockOpened", e.BuildEventContext, new Dictionary<string, string>() {
                { "name", $"Target:{e.TargetName}" }
            });
        }

        private void EventSource_TargetFinished(object sender, TargetFinishedEventArgs e)
        {
            WriteTeamCityEvent("blockClosed", e.BuildEventContext, new Dictionary<string, string>() {
                { "name", $"Target:{e.TargetName}" }
            });
        }

        private void EventSource_ProjectStarted(object sender, ProjectStartedEventArgs e)
        {
            WriteTeamCityEvent("blockOpened", e.BuildEventContext, new Dictionary<string, string>() {
                { "name", $"Project:{e.ProjectFile}" }
            });
        }

        private void EventSource_ProjectFinished(object sender, ProjectFinishedEventArgs e)
        {
            WriteTeamCityEvent("blockClosed", e.BuildEventContext, new Dictionary<string, string>() {
                { "name", $"Project:{e.ProjectFile}" }
            });
        }

        private void EventSource_WarningRaised(object sender, BuildWarningEventArgs e)
        {
            WriteTeamCityEvent("message", e.BuildEventContext, new Dictionary<string, string>() {
                { "text", $"{e.ProjectFile}({e.LineNumber},{e.ColumnNumber}): {e.Message}" },
                { "status", "WARNING" }
            });
        }

        private void EventSource_MessageRaised(object sender, BuildMessageEventArgs e)
        {
            WriteTeamCityEvent("message", e.BuildEventContext, new Dictionary<string, string>() {
                { "text", $"{e.ProjectFile}({e.LineNumber},{e.ColumnNumber}): {e.Message}" },
                { "status", "NORMAL" }
            });
        }

        private void EventSource_ErrorRaised(object sender, BuildErrorEventArgs e)
        {
            WriteTeamCityEvent("message", e.BuildEventContext, new Dictionary<string, string>() {
                { "text", $"{e.ProjectFile}({e.LineNumber},{e.ColumnNumber}): {e.Message}" },
                { "status", "ERROR" }
            });
        }

        private void EventSource_BuildStarted(object sender, BuildStartedEventArgs e)
        {
            WriteTeamCityEvent("blockOpened", e.BuildEventContext, new Dictionary<string, string>() {
                { "name", $"MSBuild" }
            });
        }

        private void EventSource_BuildFinished(object sender, BuildFinishedEventArgs e)
        {
            WriteTeamCityEvent("blockClosed", e.BuildEventContext, new Dictionary<string, string>() {
                { "name", $"MSBuild" }
            });
        }

        private void WriteTeamCityEvent(string name, BuildEventContext context, IDictionary<string, string> args)
        {
            var date = DateTimeOffset.Now;
            var timestamp = $"{date:yyyy-MM-dd'T'HH:mm:ss.fff}{date.Offset.Ticks:+;-;}{date.Offset:hhmm}";

            var message = new StringBuilder();
            message.Append($"##teamcity[{Escape(name)} timestamp='{timestamp}' flowId='{Escape(context?.NodeId ?? 1)}'");
            if (args != null && args.Any())
            {
                foreach (var arg in args)
                {
                    message.Append($" {arg.Key}='{Escape(arg.Value)}'");
                }
            }
            message.Append("]");
            Console.WriteLine(message.ToString());
        }

        private string Escape(object value)
        {
            return value.ToString()
                .Replace("|", "||")
                .Replace("'", "|'")
                .Replace("\r", "|r")
                .Replace("\n", "|n")
                .Replace("[", "|[")
                .Replace("]", "|]");
        }
    }
}
