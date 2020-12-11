using System;
using System.Collections.Generic;
using System.Threading.Tasks;
using Microsoft.Azure.EventHubs;
using Microsoft.Azure.WebJobs;
using Microsoft.Extensions.Logging;
using Azure.Messaging.Replication;
using Microsoft.Azure.ServiceBus;

namespace ServiceBusAllActive
{
    public static class Tasks
    {
        [FunctionName("jobsLeft")]
        [ExponentialBackoffRetry(-1, "00:00:05", "00:05:00")]
        public static Task JobsLeft(
            [ServiceBusTrigger("jobs", "replication", Connection = "jobs-left-connection")] Message[] input,
            [ServiceBus("jobs", Connection = "jobs-right-connection")] IAsyncCollector<Message> output,
            ILogger log)
        {
            return ServiceBusReplicationTasks.ForwardToServiceBus(input, output, log);
        }

        [FunctionName("jobsRight")]
        [ExponentialBackoffRetry(-1, "00:00:05", "00:05:00")]
        public static Task JobsRight(
            [ServiceBusTrigger("jobs", "replication", Connection = "jobs-right-connection")] Message[] input,
            [ServiceBus("jobs", Connection = "jobs-left-connection")] IAsyncCollector<Message> output,
            ILogger log)
        {
            return ServiceBusReplicationTasks.ForwardToServiceBus(input, output, log);
        }
    }
}
