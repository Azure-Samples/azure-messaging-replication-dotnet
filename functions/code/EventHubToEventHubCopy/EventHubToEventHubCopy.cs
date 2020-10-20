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
        [FunctionName("Replication")]
        public static Task Replication(
            [EventHubTrigger("replication-source-eventhub", ConsumerGroup = "replication", Connection = "replication-source-eventhub-connection")] EventData[] input,
            [EventHub("replication-target-eventhub", Connection = "replication-target-eventhub-connection")] IAsyncCollector<EventData> output,
            ILogger log)
        {
            return EventHubReplicationTasks.ForwardToEventHub(input, output, log);
        }
    }
}
