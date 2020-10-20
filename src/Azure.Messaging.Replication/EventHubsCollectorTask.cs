// Licensed under the MIT license.
// See LICENSE file in the project root for full license information.

namespace Azure.Messaging.Replication
{
    using System;
    using System.Threading;
    using System.Threading.Tasks;
    using Microsoft.Azure.EventHubs;
    using Microsoft.Azure.WebJobs;

    public class EventHubsCollectorTask : IAsyncCollector<EventData>
    {
        readonly IAsyncCollector<EventData> innerCollector;
        readonly Func<EventData, CancellationToken, Task<EventData>> action;

        public EventHubsCollectorTask(IAsyncCollector<EventData> innerCollector, Func<EventData, CancellationToken, Task<EventData>> action)
        {
            this.innerCollector = innerCollector;
            this.action = action;
        }
        public async Task AddAsync(EventData item, CancellationToken cancellationToken = new CancellationToken())
        {
            await innerCollector.AddAsync(await action(item, cancellationToken), cancellationToken);
        }

        public Task FlushAsync(CancellationToken cancellationToken = new CancellationToken())
        {
            return innerCollector.FlushAsync(cancellationToken);
        }
    }
}