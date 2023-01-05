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
    using Azure.Messaging.EventHubs.Consumer;
    using Azure.Messaging.EventHubs.Producer;
    using Xunit;

    class EventHubCopyTest
    {
        readonly string targetNamespaceConnectionString;

        readonly string sourceNamespaceConnectionString;

        readonly string targetEventHub;

        readonly string sourceConsumerGroup;

        public EventHubCopyTest(
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
            Console.WriteLine("EventHubCopyTest");
            var targetproducer = new EventHubProducerClient(targetNamespaceConnectionString);
            var sourceconsumer = new EventHubConsumerClient(this.sourceConsumerGroup, this.sourceNamespaceConnectionString);

            var senderPartitions = await targetproducer.GetPartitionIdsAsync();
            var receiverPartitions = await sourceconsumer.GetPartitionIdsAsync();
            Assert.Equal(senderPartitions.Count(), receiverPartitions.Count());

            var start = DateTime.UtcNow;

            var sw = new Stopwatch();
            sw.Start();
            var tracker = new ConcurrentDictionary<string, long>();

            int messageCount = 5000;
            int sizeInBytes = 128;
            var data = new byte[sizeInBytes];
            Array.Fill<byte>(data, 0xff);

            int sent = 0;
            Console.WriteLine($"sending {messageCount} messages of {sizeInBytes} bytes ...");
            List<Task> sendTasks = new List<Task>();
            for (int j = 0; j < messageCount; j++)
            {
                string msgid = Guid.NewGuid().ToString();
                tracker[msgid] = sw.ElapsedTicks;

                var eventData = new EventData(data);
                eventData.MessageId = msgid;

                var options = new SendEventOptions
                {
                    PartitionKey = msgid
                };

                sendTasks.Add(targetproducer.SendAsync(new List<EventData>() { eventData }, options).ContinueWith(t =>
                {
                    int s = Interlocked.Increment(ref sent);
                    if (s % 5000 == 0)
                    {
                        Console.WriteLine($"sent {s} messages ...");
                    }
                }));
            }
            await Task.WhenAll(sendTasks);

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
                    using var cancellationTokenSource = new CancellationTokenSource();
                    var cancellationToken = cancellationTokenSource.Token;

                    Console.WriteLine($"Partition {partitionId} starting ");
                    try
                    {
                        await foreach (var partitionEvent in sourceconsumer.ReadEventsFromPartitionAsync(partitionId, startPosition, options, cancellationToken))
                        {
                            if (!tracker.IsEmpty)
                            {
                                var eventData = partitionEvent.Data;
                                if (eventData == null)
                                {
                                    Console.WriteLine($"No events were received during the {options.MaximumWaitTime} window.");
                                    break;
                                }
                                else
                                {
                                    string msgid = eventData.MessageId;
                                    if (tracker.TryRemove(msgid, out var swval))
                                    {
                                        durations.Add(sw.ElapsedTicks - swval);
                                    }
                                    int s = Interlocked.Increment(ref received);
                                    if (s % 5000 == 0)
                                    {
                                        Console.WriteLine($"Partition {partitionId} received {s} messages ...");
                                    }
                                }
                            }
                            else
                            {
                                cancellationTokenSource.Cancel();
                            }
                        }
                    }
                    catch (TaskCanceledException)
                    {
                        // Test run is ending
                    }
                    Console.WriteLine($"Partition {partitionId} received {received} messages. Done.");
                }));
            }

            await Task.WhenAll(receiveTasks);
            Console.WriteLine();
            Assert.True(tracker.IsEmpty, $"tracker is not empty: {tracker.Count}");

            Console.WriteLine($"Duration {((double)durations.Sum() / (double)durations.Count) / TimeSpan.TicksPerMillisecond}");

        }
    }
}