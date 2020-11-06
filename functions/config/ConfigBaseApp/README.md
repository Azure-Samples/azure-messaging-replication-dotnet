## Baseline for a Configuration-Based Replication Application

This project is a starting point for a configuration-based replication application. 

### Creating replication tasks 

To create a new replication task, first create a new folder underneath the project folder. The name of the new folder is the name of the function, for instance `EventHubAToEventHubB`. The name has no functional correlation with the messaging entities being used and serves only for you to identify them. You can create dozens of functions in the same project.

Next, create a `function.json` file in the folder. The file configures the function. Start with the following content:

``` JSON
{
    "configurationSource": "config",
    "bindings" : [
        {
            "direction": "in",
            "name": "input" 
        },
        {
            "direction": "out",
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
    "scriptFile": "../dotnet/bin/Azure.Messaging.Replication.dll",
    "entryPoint": "Azure.Messaging.Replication.*"
}
```

In that file, you need to complete three configuration steps that depend on which entities you want to connect:

1. [Configure the input direction](#configure-the-input-direction)
2. [Configure the output direction](#configure-the-output-direction)
3. [Configure the entry point](#configure-the-entry-point)

#### Configure the input direction

##### Event Hub input

If you want to receive events from an Event Hub, add configuration information to the top section within "bindings" that sets

* **type** - the "eventHubTrigger" type.
* **connection** - the name of the app configuration value for the Event Hub connection string. This value must be `{FunctionName}-source-connection` if you want to use the provided scripts.
* **eventHubName** - the name of the Event Hub within the namespace identified by the connection string.

```JSON
    ...
    "bindings" : [
        {
            "direction": "in",
            "type": "eventHubTrigger",
            "connection": "EventHubAToEventHubB-source-connection",
            "eventHubName": "eventHubA",
            "name": "input" 
        }
    ...
```

##### Service Bus Queue input

If you want to receive events from a Service Bus queue, add configuration information to the top section within "bindings" that sets

* **type** - the "serviceBusTrigger" type.
* **connection** - the name of the app configuration value for the Service Bus connection string. This value must be `{FunctionName}-source-connection` if you want to use the provided scripts.
* **queueName** - the name of the Service Bus Queue within the namespace identified by the connection string.

```JSON
    ...
    "bindings" : [
        {
            "direction": "in",
            "type": "serviceBusTrigger",
            "connection": "QueueAToQueueB-source-connection",
            "queueName": "queue-a",
            "name": "input" 
        }
    ...
```

##### Service Bus Topic input

If you want to receive events from a Service Bus topic, add configuration information to the top section within "bindings" that sets

* **type** - the "serviceBusTrigger" type.
* **connection** - the name of the app configuration value for the Service Bus connection string. This value must be `{FunctionName}-source-connection` if you want to use the provided scripts.
* **topicName** - the name of the Service Bus Topic within the namespace identified by the connection string.
* **subscriptionName** - the name of the Service Bus Subscription on the given topic within the namespace identified by the connection string.

```JSON
    ...
    "bindings" : [
        {
            "direction": "in",
            "type": "serviceBusTrigger",
            "connection": "TopicXSubYToQueueB-source-connection",
            "topicName": "topic-x",
            "subscriptionName" : "sub-y",
            "name": "input" 
        }
    ...
```

#### Configure the output direction

##### Event Hub output

If you want to forward events to an Event Hub, add configuration information to the bottom section within "bindings" that sets

* **type** - the "eventHub" type.
* **connection** - the name of the app configuration value for the Event Hub connection string. This value must be `{FunctionName}-target-connection` if you want to use the provided scripts.
* **eventHubName** - the name of the Event Hub within the namespace identified by the connection string.

```JSON
    ...
    "bindings" : [
        {
            ...
        },
        {
            "direction": "out",
            "type": "eventHub",
            "connection": "EventHubAToEventHubB-target-connection",
            "eventHubName": "eventHubB",
            "name": "output" 
        }
    ...
```

##### Service Bus Queue output

If you want to forward events to a Service Bus Queue, add configuration information to the bottom section within "bindings" that sets

* **type** - the "serviceBus" type.
* **connection** - the name of the app configuration value for the Service Bus connection string. This value must be `{FunctionName}-target-connection` if you want to use the provided scripts.
* **queueName** - the name of the Service Bus queue within the namespace identified by the connection string.

```JSON
    ...
    "bindings" : [
        {
            ...
        },
        {
            "direction": "out",
            "type": "serviceBus",
            "connection": "QueueAToQueueB-target-connection",
            "eventHubName": "queue-b",
            "name": "output" 
        }
    ...
```

##### Service Bus Topic output

If you want to forward events to a Service Bus Topic, add configuration information to the bottom section within "bindings" that sets

* **type** - the "serviceBus" type.
* **connection** - the name of the app configuration value for the Service Bus connection string. This value must be `{FunctionName}-target-connection` if you want to use the provided scripts.
* **topicName** - the name of the Service Bus topic within the namespace identified by the connection string.

```JSON
    ...
    "bindings" : [
        {
            ...
        },
        {
            "direction": "out",
            "type": "serviceBus",
            "connection": "QueueAToQueueB-target-connection",
            "eventHubName": "queue-b",
            "name": "output" 
        }
    ...
```

#### Configure the entry point

The entry point configuration picks one of the standard replication tasks. If you are modifying the `Azure.Messaging.Replication` project, you can also add tasks and refer to them here. For instance:

```JSON
    ...
    "scriptFile": "../dotnet/bin/Azure.Messaging.Replication.dll",
    "entryPoint": "Azure.Messaging.Replication.EventHubReplicationTasks.ForwardToEventHub"
    ...
```

The following table gives you the correct values for combinations of sources and targets:

| Source      | Target      | Entry Point 
|-------------|-------------|------------------------------------------------------------------------
| Event Hub   | Event Hub   | `Azure.Messaging.Replication.EventHubReplicationTasks.ForwardToEventHub`
| Event Hub   | Service Bus | `Azure.Messaging.Replication.EventHubReplicationTasks.ForwardToServiceBus`
| Service Bus | Event Hub   | `Azure.Messaging.Replication.ServiceBusReplicationTasks.ForwardToEventHub`
| Service Bus | Service Bus | `Azure.Messaging.Replication.ServiceBusReplicationTasks.ForwardToServiceBus`

### Retry policy

Refer to the [Azure Functions documentation on
retries](../azure-functions/functions-bindings-error-pages?tabs=csharp) to
configure the retry policy. The policy settings chosen throughout the projects
in this repository configure an exponential backoff strategy with retry
intervals from 5 seconds to 5 minutes with infinite retries to avoid data loss.

For Service Bus, review the ["using retry support on top of trigger
resilience"](../azure-functions/functions-bindings-error-pages?tabs=csharp#using-retry-support-on-top-of-trigger-resilience)
section to understand the interaction of triggers and the maximum delivery count
defined for the queue.

### Build, Configure, Deploy

Once you've created the tasks you need, you need to build the project, configure
the (existing) application, and deploy the tasks.

#### Build

The `Build-FunctionApp.ps1` Powershell script will build the project and put all
required files into the `./bin` folder immediately underneath the project root.
This needs to be run after every change. 

#### Configure

The `Configure-Function.ps1` Powershell script calls the shared [Update-PairingConfiguration.ps1](../../../scripts/powershell/README.md) Powershell script and needs to be run once for each task in an existing Function
app, for the configured pairing.

For instance, assume a task `EventHubAToEventHubB` that is configured like this:

```JSON
{
    "configurationSource": "config",
    "bindings" : [
        {
            "direction": "in",
            "type": "eventHubTrigger",
            "connection": "EventHubAToEventHubB-source-connection",
            "eventHubName": "EventHubA",
            "name": "input" 
        },
        {
            "direction": "out",
            "type": "eventHub",
            "connection": "EventHubAToEventHubB-target-connection",
            "eventHubName": "EventHubB",
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
    "scriptFile": "../dotnet/bin/Azure.Messaging.Replication.dll",
    "entryPoint": "Azure.Messaging.Replication.EventHubReplicationTasks.ForwardToEventHub"
}
```
For this task, you would configure the Function application and the permissions
on the messaging resources like this:

```powershell
Configure-Function.ps1 -ResourceGroupName "myreplicationapp" 
                          -FunctionAppName "myreplicationapp" 
                          -TaskName "EventHubAToEventHubB"
                          -SourceNamespaceName "my1stnamespace"
                          -SourceEventHubName "EventHubA" 
                          -TargetNamespaceName "my2ndnamespace"
                          -TargetEventHubName "EventHubB"
```

The script assumes that the messaging resources - here the Event Hub and the Queue - already exist. The configuration script will add the required configuration entries to the application configuration.

#### Deploy

Once the build and Configure tasks are complete, the directory can be deployed into the Azure Functions app as-is. The `Deploy-FunctionApp.ps1` script simply calls the publish task of the Azure Functions tools:

```Powershell
func azure functionapp publish "myreplicationapp" 
```

Replication applications are regular Azure Function applications and you can therefore use any of the [available deployment options](https://docs.microsoft.com/en-us/azure/azure-functions/functions-deployment-technologies). For testing, you can also run the [application locally](https://docs.microsoft.com/en-us/azure/azure-functions/functions-develop-local), but with the messaging services in the cloud.

In CI/CD environments, you simply need to integrate the steps described above into a build script.