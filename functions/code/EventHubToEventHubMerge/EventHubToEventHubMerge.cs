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
        [FunctionName("Eh1ToEh2")]
        [ExponentialBackoffRetry(-1, "00:00:05", "00:05:00")]
        public static Task Eh1ToEh2(
            [EventHubTrigger("eh1", ConsumerGroup = "Eh1ToEh2", Connection = "Eh1ToEh2-source-connection")] EventData[] input,
            [EventHub("eh2", Connection = "Eh1ToEh2-target-connection")] EventHubClient outputClient,
            ILogger log)
        {
            return EventHubReplicationTasks.ConditionalForwardToEventHub(input, outputClient, log, (inputEvent) => {
                // if the inputEvent didn't get into eh1 by ways of replication, move it into eh2 and mark it for eh2
                if ( !inputEvent.Properties.ContainsKey("repl-target") || inputEvent.Properties["repl-target"] as string != "eh1") {
                      inputEvent.Properties["repl-target"] = "eh2";
                      return inputEvent;
                }
                return null;
            });
        }

        [FunctionName("Eh2ToEh1")]
        [ExponentialBackoffRetry(-1, "00:00:05", "00:05:00")]
        public static Task Eh2ToEh1(
            [EventHubTrigger("eh2", ConsumerGroup = "Eh2ToEh1", Connection = "Eh2ToEh1-source-connection")] EventData[] input,
            [EventHub("eh1", Connection = "Eh2ToEh1-target-connection")] EventHubClient outputClient,
            ILogger log)
        {
            return EventHubReplicationTasks.ConditionalForwardToEventHub(input, outputClient, log, (inputEvent) => {
                // if the inputEvent didn't get into eh2 by ways of replication, move it into eh1 and mark it for eh1
                if ( !inputEvent.Properties.ContainsKey("repl-target") || inputEvent.Properties["repl-target"] as string != "eh2") {
                      inputEvent.Properties["repl-target"] = "eh1";
                      return inputEvent;
                }
                return null;
            });
        }
    }
}
