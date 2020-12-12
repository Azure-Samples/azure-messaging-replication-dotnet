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

    public class ServiceBusReplicationTasks
    {
        public static Task ForwardToEventHub(Message[] input, EventHubClient output, ILogger log)
        {
            return ConditionalForwardToEventHub(input, output, log);
        }

        public static Task ConditionalForwardToEventHub(Message[] input, EventHubClient output, ILogger log, Func<Message, EventData> factory = null)
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
                    foreach (var property in message.UserProperties)
                    {
                        eventData.Properties.Add(property);
                    }
                }

                eventData.Properties[Constants.ReplEnqueuedTimePropertyName] =
                    (message.UserProperties.ContainsKey(Constants.ReplEnqueuedTimePropertyName)
                        ? message.UserProperties[Constants.ReplEnqueuedTimePropertyName] + ";"
                        : string.Empty) +
                    message.SystemProperties.EnqueuedTimeUtc.ToString("u");
                eventData.Properties[Constants.ReplOffsetPropertyName] =
                   (message.UserProperties.ContainsKey(Constants.ReplOffsetPropertyName)
                        ? message.UserProperties[Constants.ReplOffsetPropertyName] + ";"
                        : string.Empty) +
                    message.SystemProperties.EnqueuedSequenceNumber.ToString();
                eventData.Properties[Constants.ReplSequencePropertyName] =
                    (message.UserProperties.ContainsKey(Constants.ReplSequencePropertyName)
                        ? message.UserProperties[Constants.ReplSequencePropertyName] + ";"
                        : string.Empty) +
                    message.SystemProperties.EnqueuedSequenceNumber.ToString();

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
                    tasks.Add(output.SendAsync(batch.Value, batch.Key));
                }
            }

            return Task.WhenAll(tasks);
        }


        public static Task ForwardToServiceBus(Message[] input, IAsyncCollector<Message> output,
            ILogger log)
        {
            return ConditionalForwardToServiceBus(input, output, log);
        }

        public static async Task ConditionalForwardToServiceBus(Message[] input, IAsyncCollector<Message> output,
            ILogger log, Func<Message, Message> factory = null)
        {
            foreach (Message message in input)
            {
                var forwardedMessage = factory != null ? factory(message) : message.Clone();

                if (forwardedMessage == null)
                {
                    continue;
                }
                forwardedMessage.UserProperties[Constants.ReplEnqueuedTimePropertyName] =
                    (message.UserProperties.ContainsKey(Constants.ReplEnqueuedTimePropertyName)
                        ? message.UserProperties[Constants.ReplEnqueuedTimePropertyName] + ";"
                        : string.Empty) +
                    message.SystemProperties.EnqueuedTimeUtc.ToString("u");
                forwardedMessage.UserProperties[Constants.ReplOffsetPropertyName] =
                    (message.UserProperties.ContainsKey(Constants.ReplOffsetPropertyName)
                        ? message.UserProperties[Constants.ReplOffsetPropertyName] + ";"
                        : string.Empty) +
                    message.SystemProperties.EnqueuedSequenceNumber.ToString();
                forwardedMessage.UserProperties[Constants.ReplSequencePropertyName] =
                    (message.UserProperties.ContainsKey(Constants.ReplSequencePropertyName)
                        ? message.UserProperties[Constants.ReplSequencePropertyName] + ";"
                        : string.Empty) +
                    message.SystemProperties.EnqueuedSequenceNumber.ToString();
                await output.AddAsync(forwardedMessage);
            }
        }
    }
}