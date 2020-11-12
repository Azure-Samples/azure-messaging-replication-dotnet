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

    public class ServiceBusReplicationTasks
    {
        public static Task ForwardToEventHub(Message[] input, EventHubClient output,
            ILogger log)
        {
            var tasks = new List<Task>();
            var noPartitionBatch = new List<EventData>();
            var partitionBatches = new Dictionary<string, List<EventData>>();

            foreach (var message in input)
            {
                var eventData = new EventData(message.Body);
                var key = message.PartitionKey ?? message.SessionId;
                foreach (var property in message.UserProperties)
                {
                    eventData.Properties.Add(property);
                }

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

        public static async Task ForwardToServiceBus(Message[] input, IAsyncCollector<Message> output,
            ILogger log)
        {
            foreach (Message message in input)
            {
                await output.AddAsync(message.Clone());
            }
        }
    }
}