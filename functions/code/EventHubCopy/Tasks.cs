using System;
using System.Collections.Generic;
using System.Threading.Tasks;
using Microsoft.Azure.EventHubs;
using Microsoft.Azure.WebJobs;
using Microsoft.Extensions.Logging;
using Azure.Messaging.Replication;

namespace EventHubToEventHubCopy
{
    public static class Tasks
    {
        [FunctionName("telemetry")]
        [ExponentialBackoffRetry(-1, "00:00:05", "00:05:00")]
        public static Task Telemetry(
            [EventHubTrigger("telemetry", ConsumerGroup = "repl-example-weu.telemetry", Connection = "telemetry-source-connection")] EventData[] input,
            [EventHub("telemetry-copy", Connection = "telemetry-target-connection")] EventHubClient outputClient,
            ILogger log)
        {
            return EventHubReplicationTasks.ForwardToEventHub(input, outputClient, log);
        }
    }
}
