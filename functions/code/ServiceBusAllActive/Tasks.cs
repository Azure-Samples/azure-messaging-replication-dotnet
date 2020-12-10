using System;
using System.Collections.Generic;
using System.Threading.Tasks;
using Microsoft.Azure.EventHubs;
using Microsoft.Azure.WebJobs;
using Microsoft.Extensions.Logging;
using Azure.Messaging.Replication;
using Microsoft.Azure.ServiceBus;

namespace ServiceBusActivePassive
{
    public static class Tasks
    {
        [FunctionName("QueueAtoQueueB")]
        [ExponentialBackoffRetry(-1, "00:00:05", "00:05:00")]
        public static Task QueueAtoQueueB(
            [ServiceBusTrigger("queueA", Connection = "QueueAtoQueueB-source-connection")] Message[] input,
            [ServiceBus("queueB", Connection = "QueueAtoQueueB-target-connection")] IAsyncCollector<Message> output,
            ILogger log)
        {
            return ServiceBusReplicationTasks.ForwardToServiceBus(input, output, log);
        }
    }
}
