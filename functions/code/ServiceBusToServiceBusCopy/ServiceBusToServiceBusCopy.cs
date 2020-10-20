using System;
using System.Collections.Generic;
using System.Threading.Tasks;
using Microsoft.Azure.EventHubs;
using Microsoft.Azure.WebJobs;
using Microsoft.Extensions.Logging;
using Azure.Messaging.Replication;
using Microsoft.Azure.ServiceBus;

namespace EventHubToEventHubCopy
{
    public static class Tasks
    {
        [FunctionName("source_eventhub_to_target_eventhub")]
        public static Task source_eventhub_to_target_eventhub(
            [ServiceBusTrigger("source-queue", Connection = "source-queue-connection")] Message[] input,
            [ServiceBus("target-queue", Connection = "target-queue-connection")] IAsyncCollector<Message> output,
            ILogger log)
        {
            return ServiceBusReplicationTasks.ForwardToServiceBus(input, output, log);
        }
    }
}
