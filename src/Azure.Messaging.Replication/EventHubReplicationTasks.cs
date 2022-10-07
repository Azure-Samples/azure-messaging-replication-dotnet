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

    public class EventHubReplicationTasks
    {
        public static Task ForwardToEventHub(EventData[] input, EventHubProducerClient output,
            ILogger log)
        {
            return ConditionalForwardToEventHub(input, output, log);
        }

        public static Task ConditionalForwardToEventHub(EventData[] input, EventHubProducerClient output,
            ILogger log, Func<EventData, EventData> factory = null)
        {
            var tasks = new List<Task>();
            var noPartitionBatch = new List<EventData>();
            var partitionBatches = new Dictionary<string, List<EventData>>();
            foreach (EventData inputEventData in input)
            {
                var eventData = factory != null ? factory(inputEventData) : inputEventData;
                if (eventData == null)
                {
                    continue;
                }
                eventData.Properties[Constants.ReplEnqueuedTimePropertyName] =
                    (eventData.Properties.ContainsKey(Constants.ReplEnqueuedTimePropertyName)
                        ? eventData.Properties[Constants.ReplEnqueuedTimePropertyName] + ";"
                        : string.Empty) +
                    eventData.EnqueuedTime.ToString("u");
                eventData.Properties[Constants.ReplOffsetPropertyName] =
                    (eventData.Properties.ContainsKey(Constants.ReplOffsetPropertyName)
                        ? eventData.Properties[Constants.ReplOffsetPropertyName] + ";"
                        : string.Empty) +
                    eventData.Offset;
                eventData.Properties[Constants.ReplSequencePropertyName] =
                    (eventData.Properties.ContainsKey(Constants.ReplSequencePropertyName)
                        ? eventData.Properties[Constants.ReplSequencePropertyName] + ";"
                        : string.Empty) +
                    eventData.SequenceNumber.ToString();

                if (eventData.PartitionKey != null)
                {
                    if (!partitionBatches.ContainsKey(eventData.PartitionKey))
                    {
                        partitionBatches[eventData.PartitionKey] = new List<EventData>();
                    }

                    partitionBatches[eventData.PartitionKey].Add(eventData);
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

        public static Task ForwardToServiceBus(EventData[] input, IAsyncCollector<ServiceBusMessage> output,
            ILogger log)
        {
            return ConditionalForwardToServiceBus(input, output, log);
        }

        public static async Task ConditionalForwardToServiceBus(EventData[] input, IAsyncCollector<ServiceBusMessage> output,
            ILogger log, Func<EventData, ServiceBusMessage> factory = null)
        {
            foreach (EventData eventData in input)
            {
                ServiceBusMessage message;

                if (factory != null)
                {
                    message = factory(eventData);
                    if (message == null)
                    {
                        continue;
                    }
                }
                else
                {
                    message = new ServiceBusMessage(eventData.Body.ToArray())
                    {
                        ContentType = eventData.SystemProperties["content-type"] as string,
                        To = eventData.SystemProperties["to"] as string,
                        CorrelationId = eventData.SystemProperties["correlation-id"] as string,
                        ReplyTo = eventData.SystemProperties["reply-to"] as string,
                        ReplyToSessionId = eventData.SystemProperties["reply-to-group-name"] as string,
                        MessageId = eventData.SystemProperties["message-id"] as string ?? eventData.Offset.ToString(),
                        PartitionKey = eventData.PartitionKey,
                        SessionId = eventData.PartitionKey
                    };
                    foreach (var property in eventData.Properties)
                    {
                        message.ApplicationProperties.Add(property);
                    }
                }

                message.ApplicationProperties[Constants.ReplEnqueuedTimePropertyName] =
                    (eventData.Properties.ContainsKey(Constants.ReplEnqueuedTimePropertyName)
                        ? eventData.Properties[Constants.ReplEnqueuedTimePropertyName] + ";"
                        : string.Empty) +
                    eventData.EnqueuedTime.ToString("u");
                message.ApplicationProperties[Constants.ReplOffsetPropertyName] =
                    (eventData.Properties.ContainsKey(Constants.ReplOffsetPropertyName)
                        ? eventData.Properties[Constants.ReplOffsetPropertyName] + ";"
                        : string.Empty) +
                    eventData.Offset;
                message.ApplicationProperties[Constants.ReplSequencePropertyName] =
                    (eventData.Properties.ContainsKey(Constants.ReplSequencePropertyName)
                        ? eventData.Properties[Constants.ReplSequencePropertyName] + ";"
                        : string.Empty) +
                    eventData.SequenceNumber.ToString();

                await output.AddAsync(message);
            }
        }
    }
}