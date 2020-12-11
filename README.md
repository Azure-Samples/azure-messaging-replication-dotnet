## Azure Messaging Replication Tasks with .NET Core

This project contains a set of samples that demonstrate how to create Azure
Messaging replication tasks using the Azure Functions runtime with .NET Core.

For using these tasks with Event Hubs, first read the Event Hubs Federation guidance (
[Overview](https://docs.microsoft.com/azure/event-hubs/event-hubs-federation-overview),
[Functions](https://docs.microsoft.com/azure/event-hubs/event-hubs-federation-replicator-functions),
[Patterns](https://docs.microsoft.com/azure/event-hubs/event-hubs-federation-patterns)).

For Service Bus, read the Service bus Federation Guidance (
[Overview](https://docs.microsoft.com/azure/service-bus-messaging/service-bus-federation-overview),
[Functions](https://docs.microsoft.com/azure/service-bus-messaging/service-bus-federation-replicator-functions),
[Patterns](https://docs.microsoft.com/azure/service-bus-messaging/service-bus-federation-patterns))

### Introduction

Many sophisticated solutions require the same event streams or the same content
of queues to be made available for consumption in multiple locations and/or for
event streams or queue contents to be collected in multiple locations and then
consolidated into a specific locations for consumption.

Replicating event streams and contents of queues requires a scalable and
reliable execution environment for the replication tasks that you want to
configure and run. On Azure, the runtime environment that is best suited for
these tasks is [Azure Functions](https://docs.microsoft.com/azure/azure-functions/functions-overview.md).

Azure Functions allows replication tasks to directly integrate
with Azure virtual networks and [service endpoints](https://docs.microsoft.com/azure/virtual-network/virtual-network-service-endpoints-overview) for
all Azure messaging services, and it is readily integrated with [Azure Monitor](https://docs.microsoft.com/azure/azure-monitor/overview).

Azure Functions has prebuilt, scalable triggers and output bindings for [Azure Event Hubs](https://docs.microsoft.com/azure/azure-functions/functions-bindings-event-hubs), [Azure IoT
Hub](https://docs.microsoft.com/azure/azure-functions/functions-bindings-event-iot), [Azure Service Bus](https://docs.microsoft.com/azure/azure-functions/functions-bindings-service-bus.md), [Azure Event
Grid](https://docs.microsoft.com/azure/azure-functions/functions-bindings-event-grid.md), and [Azure Queue Storage](https://docs.microsoft.com/azure/azure-functions/functions-bindings-storage-queue.md), as well as
custom extensions for [RabbitMQ](https://github.com/azure/azure-functions-rabbitmq-extension), and [Apache Kafka](https://github.com/azure/azure-functions-kafka-extension). 

Most triggers will dynamically adapt to the throughput needs by scaling the
number of concurrently executing instance up and down based on documented
metrics.

With the Azure Functions consumption plan, the prebuilt triggers can even scale
down to zero while no messages are available for replication, which means you
incur no costs for keeping the configuration ready to scale back up; the key
downside of using the consumption plan is that the latency for replication tasks
"waking up" from this state is significantly higher than with the hosting plans
where the infrastructure is kept running.  

> Azure Functions will soon add native support for Messaging Replication Tasks
> such that these tasks will no longer require any customer-deployed code to run
> and the code will automatically be maintained by the Functions runtime. The
> [config](functions/config) experience in this repository is similar to the
> future model, but still requires code to be built and deployed. Because this
> new model is under active development, the "standard" replication tasks
> provided in this repository are not provided as NuGet packages, but as code
> samples for you to build custom tasks on.

### How to use this repository

You can use this repository either to configure and deploy replication tasks
without having to write any code, at all, or you can use it as a foundation for
your own replication tasks.

In either case, you will need the following tools:
* [Azure Functions Core Tools](https://docs.microsoft.com/azure/azure-functions/functions-run-local)
* [Azure Powershell](https://docs.microsoft.com/en-us/powershell/azure/install-az-ps)
* [.NET Core SDK 3.1](https://dotnet.microsoft.com/download/dotnet-core/3.1)
* [Git client](https://git-scm.com/downloads)

Please download the repository contents or clone this repository from a command line window with:

```powershell
git clone https://github.com/Azure-Samples/azure-messaging-replication-dotnet
```

The instructions in the [functions/config](functions/config) folder and
subfolders explain how to configure replication tasks without having to write
any code yourself. The provided scripts use the aforementioned tools for
configuring the replication tasks.

### Contents

The following folders are part of this project:

* **[functions/code](functions/code)** - .NET Core Azure Functions projects as starting points for your custom replication tasks that require modification of events or messages as they are being moved:
   * **[EventHubCopy](functions/code/EventHubCopy)** - Function for copying data between two Event Hubs
   * **[EventHubMerge](functions/code/EventHubMerge)** - Function for continuously merging two Event Hubs
   * **[EventHubProjectionToCosmosDB](functions/code/EventHubProjectionToCosmosDB)** - Function for projecting events into a key/value store ("compaction")
   * **[ServiceBusCopy](functions/code/ServiceBusCopy)** - Function for copying data between two Service Bus Queues
   * **[ServiceActivePassive](functions/code/ServiceBusActivePassive)** - Function backing up messages in a standby topic or queue
   * **[ServiceBusAllActive](functions/code/ServiceBusAllActive)** - Function for maintaining mirrored topics acting as queues
* **[functions/config](functions/config)** - Configuration-only projects, which use the standard replication task library:
   * **[EventHubCopy](functions/config/EventHubCopy)** - Function for copying data between two Event Hubs
   * **[EventHubCopyToServiceBus](functions/config/EventHubCopyToServiceBus)** - Function for copying data between two Event Hubs
   * **[ServiceBusCopy](functions/config/ServiceBusCopy)** - Function for copying data between two Service Bus Queues
   * **[ServiceBusCopyToEventHub](functions/config/ServiceBusCopyToEventHub)** - Function for copying data between a Service Bus Queue to an Event Hub
* **[src](src)** - .NET Core libraries implementing replication tasks.
  * **[src/Azure.Messaging.Replication](src/Azure.Messaging.Replication)** - Standard replication tasks
* **[templates](templates)** - Azure Resource Manager templates to create properly configured Function app environments 
* **[test](test)** - Test projects and validation scripts


## Contributing

This project welcomes contributions and suggestions.  Most contributions require you to agree to a
Contributor License Agreement (CLA) declaring that you have the right to, and actually do, grant us
the rights to use your contribution. For details, visit https://cla.opensource.microsoft.com.

When you submit a pull request, a CLA bot will automatically determine whether you need to provide
a CLA and decorate the PR appropriately (e.g., status check, comment). Simply follow the instructions
provided by the bot. You will only need to do this once across all repos using our CLA.

This project has adopted the [Microsoft Open Source Code of Conduct](https://opensource.microsoft.com/codeofconduct/).
For more information see the [Code of Conduct FAQ](https://opensource.microsoft.com/codeofconduct/faq/) or
contact [opencode@microsoft.com](mailto:opencode@microsoft.com) with any additional questions or comments.
