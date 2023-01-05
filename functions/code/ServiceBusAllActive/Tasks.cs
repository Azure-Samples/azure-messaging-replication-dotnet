using System;
using System.Collections.Generic;
using System.Threading.Tasks;
using Azure.Messaging.EventHubs;
using Microsoft.Azure.WebJobs;
using Microsoft.Extensions.Logging;
using Azure.Messaging.Replication;
using Azure.Messaging.ServiceBus;

namespace ServiceBusAllActive
{
    public static class Tasks
    {
        [FunctionName("jobsLeft")]
        [ExponentialBackoffRetry(-1, "00:00:05", "00:05:00")]
        public static Task JobsLeft(
            [ServiceBusTrigger("jobs", "replication", Connection = "jobs-left-connection")] ServiceBusReceivedMessage[] input,
            [ServiceBus("jobs", Connection = "jobs-right-connection")] IAsyncCollector<ServiceBusMessage> output,
            ILogger log)
        {
            return ServiceBusReplicationTasks.ForwardToServiceBus(input, output, log);
        }

        [FunctionName("jobsRight")]
        [ExponentialBackoffRetry(-1, "00:00:05", "00:05:00")]
        public static Task JobsRight(
            [ServiceBusTrigger("jobs", "replication", Connection = "jobs-right-connection")] ServiceBusReceivedMessage[] input,
            [ServiceBus("jobs", Connection = "jobs-left-connection")] IAsyncCollector<ServiceBusMessage> output,
            ILogger log)
        {
            return ServiceBusReplicationTasks.ForwardToServiceBus(input, output, log);
        }
    }
}
