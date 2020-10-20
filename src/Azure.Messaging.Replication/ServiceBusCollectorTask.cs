// Licensed under the MIT license.
// See LICENSE file in the project root for full license information.

namespace Azure.Messaging.Replication
{
    using System;
    using System.Threading;
    using System.Threading.Tasks;
    using Microsoft.Azure.ServiceBus;
    using Microsoft.Azure.WebJobs;

    public class ServiceBusCollectorTask : IAsyncCollector<Message>
    {
        readonly Func<Message, CancellationToken, Task<Message>> action;

        readonly IAsyncCollector<Message> innerCollector;

        public ServiceBusCollectorTask(IAsyncCollector<Message> innerCollector,
            Func<Message, CancellationToken, Task<Message>> action)
        {
            this.innerCollector = innerCollector;
            this.action = action;
        }

        public async Task AddAsync(Message message, CancellationToken cancellationToken = new CancellationToken())
        {
            await innerCollector.AddAsync(await action(message, cancellationToken), cancellationToken);
        }

        public Task FlushAsync(CancellationToken cancellationToken = new CancellationToken())
        {
            return innerCollector.FlushAsync(cancellationToken);
        }
    }
}