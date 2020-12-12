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
        const string taskTelemetryLeft = "telemetry-left";
        const string taskTelemetryRight =  "telemetry-right";
        const string rightEventHubName = "telemetry";
        const string leftEventHubName = "telemetry";
        const string rightEventHubConnection = "telemetry-right-connection";
        const string leftEventHubConnection = "telemetry-left-connection";
        const string leftEventHubConsumerGroup = "%telemetry-left-consumergroup%";
        const string rightEventHubConsumerGroup = "%telemetry-right-consumergroup%";
        
        [FunctionName(taskTelemetryLeft)]
        [ExponentialBackoffRetry(-1, "00:00:05", "00:05:00")]
        public static Task TelemetryLeft(
            [EventHubTrigger(leftEventHubName, ConsumerGroup = leftEventHubConsumerGroup, Connection = leftEventHubConnection)] EventData[] input,
            [EventHub(rightEventHubName, Connection = rightEventHubConnection)] EventHubClient outputClient,
            ILogger log)
        {
            return EventHubReplicationTasks.ConditionalForwardToEventHub(input, outputClient, log, (inputEvent) => {
                if ( !inputEvent.Properties.ContainsKey("repl-target") || 
                     !string.Equals(inputEvent.Properties["repl-target"] as string, leftEventHubName)) {
                      inputEvent.Properties["repl-target"] = rightEventHubName;
                      return inputEvent;
                }
                return null;
            });
        }

        [FunctionName(taskTelemetryRight)]
        [ExponentialBackoffRetry(-1, "00:00:05", "00:05:00")]
        public static Task TelemetryRight(
            [EventHubTrigger(rightEventHubName, ConsumerGroup = rightEventHubConsumerGroup, Connection = rightEventHubConnection)] EventData[] input,
            [EventHub(leftEventHubName, Connection = leftEventHubConnection)] EventHubClient outputClient,
            ILogger log)
        {
            return EventHubReplicationTasks.ConditionalForwardToEventHub(input, outputClient, log, (inputEvent) => {
                if ( !inputEvent.Properties.ContainsKey("repl-target") || 
                     !string.Equals(inputEvent.Properties["repl-target"] as string, rightEventHubName)) {
                      inputEvent.Properties["repl-target"] = leftEventHubName;
                      return inputEvent;
                }
                return null;
            });
        }
    }
}
