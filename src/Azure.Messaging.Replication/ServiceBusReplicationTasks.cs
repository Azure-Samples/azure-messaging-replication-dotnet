// Licensed under the MIT license.
// See LICENSE file in the project root for full license information.

namespace Azure.Messaging.Replication
{
    using System.Threading.Tasks;
    using Microsoft.Azure.EventHubs;
    using Microsoft.Azure.ServiceBus;
    using Microsoft.Azure.WebJobs;
    using Microsoft.Extensions.Logging;

    public class ServiceBusReplicationTasks
    {
        public static async Task ForwardToEventHub(Message[] input, IAsyncCollector<EventData> output,
            ILogger log)
        {
            foreach (var message in input)
            {
                var eventData = new EventData(message.Body)
                {
                    SystemProperties =
                    {
                        { "content-type", message.ContentType },
                        { "to", message.To },
                        { "correlation-id", message.CorrelationId },
                        { "subject", message.Label },
                        { "reply-to", message.ReplyTo },
                        { "reply-to-group-name", message.ReplyToSessionId },
                        { "message-id", message.MessageId },
                        { "x-opt-partition-key", message.PartitionKey ?? message.SessionId }
                    }
                };

                foreach (var property in message.UserProperties)
                {
                    eventData.Properties.Add(property);
                }

                await output.AddAsync(eventData);
            }
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