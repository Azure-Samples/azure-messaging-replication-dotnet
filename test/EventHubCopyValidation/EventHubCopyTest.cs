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

    class EventHubCopyTest
    {
        readonly string targetNamespaceConnectionString;

        readonly string sourceNamespaceConnectionString;

        readonly string targetEventHub;

        readonly string sourceEventHub;

        readonly string sourceConsumerGroup;

        public EventHubCopyTest(
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
            Console.WriteLine("EventHubCopyTest");
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
            var tracker = new ConcurrentDictionary<string, long>();

            int messageCount = 50000;
            int sizeInBytes = 128;
            var data = new byte[sizeInBytes];
            Array.Fill<byte>(data,0xff);
                
            int sent = 0;
            Console.WriteLine($"sending {messageCount} messages of {sizeInBytes} bytes ...");
            List<Task> sendTasks = new List<Task>();
            for (int j = 0; j < messageCount; j++)
            {
                string msgid = Guid.NewGuid().ToString();
                tracker[msgid] = sw.ElapsedTicks;

                var eventData = new EventData(data);
                eventData.Properties["message-id"] = msgid;
                sendTasks.Add(sendSideClient.SendAsync(eventData, msgid).ContinueWith(t=>{
                    int s = Interlocked.Increment(ref sent); 
                    if ( s % 5000 == 0) {
                        Console.WriteLine($"sent {s} messages ...");
                    }
                }));
            }
            await Task.WhenAll(sendTasks);
            
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
                    while (!tracker.IsEmpty)
                    {
                        var eventData = await receiver.ReceiveAsync(100, TimeSpan.FromSeconds(30));
                        if (eventData != null)
                        {
                            foreach (var ev in eventData)
                            {
                                string msgid = ev.Properties["message-id"] as string;
                                if(tracker.TryRemove(msgid, out var swval)) 
                                {
                                    durations.Add(sw.ElapsedTicks - swval);
                                }
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
            Assert.True(tracker.IsEmpty, $"tracker is not empty: {tracker.Count}");

            Console.WriteLine($"Duration {((double)durations.Sum()/(double)durations.Count)/TimeSpan.TicksPerMillisecond}");
            
        }
    }
}
