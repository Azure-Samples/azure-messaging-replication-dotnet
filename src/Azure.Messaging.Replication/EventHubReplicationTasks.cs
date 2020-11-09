// Licensed under the MIT license.
// See LICENSE file in the project root for full license information.

namespace Azure.Messaging.Replication
{
    using System.Threading.Tasks;
    using Microsoft.Azure.EventHubs;
    using Microsoft.Azure.ServiceBus;
    using Microsoft.Azure.WebJobs;
    using Microsoft.Extensions.Logging;
    using System.Collections.Generic;

    public class EventHubReplicationTasks
    {
        public static Task ForwardToEventHub(EventData[] input, EventHubClient output,
            ILogger log)
        {
            var tasks = new List<Task>();
            var noPartitionBatch = new List<EventData>();
            var partitionBatches = new Dictionary<string, List<EventData> >();
            foreach (EventData eventData in input)
            {
                if (eventData.SystemProperties.PartitionKey != null)
                {
                    if ( !partitionBatches.ContainsKey(eventData.SystemProperties.PartitionKey))
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
                foreach( var batch in partitionBatches)
                {
                    tasks.Add(output.SendAsync(batch.Value, batch.Key));
                }
            }
            return Task.WhenAll(tasks);
        }

        public static async Task ForwardToServiceBus(EventData[] input, IAsyncCollector<Message> output,
            ILogger log)
        {
            foreach (EventData eventData in input)
            {
                var item = new Message(eventData.Body.ToArray())
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
                    item.UserProperties.Add(property);
                }

                await output.AddAsync(item);
            }
        }
    }
}