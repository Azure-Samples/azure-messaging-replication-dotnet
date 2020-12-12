using System;
using System.Collections.Generic;
using System.Threading.Tasks;
using Microsoft.Azure.EventHubs;
using Microsoft.Azure.WebJobs;
using Microsoft.Extensions.Logging;
using Azure.Messaging.Replication;
using Microsoft.Azure.ServiceBus;

namespace ServiceBusCopy
{
    public static class Tasks
    {
        [FunctionName("jobs-transfer")]
        [ExponentialBackoffRetry(-1, "00:00:05", "00:05:00")]
        public static Task JobsTransfer(
            [ServiceBusTrigger("jobs-transfer", Connection = "jobs-transfer-source-connection")] Message[] input,
            [ServiceBus("jobs", Connection = "jobs-target-connection")] IAsyncCollector<Message> output,
            ILogger log)
        {
            return ServiceBusReplicationTasks.ForwardToServiceBus(input, output, log);
        }
    }
}
