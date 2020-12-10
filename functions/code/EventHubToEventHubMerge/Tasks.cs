using System;
using System.Collections.Generic;
using System.Threading.Tasks;
using Microsoft.Azure.EventHubs;
using Microsoft.Azure.WebJobs;
using Microsoft.Extensions.Logging;
using Azure.Messaging.Replication;

namespace EventHubToEventHubMerge
{
    public static class Tasks
    {
        static const string functionAppName = "merge-example";
        static const string taskTelemetryLeftToRight = "telemetry-westeurope-to-eastus2";
        static const string taskTelemetryRightToLeft =  "telemetry-eastus2-to-westeurope";
        static const string rightEventHubName = "telemetry";
        static const string leftEventHubName = "telemetry";
        static const string rightEventHubConnection = "telemetry-eus2-connection";
        static const string leftEventHubConnection = "telemetry-weu-connection";
        
        [FunctionName(taskTelemetryLeftToRight)]
        [ExponentialBackoffRetry(-1, "00:00:05", "00:05:00")]
        public static Task TelemetryLeftToRight(
            [EventHubTrigger(leftEventHubName, ConsumerGroup = $"{functionAppName}.{taskTelemetryLeftToRight}", Connection = leftEventHubConnection)] EventData[] input,
            [EventHub(rightEventHubName, Connection = rightEventHubConnection)] EventHubClient outputClient,
            ILogger log)
        {
            return EventHubReplicationTasks.ConditionalForwardToEventHub(input, outputClient, log, (inputEvent) => {
                const string replyTarget = $"{functionAppName}.{taskTelemetryLeftToRight}";
                if ( !inputEvent.Properties.ContainsKey("repl-target") || 
                     !string.Equals(inputEvent.Properties["repl-target"] as string, leftEventHubName) {
                      inputEvent.Properties["repl-target"] = rightEventHubName;
                      return inputEvent;
                }
                return null;
            });
        }

        [FunctionName(taskTelemetryRightToLeft)]
        [ExponentialBackoffRetry(-1, "00:00:05", "00:05:00")]
        public static Task TelemetryRightToLeft(
            [EventHubTrigger(rightEventHubName, ConsumerGroup = $"{functionAppName}.{taskTelemetryRightToLeft}", Connection = rightEventHubConnection)] EventData[] input,
            [EventHub(leftEventHubName, Connection = leftEventHubConnection)] EventHubClient outputClient,
            ILogger log)
        {
            return EventHubReplicationTasks.ConditionalForwardToEventHub(input, outputClient, log, (inputEvent) => {
                if ( !inputEvent.Properties.ContainsKey("repl-target") || 
                     !string.Equals(inputEvent.Properties["repl-target"] as string, rightEventHubName) {
                      inputEvent.Properties["repl-target"] = leftEventHubName;
                      return inputEvent;
                }
                return null;
            });
        }
    }
}
