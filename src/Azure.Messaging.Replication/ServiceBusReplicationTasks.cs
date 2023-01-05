// Copyright (c) Microsoft Corporation.
// See LICENSE file in the project root for full license information.

namespace Azure.Messaging.Replication
{
    using System;
    using System.Collections.Generic;
    using System.Threading.Tasks;
    using Azure.Messaging.EventHubs;
    using Azure.Messaging.EventHubs.Producer;
    using Azure.Messaging.ServiceBus;
    using Microsoft.Azure.WebJobs;
    using Microsoft.Extensions.Logging;

    public class ServiceBusReplicationTasks
    {
        public static Task ForwardToEventHub(ServiceBusReceivedMessage[] input, EventHubProducerClient output, ILogger log)
        {
            return ConditionalForwardToEventHub(input, output, log);
        }

        public static Task ConditionalForwardToEventHub(ServiceBusReceivedMessage[] input, EventHubProducerClient output, ILogger log, Func<ServiceBusReceivedMessage, EventData> factory = null)
        {
            var tasks = new List<Task>();
            var noPartitionBatch = new List<EventData>();
            var partitionBatches = new Dictionary<string, List<EventData>>();

            foreach (var message in input)
            {
                EventData eventData;
                var key = message.PartitionKey ?? message.SessionId;

                if (factory != null)
                {
                    eventData = factory(message);
                    if (eventData == null)
                    {
                        continue;
                    }
                }
                else
                {
                    eventData = new EventData(message.Body);
                    foreach (var property in message.ApplicationProperties)
                    {
                        eventData.Properties.Add(property);
                    }
                }

                eventData.Properties[Constants.ReplEnqueuedTimePropertyName] =
                    (message.ApplicationProperties.ContainsKey(Constants.ReplEnqueuedTimePropertyName)
                        ? message.ApplicationProperties[Constants.ReplEnqueuedTimePropertyName] + ";"
                        : string.Empty) +
                    message.ScheduledEnqueueTime.ToString("u");

                eventData.Properties[Constants.ReplOffsetPropertyName] =
                   (message.ApplicationProperties.ContainsKey(Constants.ReplOffsetPropertyName)
                        ? message.ApplicationProperties[Constants.ReplOffsetPropertyName] + ";"
                        : string.Empty) +
                    message.SequenceNumber.ToString();

                eventData.Properties[Constants.ReplSequencePropertyName] =
                    (message.ApplicationProperties.ContainsKey(Constants.ReplSequencePropertyName)
                        ? message.ApplicationProperties[Constants.ReplSequencePropertyName] + ";"
                        : string.Empty) +
                    message.SequenceNumber.ToString();

                if (key != null)
                {
                    if (!partitionBatches.ContainsKey(key))
                    {
                        partitionBatches[key] = new List<EventData>();
                    }

                    partitionBatches[key].Add(eventData);
                }
                else
                {
                    noPartitionBatch.Add(eventData);
                }
            }

            if (noPartitionBatch.Count > 0)
            {
                tasks.Add(output.SendAsync(noPartitionBatch));
            }

            if (partitionBatches.Count > 0)
            {
                foreach (var batch in partitionBatches)
                {
                    var options = new SendEventOptions
                    {
                        PartitionKey = batch.Key
                    };
                    tasks.Add(output.SendAsync(batch.Value, options));
                }
            }

            return Task.WhenAll(tasks);
        }


        public static Task ForwardToServiceBus(ServiceBusReceivedMessage[] input, IAsyncCollector<ServiceBusMessage> output,
            ILogger log)
        {
            return ConditionalForwardToServiceBus(input, output, log);
        }

        public static async Task ConditionalForwardToServiceBus(ServiceBusReceivedMessage[] input, IAsyncCollector<ServiceBusMessage> output,
            ILogger log, Func<ServiceBusReceivedMessage, ServiceBusMessage> factory = null)
        {
            foreach (ServiceBusReceivedMessage message in input)
            {
                var forwardedMessage = factory != null ? factory(message) : new ServiceBusMessage(message); //?

                if (forwardedMessage == null)
                {
                    continue;
                }
                forwardedMessage.ApplicationProperties[Constants.ReplEnqueuedTimePropertyName] =
                    (message.ApplicationProperties.ContainsKey(Constants.ReplEnqueuedTimePropertyName)
                        ? message.ApplicationProperties[Constants.ReplEnqueuedTimePropertyName] + ";"
                        : string.Empty) +
                    message.ScheduledEnqueueTime.ToString("u");
                forwardedMessage.ApplicationProperties[Constants.ReplOffsetPropertyName] =
                    (message.ApplicationProperties.ContainsKey(Constants.ReplOffsetPropertyName)
                        ? message.ApplicationProperties[Constants.ReplOffsetPropertyName] + ";"
                        : string.Empty) +
                    message.SequenceNumber.ToString();
                forwardedMessage.ApplicationProperties[Constants.ReplSequencePropertyName] =
                    (message.ApplicationProperties.ContainsKey(Constants.ReplSequencePropertyName)
                        ? message.ApplicationProperties[Constants.ReplSequencePropertyName] + ";"
                        : string.Empty) +
                    message.SequenceNumber.ToString();
                await output.AddAsync(forwardedMessage);
            }
        }
    }
}