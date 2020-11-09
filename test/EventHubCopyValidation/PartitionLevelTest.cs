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

    class PartitionLevelTest
    {
        readonly string targetNamespaceConnectionString;

        readonly string sourceNamespaceConnectionString;

        readonly string targetEventHub;

        readonly string sourceEventHub;

        readonly string sourceConsumerGroup;

        public PartitionLevelTest(
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

            Console.WriteLine("sending");
            List<Task> sendTasks = new List<Task>();
            for (int j = 0; j < 1000; j++)
            {
                string msgid = Guid.NewGuid().ToString();
                tracker[msgid] = sw.ElapsedTicks;
                var eventData = new EventData(new byte[] { 1, 2, 3, 4, 5, 6, 7, 8, 9, 0 });
                eventData.Properties["message-id"] = msgid;
                sendTasks.Add(sendSideClient.SendAsync(eventData, msgid));
            }

            
            List<Task> receiveTasks = new List<Task>();

            ConcurrentBag<long> durations = new ConcurrentBag<long>();
            Console.Write("receiving: ");
            foreach (var partitionId in receiverInfo.PartitionIds)
            {
                receiveTasks.Add(Task.Run(async () =>
                {

                    var receiver = receiveSideClient.CreateReceiver(this.sourceConsumerGroup, partitionId,
                        EventPosition.FromEnqueuedTime(start));
                    Console.Write($"{partitionId}, ");
                    while (!tracker.IsEmpty)
                    {
                        var eventData = await receiver.ReceiveAsync(100, TimeSpan.FromSeconds(10));
                        if (eventData != null)
                        {
                            foreach (var ev in eventData)
                            {
                                string msgid = ev.Properties["message-id"] as string;
                                if(tracker.TryRemove(msgid, out var swval)) 
                                {
                                    durations.Add(sw.ElapsedTicks - swval);
                                }
                            }
                        }
                        else
                        {
                            break;
                        }
                    }
                }));
            }
            await Task.WhenAll(sendTasks);
            await Task.WhenAll(receiveTasks);
            Console.WriteLine();
            Assert.True(tracker.IsEmpty);

            Console.WriteLine(((double)durations.Sum()/(double)durations.Count)/TimeSpan.TicksPerMillisecond);
            
        }
    }
}
