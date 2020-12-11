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
    using Microsoft.Azure.EventHubs;
    using Xunit;

    class EventHubOrderTest
    {
        readonly string targetNamespaceConnectionString;

        readonly string sourceNamespaceConnectionString;

        readonly string targetEventHub;

        readonly string sourceEventHub;

        readonly string sourceConsumerGroup;

        public EventHubOrderTest(
            string targetNamespaceConnectionString,
            string sourceNamespaceConnectionString,
            string targetEventHub, 
            string sourceEventHub, 
            string sourceConsumerGroup)
        {
            this.targetNamespaceConnectionString = targetNamespaceConnectionString;
            this.sourceNamespaceConnectionString = sourceNamespaceConnectionString;
            this.targetEventHub = targetEventHub;
            this.sourceEventHub = sourceEventHub;
            this.sourceConsumerGroup = sourceConsumerGroup;
        }


        public async Task RunTest()
        {
            Console.WriteLine("EventHubOrderTest");
            string pk = Guid.NewGuid().ToString();
            var senderCxn = new EventHubsConnectionStringBuilder(targetNamespaceConnectionString)
            {
                EntityPath = targetEventHub
            };
            var sendSideClient = EventHubClient.CreateFromConnectionString(senderCxn.ToString());
            var receiverCxn = new EventHubsConnectionStringBuilder(sourceNamespaceConnectionString)
            {
                EntityPath = sourceEventHub
            };
            var receiveSideClient = EventHubClient.CreateFromConnectionString(receiverCxn.ToString());

            var senderInfo = await sendSideClient.GetRuntimeInformationAsync();
            var receiverInfo = await receiveSideClient.GetRuntimeInformationAsync();
            Assert.Equal(senderInfo.PartitionCount, receiverInfo.PartitionCount);

            var start = DateTime.UtcNow;

            var sw = new Stopwatch();
            sw.Start();
            var tracker = new List<Tuple<string,long>>();

            int messageCount = 5000;
            int sizeInBytes = 128;
            var data = new byte[sizeInBytes];
            Array.Fill<byte>(data,0xff);
                
            int sent = 0;
            Console.WriteLine($"sending {messageCount} messages of {sizeInBytes} bytes ...");
            
            for (int j = 0; j < messageCount; j++)
            {
                string msgid = Guid.NewGuid().ToString();

                tracker.Add(new Tuple<string, long>(msgid, sw.ElapsedTicks));
                var eventData = new EventData(data);
                eventData.Properties["message-id"] = msgid;
                // we need to send those all one-by-one to preserve order during sends
                await sendSideClient.SendAsync(eventData, pk).ContinueWith(t=>{
                    int s = Interlocked.Increment(ref sent); 
                    if ( s % 1000 == 0) {
                        Console.WriteLine($"sent {s} messages ...");
                    }
                });
            }

            
            
            List<Task> receiveTasks = new List<Task>();

            ConcurrentBag<long> durations = new ConcurrentBag<long>();
            Console.Write("receiving: ");
            foreach (var partitionId in receiverInfo.PartitionIds)
            {
                receiveTasks.Add(Task.Run(async () =>
                {
                    int received = 0;
                    var receiver = receiveSideClient.CreateReceiver(this.sourceConsumerGroup, partitionId,
                        EventPosition.FromEnqueuedTime(start));
                    Console.WriteLine($"Partition {partitionId} starting ");
                    while (tracker.Count > 0)
                    {
                        
                        var eventData = await receiver.ReceiveAsync(100, TimeSpan.FromSeconds(2));
                        if (eventData != null)
                        {
                            foreach (var ev in eventData)
                            {
                                if ( ev.SystemProperties.PartitionKey != pk)
                                    continue;

                                string msgid = ev.Properties["message-id"] as string;
                                Assert.Equal(tracker[0].Item1, msgid); 
                                durations.Add(sw.ElapsedTicks - tracker[0].Item2);
                                tracker.RemoveAt(0);

                                int s = Interlocked.Increment(ref received); 
                                if ( s % 5000 == 0) {
                                    Console.WriteLine($"Partition {partitionId} received {s} messages ...");
                                }
                            }
                        }
                        else
                        {
                            Console.WriteLine($"Partition {partitionId} empty.");
                            break;
                        }
                    }
                    Console.WriteLine($"Partition {partitionId} received {received} messages. Done.");
                }));
            }
            
            await Task.WhenAll(receiveTasks);
            Console.WriteLine();
            Assert.Empty(tracker);

            Console.WriteLine($"Duration {((double)durations.Sum()/(double)durations.Count)/TimeSpan.TicksPerMillisecond}");
            
        }
    }
}
