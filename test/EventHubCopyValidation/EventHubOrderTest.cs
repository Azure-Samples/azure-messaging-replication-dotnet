using System;
using System.Collections.Generic;
using System.Text;

namespace EventHubCopyValidation
{
    using System.Collections.Concurrent;
    using System.Diagnostics;
    using System.Linq;
    using System.Threading;
    using System.Threading.Tasks;
    using Azure.Messaging.EventHubs;
    using Azure.Messaging.EventHubs.Producer;
    using Azure.Messaging.EventHubs.Primitives;
    using Xunit;
    using Azure.Messaging.EventHubs.Consumer;

    class EventHubOrderTest
    {
        readonly string targetNamespaceConnectionString;

        readonly string sourceNamespaceConnectionString;

        readonly string targetEventHub;

        readonly string sourceConsumerGroup;

        public EventHubOrderTest(
            string targetNamespaceConnectionString,
            string sourceNamespaceConnectionString,
            string targetEventHub,
            string sourceConsumerGroup)
        {
            this.targetNamespaceConnectionString = targetNamespaceConnectionString;
            this.sourceNamespaceConnectionString = sourceNamespaceConnectionString;
            this.targetEventHub = targetEventHub;
            this.sourceConsumerGroup = sourceConsumerGroup;
        }


        public async Task RunTest()
        {
            Console.WriteLine("EventHubOrderTest");
            string partitionKey = Guid.NewGuid().ToString();

            var targetproducer = new EventHubProducerClient(targetNamespaceConnectionString, targetEventHub);
            var sourceconsumer = new EventHubConsumerClient(this.sourceConsumerGroup, this.sourceNamespaceConnectionString);

            var senderPartitions = await targetproducer.GetPartitionIdsAsync();
            var receiverPartitions = await sourceconsumer.GetPartitionIdsAsync();
            Assert.Equal(senderPartitions.Count(), receiverPartitions.Count());

            var start = DateTime.UtcNow;

            var sw = new Stopwatch();
            sw.Start();
            var tracker = new List<Tuple<string, long>>();

            int messageCount = 5000;
            int sizeInBytes = 128;
            var data = new byte[sizeInBytes];
            Array.Fill<byte>(data, 0xff);

            int sent = 0;
            Console.WriteLine($"sending {messageCount} messages of {sizeInBytes} bytes ...");

            for (int j = 0; j < messageCount; j++)
            {
                string msgid = Guid.NewGuid().ToString();

                tracker.Add(new Tuple<string, long>(msgid, sw.ElapsedTicks));
                var eventData = new EventData(data);
                eventData.MessageId = msgid;

                // we need to send those all one-by-one to preserve order during sends

                var options = new SendEventOptions
                {
                    PartitionKey = partitionKey
                };

                await targetproducer.SendAsync(new List<EventData>() { eventData }, options).ContinueWith(t =>
                {
                    int s = Interlocked.Increment(ref sent);
                    if (s % 1000 == 0)
                    {
                        Console.WriteLine($"sent {s} messages ...");
                    }
                });
            }

            List<Task> receiveTasks = new List<Task>();

            ConcurrentBag<long> durations = new ConcurrentBag<long>();
            Console.Write("receiving: ");
            foreach (var partitionId in receiverPartitions)
            {
                receiveTasks.Add(Task.Run(async () =>
                {
                    int received = 0;
                    var startPosition = EventPosition.FromEnqueuedTime(start);
                    var options = new ReadEventOptions { MaximumWaitTime = TimeSpan.FromSeconds(30) };

                    Console.WriteLine($"Partition {partitionId} starting ");
                    while (tracker.Count > 0)
                    {
                        await foreach (var partitionEvent in sourceconsumer.ReadEventsFromPartitionAsync(partitionKey, startPosition, options))
                        {
                            var eventData = partitionEvent.Data;
                            string msgid = eventData.MessageId;
                            Assert.Equal(tracker[0].Item1, msgid);
                            durations.Add(sw.ElapsedTicks - tracker[0].Item2);
                            tracker.RemoveAt(0);

                            int s = Interlocked.Increment(ref received);
                            if (s % 5000 == 0)
                            {
                                Console.WriteLine($"Partition {partitionId} received {s} messages ...");
                            }
                        }
                    }
                    Console.WriteLine($"Partition {partitionId} received {received} messages. Done.");
                }));
            }

            await Task.WhenAll(receiveTasks);
            Console.WriteLine();
            Assert.Empty(tracker);

            Console.WriteLine($"Duration {((double)durations.Sum() / (double)durations.Count) / TimeSpan.TicksPerMillisecond}");

        }
    }
}
