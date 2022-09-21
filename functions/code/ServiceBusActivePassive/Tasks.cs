using System;
using System.Collections.Generic;
using System.Threading.Tasks;
using Azure.Messaging.EventHubs;
using Microsoft.Azure.WebJobs;
using Microsoft.Extensions.Logging;
using Azure.Messaging.Replication;
using Azure.Messaging.ServiceBus;

namespace ServiceBusActivePassive
{
    public static class Tasks
    {
        //[FunctionName("jobs")]
        //[ExponentialBackoffRetry(-1, "00:00:05", "00:05:00")]
        //public static Task Jobs(
        //    [ServiceBusTrigger("jobs", "replication", Connection = "jobs-left-connection")] Message[] input,
        //    [ServiceBus("jobs", Connection = "jobs-right-connection")] IAsyncCollector<Message> output,
        //    ILogger log)
        //{
        //    return ServiceBusReplicationTasks.ForwardToServiceBus(input, output, log);
        //}
    }
}
