## Service Bus Copy (Configuration)

This project illustrates how to build and deploy a simple copy replication
function that moves data between a Service Bus queue or a topic subscription and
an queue or topic inside a different namespace.

Within a single namespace, messages can be forwarded using the built-in
[autoforwarding](https://docs.microsoft.com/azure/service-bus-messaging/service-bus-auto-forwarding) feature. 

It is assumed that you are familiar with Service Bus and know how to create entities
either through [Azure Portal](https://docs.microsoft.com/azure/service-bus-messaging/service-bus-quickstart-portal),
[Azure CLI](https://docs.microsoft.com/azure/service-bus-messaging/service-bus-quickstart-cli),
[Azure PowerShell](https://docs.microsoft.com/azure/service-bus-messaging/service-bus-quickstart-powershell), or
[ARM Templates](https://docs.microsoft.com/azure/service-bus-messaging/service-bus-resource-manager-namespace-queue).

It is furthermore assumed that you have read the Service Bus Federation guidance (
[Overview](https://docs.microsoft.com/azure/service-bus-messaging/service-bus-federation-overview),
[Functions](https://docs.microsoft.com/azure/service-bus-messaging/service-bus-federation-replicator-functions),
[Patterns](https://docs.microsoft.com/azure/service-bus-messaging/service-bus-federation-patterns)), and
have a scenario for your replication project in mind.

The [replication](https://docs.microsoft.com/azure/service-bus-messaging/service-bus-federation-patterns#replication)
and [merge](https://docs.microsoft.com/azure/service-bus-messaging/service-bus-federation-patterns#merge)
patterns can be readily implemented with this project.

### Replication topology

For configuring and running this replication function, you need a source Service
Bus queue or topic subscription in one namespace and a target queue or topic in
another namespace. The namespaces may be located in different Azure regions.

We will refer to the Service Bus entity from which messages are to be replicated as the
*source* and the Service Bus entity to which messages are replicated the *target*.

In Service Bus, replication will not copy messages, but move messages from
source and target, with the moved messages being deleted from the source. 

To create mirrored queues where a second queue contains copies of the messages
sent into the primary queue, the primary queue really needs to be a topic where
a 'main' subscription acts like the queue endpoint for the application, and a
'replication' subscription gets copies of messages that are being replicated.
Mirroring scenarios are covered by the
[ServiceBusAllActive](../ServiceBusAllActive) and
[ServiceBusActivePassive](../ServiceBusActivePassive) examples.

To route messages across different scopes, where the scope might be a geographic
region or application ownership, you may create a transfer queue into which
messages are being sent from an application, and the replication task transfers
messages from that queue to a target queue in a namespace in a different region
and/or belonging to a different application. The entity acting as the transfer
queue might also be a topic subscription. 

The following diagram shows an exemplary topology with a suggested convention
for naming the various elements. Here, the replication function name reflects
the name of the Service Bus queue it copies from source to target.


```markdown
      Source Queue               Replication App             Target Event Hub
+-------------------------+ +-------------------------+  +-----------------------+              
| Namespace (West Europe) | |      Function App       |  | Namespace (East US 2) |
|  "example-sb-weu"       | | "repl-example-weu-eus2" |  |  "example-eh-eus2"    |
|                         | |                         |  |                       |
| +-----------------+     | |  +-----------------+    |  |   +---------------+   |
  |                 |          |   Replication   |           |               |
  |   Service Bus   |          |    Function     |           |  Event Hub    | 
  |      Queue      |---->-----|                 |----->-----|               |
  | "jobs-transfer" |          | "jobs_transfer" |           |    "jobs"     |
  |                 |          |                 |           |               |
  +-----------------+          +-----------------+           +---------------+
```


### Configuring the Replication App

Leaning on the naming conventions of the exemplary topology, the project
implements one replication task named "jobs_transfer" that performs the copy.

The task is defined in the a 'function.json' configuration file that resides in
the 'jobs_transfer' folder, corresponding to the name of the function.

For adding further tasks to the replication application, create a new folder for
each task and place a 'function.json' file into it. The options for the
configuration files are [explained in the product documentation](https://docs.microsoft.com/azure/service-bus-messaging/service-bus-federation-service-bus).

```json
{
    "configurationSource": "config",
    "bindings" : [
        {
            "direction": "in",
            "type": "serviceBusTrigger",
            "connection": "jobs-transfer-source-connection",
            "queueName": "jobs-transfer",
            "name": "input" 
        },
        {
            "direction": "out",
            "type": "eventHub",
            "connection": "jobs-target-connection",
            "eventHubName": "jobs",
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
    "entryPoint": "Azure.Messaging.Replication.ServiceBusReplicationTasks.ForwardToServiceBus"
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