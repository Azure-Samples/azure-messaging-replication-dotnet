## Event Hub to Service Bus Copy (Configuration)

This project illustrates how to configure and deploy a copy replication function
that moves data between from an Azure Event Hubs into a Servcie Bus entity
without you having to write or modify any code.

It is assumed that you are familiar with Event Hubs and know how to create them
either through [Azure Portal](https://docs.microsoft.com/azure/event-hubs/event-hubs-create),
[Azure CLI](https://docs.microsoft.com/azure/event-hubs/event-hubs-quickstart-cli),
[Azure PowerShell](https://docs.microsoft.com/azure/event-hubs/event-hubs-quickstart-powershell), or
[ARM Templates](https://docs.microsoft.com/azure/event-hubs/event-hubs-resource-manager-namespace-event-hub).

It is furthermore assumed that you have read the Event Hubs Federation guidance (
[Overview](https://docs.microsoft.com/azure/event-hubs/event-hubs-federation-overview),
[Functions](https://docs.microsoft.com/azure/event-hubs/event-hubs-federation-replicator-functions),
[Patterns](https://docs.microsoft.com/azure/event-hubs/event-hubs-federation-patterns)), and
have a scenario for your replication project in mind.

The [replication](https://docs.microsoft.com/azure/event-hubs/event-hubs-federation-patterns#replication)
and [merge](https://docs.microsoft.com/azure/event-hubs/event-hubs-federation-patterns#merge)
patterns can be readily implemented with this project.

### Prerequisites

To configure and deploy this project, you need the following components installed:

* [.NET Core SDK 3.1](https://dotnet.microsoft.com/download/dotnet-core/3.1)
* [Azure Functions Core Tools 3](https://docs.microsoft.com/azure/azure-functions/functions-run-local)

### Replication topology 

For configuring and running this replication function, you need two Event Hubs,
either inside the same namespace or in different namespaces that may be located
in different Azure regions.

We will refer to the Event Hubs from which events are to be replicated as the
*source* and the Event Hub into which messages are replicated the *target*.

On the *source* Event Hub, you will need to create a dedicated [consumer
group](https://docs.microsoft.com/azure/event-hubs/event-hubs-features#consumer-groups)
for the replication function that will allow the functions to manage scaling and
keep track of its progress on the source event hub.

The following diagram shows an exemplary topology with a suggested convention
for naming the various elements. Here, the replication function name reflects
the name of the Event Hub it mirrors from source to target, and the consumer
group name on the *source* reflects the replication app and function name.

If the Event Hubs have different names, you might reflect that in the function
name as `source_target`. The naming is ultimately up to you and will follow
whatever conventions you define for your scenario.

```markdown
              Source Event Hub                              Replication App              Target Service Bus
+-----------------------------------------------------+ +-------------------------+  +-----------------------+              
|             Namespace (West Europe)                 | |      Function App       |  | Namespace (East US 2) |
|               "example-eh-weu"                      | | "repl-example-weu-eus2" |  |  "example-sb-eus2"    |
|                                                     | |                         |  |                       |
| +-------------+                                     | |      +-------------+    |  |   +---------------+   |
  |             +-----------------------------------+          | Replication |           |               |
  |  Event Hub  |     Consumer Group                |          |  Function   |           |  Service Bus  | 
  |             | "repl-example-weu-eus2.telemetry" |---->-----|             |----->-----|               |
  | "telemetry" |                                   |          | "telemetry" |           |  "telemetry"  |
  |             +-----------------------------------+          |             |           |               |
  +-------------+                                              +-------------+           +---------------+
```


### Building, Configuring, and Deploying the Replication App

Leaning on the naming conventions of the exemplary topology, the project
implements one replication task named "telemetry" that performs the copy.

The task is defined in the a 'function.json' configuration file that resides in
the 'telemetry' folder, corresponding to the name of the function.

For adding further tasks to the replication application, create a new folder for
each task and place a 'function.json' file into it. The options for the
configuration files are [explained in the product documentation](https://docs.microsoft.com/azure/event-hubs/event-hubs-federation-event-hubs).

```json
{
    "configurationSource": "config",
    "bindings" : [
        {
            "direction": "in",
            "type": "eventHubTrigger",
            "connection": "telemetry-source-connection",
            "eventHubName": "telemetry",
            "consumerGroup": "%telemetry-source-consumergroup%",
            "name": "input" 
        },
        {
            "direction": "out",
            "type": "serviceBus",
            "connection": "telemetry-target-connection",
            "queueName": "telemetry",
            "name": "output"
        }
    ],
    "retry": {
        "strategy": "exponentialBackoff",
        "maxRetryCount": -1,
        "minimumInterval": "00:00:05",
        "maximumInterval": "00:05:00"
    },
    "disabled": false,
    "scriptFile": "../bin/Azure.Messaging.Replication.dll",
    "entryPoint": "Azure.Messaging.Replication.EventHubReplicationTasks.ForwardToServiceBus"
}
```

The `connection` values refer to the name of configuration entries in the
application settings of the Functions application. The [setup](#setup) step below
explains how to set those.

### Setup, Configuration, Deployment

Refer to the [ServiceBusCopy](../ServiceBusCopy/README.md) and
[EventHubCopy](../EventHubCopy/README.md) documents for how to set up the Event Hubs side and the Service Bus side of the task.

### Monitoring

To learn how you can monitor your replication app, please refer to the [monitoring section](https://docs.microsoft.com/azure/azure-functions/configure-monitoring?tabs=v2) of the Azure Functions documentation.

A particularly useful visual tool for monitoring replication tasks is the Application Insights [Application Map](https://docs.microsoft.com/azure/azure-monitor/app/app-map), which is automatically generated from the captured monitoring information and allows exploring the reliability and performance of the replication task sosurce and target transfers.

For immediate diagnostic insights, you can work with the [Live Metrics](https://docs.microsoft.com/azure/azure-monitor/app/live-stream) portal tool, which provides low latency visualization of log details.