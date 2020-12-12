// Copyright (c) Microsoft Corporation.
// See LICENSE file in the project root for full license information.

namespace Azure.Messaging.Replication
{
    using System;
    using System.Collections.Generic;
    using System.Threading.Tasks;
    using Microsoft.Azure.EventHubs;
    using Microsoft.Azure.ServiceBus;
    using Microsoft.Azure.WebJobs;
    using Microsoft.Extensions.Logging;

    public class EventHubReplicationTasks
    {
        public static Task ForwardToEventHub(EventData[] input, EventHubClient output,
            ILogger log)
        {
            return ConditionalForwardToEventHub(input, output, log);
        }

        public static Task ConditionalForwardToEventHub(EventData[] input, EventHubClient output,
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
                    eventData.SystemProperties.EnqueuedTimeUtc.ToString("u");
                eventData.Properties[Constants.ReplOffsetPropertyName] =
                    (eventData.Properties.ContainsKey(Constants.ReplOffsetPropertyName)
                        ? eventData.Properties[Constants.ReplOffsetPropertyName] + ";"
                        : string.Empty) +
                    eventData.SystemProperties.Offset;
                eventData.Properties[Constants.ReplSequencePropertyName] =
                    (eventData.Properties.ContainsKey(Constants.ReplSequencePropertyName)
                        ? eventData.Properties[Constants.ReplSequencePropertyName] + ";"
                        : string.Empty) +
                    eventData.SystemProperties.SequenceNumber.ToString();

                if (eventData.SystemProperties.PartitionKey != null)
                {
                    if (!partitionBatches.ContainsKey(eventData.SystemProperties.PartitionKey))
                    {
                        partitionBatches[eventData.SystemProperties.PartitionKey] = new List<EventData>();
                    }

                    partitionBatches[eventData.SystemProperties.PartitionKey].Add(eventData);
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
                    tasks.Add(output.SendAsync(batch.Value, batch.Key));
                }
            }

            return Task.WhenAll(tasks);
        }

        public static Task ForwardToServiceBus(EventData[] input, IAsyncCollector<Message> output,
            ILogger log)
        {
            return ConditionalForwardToServiceBus(input, output, log);
        }

        public static async Task ConditionalForwardToServiceBus(EventData[] input, IAsyncCollector<Message> output,
            ILogger log, Func<EventData, Message> factory = null)
        {
            foreach (EventData eventData in input)
            {
                Message message;

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
                    message = new Message(eventData.Body.ToArray())
                    {
                        ContentType = eventData.SystemProperties["content-type"] as string,
                        To = eventData.SystemProperties["to"] as string,
                        CorrelationId = eventData.SystemProperties["correlation-id"] as string,
                        Label = eventData.SystemProperties["subject"] as string,
                        ReplyTo = eventData.SystemProperties["reply-to"] as string,
                        ReplyToSessionId = eventData.SystemProperties["reply-to-group-name"] as string,
                        MessageId = eventData.SystemProperties["message-id"] as string ?? eventData.SystemProperties.Offset,
                        PartitionKey = eventData.SystemProperties.PartitionKey,
                        SessionId = eventData.SystemProperties.PartitionKey
                    };
                    foreach (var property in eventData.Properties)
                    {
                        message.UserProperties.Add(property);
                    }
                }

                message.UserProperties[Constants.ReplEnqueuedTimePropertyName] =
                    (eventData.Properties.ContainsKey(Constants.ReplEnqueuedTimePropertyName)
                        ? eventData.Properties[Constants.ReplEnqueuedTimePropertyName] + ";"
                        : string.Empty) +
                    eventData.SystemProperties.EnqueuedTimeUtc.ToString("u");
                message.UserProperties[Constants.ReplOffsetPropertyName] =
                    (eventData.Properties.ContainsKey(Constants.ReplOffsetPropertyName)
                        ? eventData.Properties[Constants.ReplOffsetPropertyName] + ";"
                        : string.Empty) +
                    eventData.SystemProperties.Offset;
                message.UserProperties[Constants.ReplSequencePropertyName] =
                    (eventData.Properties.ContainsKey(Constants.ReplSequencePropertyName)
                        ? eventData.Properties[Constants.ReplSequencePropertyName] + ";"
                        : string.Empty) +
                    eventData.SystemProperties.SequenceNumber.ToString();

                await output.AddAsync(message);
            }
        }
    }
}