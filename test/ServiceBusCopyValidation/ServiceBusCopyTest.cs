using System;
using System.Collections.Generic;
using System.Text;

namespace ServiceBusCopyValidation
{
    using System.Collections.Concurrent;
    using System.Diagnostics;
    using System.Linq;
    using System.Threading;
    using System.Threading.Tasks;
    using Microsoft.Azure.ServiceBus;
    using Xunit;

    class ServiceBusCopyTest
    {
        readonly string targetNamespaceConnectionString;

        readonly string sourceNamespaceConnectionString;

        readonly string targetQueue;

        readonly string sourceQueue;

        public ServiceBusCopyTest(
            string targetNamespaceConnectionString,
            string sourceNamespaceConnectionString,
            string targetQueue, 
            string sourceQueue)
        {
            this.targetNamespaceConnectionString = targetNamespaceConnectionString;
            this.sourceNamespaceConnectionString = sourceNamespaceConnectionString;
            this.targetQueue = targetQueue;
            this.sourceQueue = sourceQueue;
        }


        public async Task RunTest()
        {
            var senderCxn = new ServiceBusConnectionStringBuilder(targetNamespaceConnectionString)
            {
                EntityPath = targetQueue
            };
            var sendSideClient =  new QueueClient(senderCxn);
            var receiverCxn = new ServiceBusConnectionStringBuilder(sourceNamespaceConnectionString)
            {
                EntityPath = sourceQueue
            };
            var receiveSideClient = new Microsoft.Azure.ServiceBus.Core.MessageReceiver(receiverCxn);

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
                var message = new Message(new byte[] { 1, 2, 3, 4, 5, 6, 7, 8, 9, 0 });
                message.MessageId = msgid;
                sendTasks.Add(sendSideClient.SendAsync(message));
            }

             await Task.WhenAll(sendTasks);
        
            ConcurrentBag<long> durations = new ConcurrentBag<long>();
            Console.Write("receiving: ");
            var receiveTask = Task.Run(async () =>
                {

                    while (!tracker.IsEmpty)
                    {
                        var message = await receiveSideClient.ReceiveAsync(100, TimeSpan.FromSeconds(10));
                        if (message != null)
                        {
                            foreach (var msg in message)
                            {
                                string msgid = msg.MessageId;
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
                });
           
            await receiveTask;
            Console.WriteLine();
            Assert.True(tracker.IsEmpty, $"tracker is not empty: {tracker.Count}");

            Console.WriteLine(((double)durations.Sum()/(double)durations.Count)/TimeSpan.TicksPerMillisecond);
            
        }
    }
}
