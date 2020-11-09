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

            Console.WriteLine("sending");
            List<Task> sendTasks = new List<Task>();
            for (int j = 0; j < 100; j++)
            {
                string msgid = Guid.NewGuid().ToString();

                tracker.Add(new Tuple<string, long>(msgid, sw.ElapsedTicks));
                var eventData = new EventData(new byte[] { 1, 2, 3, 4, 5, 6, 7, 8, 9, 0 });
                eventData.Properties["message-id"] = msgid;
                await sendSideClient.SendAsync(eventData, pk);
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
                    while (tracker.Count > 0)
                    {
                        var eventData = await receiver.ReceiveAsync(100, TimeSpan.FromSeconds(10));
                        if (eventData != null)
                        {
                            Console.Write($"{partitionId}");
                            foreach (var ev in eventData)
                            {
                                if ( ev.SystemProperties.PartitionKey != pk)
                                    continue;

                                
                                string msgid = ev.Properties["message-id"] as string;
                                Assert.Equal(tracker[0].Item1, msgid); 
                                durations.Add(sw.ElapsedTicks - tracker[0].Item2);
                                tracker.RemoveAt(0);
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
            Assert.Empty(tracker);

            Console.WriteLine(((double)durations.Sum()/(double)durations.Count)/TimeSpan.TicksPerMillisecond);
            
        }
    }
}
