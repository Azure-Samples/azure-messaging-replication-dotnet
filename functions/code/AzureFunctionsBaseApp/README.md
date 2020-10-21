## Azure Functions Replication Template Project

This is a preconfigured project for your own replication tasks. You can either
reference the standard tasks, as shown in other sample projects parallel to this
one, or you can write your own tasks.

The `AzureFunctionsBaseApp.csproj` project file already references the Azure
Event Hubs, Azure Service Bus, and Azure Storage extensions for Azure Functions
as well as the Azure Functions SDK. It also references the standard tasks from
this repository.

### Adding replication tasks

To add replication tasks, follow the guidance in the Azure Functions documentation for [triggers](https://docs.microsoft.com/en-us/azure/azure-functions/functions-triggers-bindings?tabs=csharp):

* [Azure Event Hubs trigger](https://docs.microsoft.com/en-us/azure/azure-functions/functions-bindings-event-hubs-trigger?tabs=csharp) 
* [Azure Service Bus trigger](https://docs.microsoft.com/en-us/azure/azure-functions/functions-bindings-service-bus-trigger?tabs=csharp) 
* [Azure IoT Hub trigger](https://docs.microsoft.com/en-us/azure/azure-functions/functions-bindings-event-iot-trigger?tabs=csharp) 
* [Azure Event Grid trigger](https://docs.microsoft.com/en-us/azure/azure-functions/functions-bindings-event-grid-trigger?tabs=csharp)
* [Azure Queue Storage trigger](https://docs.microsoft.com/en-us/azure/azure-functions/functions-bindings-storage-queue-trigger?tabs=csharp)  
* [Apache Kafka trigger](https://github.com/azure/azure-functions-kafka-extension)
* [RabbitMQ trigger](https://github.com/azure/azure-functions-rabbitmq-extension) 

Whenever available, you should prefer the batch-oriented triggers over triggers that deliver individual events or messages and you should always obtain the complete event or message structure rather than rely on Azure Function's [parameter binding expressions](https://docs.microsoft.com/en-us/azure/azure-functions/functions-bindings-expressions-patterns). 

The name of the function should reflect the pair of source and target you are connecting, and you should prefix references to connection strings or other configuration elements in the application configuration files with that name. 

As an example for the recommended usage pattern, consider this function asking for an array (batch) of `EventData` objects from an Event Hub.

```csharp
[FunctionName("Eh1ToEh2")]
public static void Eh1ToEh2(
    [EventHubTrigger("eh1", Connection = "Eh1ToEh2-source-connection")]
    EventData[] input,
    // ... output binding ...
    ILogger log)
{
    foreach (var message in input)
    {
        // ... copy to output ...
    }
}
```

Once you've created a function based on a trigger, you can [bind the
output](https://docs.microsoft.com/en-us/azure/azure-functions/functions-triggers-bindings?tabs=csharp)
of the function to a target. The following list enumerates the options directly
supported by Azure Functions:

* [Azure Event hubs output binding](https://docs.microsoft.com/en-us/azure/azure-functions/functions-bindings-event-hubs-output?tabs=csharp) 
* [Azure Service Bus output binding](https://docs.microsoft.com/en-us/azure/azure-functions/functions-bindings-service-bus-output?tabs=csharp)
* [Azure IoT Hub output binding](https://docs.microsoft.com/en-us/azure/azure-functions/functions-bindings-event-iot-output?tabs=csharp) 
* [Azure Queue Storage output binding](https://docs.microsoft.com/en-us/azure/azure-functions/functions-bindings-storage-queue-output?tabs=csharp)
* [Azure Notification Hubs output binding](https://docs.microsoft.com/en-us/azure/azure-functions/functions-bindings-notification-hubs) 
* [Azure SignalR service output binding](https://docs.microsoft.com/en-us/azure/azure-functions/functions-bindings-signalr-service-output?tabs=csharp)
* [Azure Event Grid output binding](https://docs.microsoft.com/en-us/azure/azure-functions/functions-bindings-event-grid-output?tabs=csharp) 
* [Twilio SendGrid output binding](https://docs.microsoft.com/en-us/azure/azure-functions/functions-bindings-sendgrid?tabs=csharp) 
* [Apache Kafka output binding](https://github.com/azure/azure-functions-kafka-extension) 
* [RabbitMQ output binding](https://github.com/azure/azure-functions-rabbitmq-extension) 

Again, prefer the batch version of the output binding where available. 

For Event Hubs, you can bind an `IAsyncCollector<EventData>` as the output which will
cause a batch transfer. For Service Bus, you can bind `IAsyncCollector<Message>`.

The example below completes the prior one by copying data from an Event Hub input to an Event Hub output. You can obviously modify the event or message or create an entirely new one, or even emit zero or multiple output events based on one input event, while your code is in control.


```csharp
[FunctionName("Eh1ToEh2")]
public static void Eh1ToEh2(
    [EventHubTrigger("eh1", Connection = "Eh1ToEh2-source-connection")]
    EventData[] input,
    [EventHub("eh2", Connection = "Eh1ToEh2-target-connection")
    IAsyncCollector<EventData> output,
    ILogger log)
{
    foreach (var eventData in input)
    {
        // ...your task to transform, transcode, enrich, reduce, validate, etc. ...

        await output.AddAsync(eventData);
    }
}
```

### Data and metadata mapping

Once you've decided on a pair of input trigger and output binding, you will have to perform some mapping between the different event or message types, unless the type of your trigger and the output is the same.

For instance, going from Event Hub to another Event Hub is trivial as the prior example shows. If you want to map between different messaging services, you will need to do some metadata mapping.

> The mappings shown here will become simpler and at the same time more complete
> with the coming update of the Azure Event Hubs and Azure Service Bus triggers
> based on the new Azure SDK where the underlying AMQP structures can be accessed
> directly and also copied into new messages.

#### Service Bus To Event Hubs

Going from Service Bus to Event Hubs, you should copy several of the system properties from the Service Bus input message such that the metadata is not lost. Event Hubs preserves this information on events passing through it, even though the properties are not available on the strongly typed API. The SessionId is mapped to the Event Hub PartitionKey if available, such that related events stay together. 

```csharp
[FunctionName("QueueAtoEh1")]
public static async Task QueueAtoEh1(
    [ServiceBusTrigger("queue-a", Connection = "QueueAtoEh1-source-connection")]
    Message[] input, 
    [EventHub("eh1", Connection = "QueueAtoEh1-target-connection")]
    IAsyncCollector<EventData> output, ILogger log)
{
    foreach (var message in input)
    {
        var eventData = new EventData(message.Body)
        {
            SystemProperties =
            {
                { "content-type", message.ContentType },
                { "to", message.To },
                { "correlation-id", message.CorrelationId },
                { "subject", message.Label },
                { "reply-to", message.ReplyTo },
                { "reply-to-group-name", message.ReplyToSessionId },
                { "message-id", message.MessageId },
                { "x-opt-partition-key", message.PartitionKey ?? message.SessionId }
            }
        };

        foreach (var property in message.UserProperties)
        {
            eventData.Properties.Add(property);
        }

        await output.AddAsync(eventData);
    }
}
```

This mapping is also implemented in the `Azure.Messaging.ReplicationServiceBusReplicationTasks.ForwardToEventHub()` helper, which can be used instead:

```csharp
[FunctionName("Eh1ToQueueA")]
public static async Task Eh1ToQueueA(
    [EventHubTrigger("eh1", Connection = "Eh1ToQueueA-source-connection")]
    EventData[] input, 
    [ServiceBus("queueA", Connection = "Eh1ToQueueA-target-connection")]
    IAsyncCollector<Message> output,
    ILogger log)
{
   return ServiceBusReplicationTasks.ForwardToEventHub(input, output, log);
}
```

#### Event Hubs to Service Bus

When mapping from Service Bus to Event Hubs, you'll do the same metadata mapping in the other direction. 

```csharp
[FunctionName("Eh1ToQueueA")]
public static async Task Eh1ToQueueA(
    [EventHubTrigger("eh1", Connection = "Eh1ToQueueA-source-connection")]
    EventData[] input, 
    [ServiceBus("queueA", Connection = "Eh1ToQueueA-target-connection")]
    IAsyncCollector<Message> output,
    ILogger log)
{
    foreach (EventData eventData in input)
    {
        var item = new Message(eventData.Body.ToArray())
        {
            ContentType = eventData.SystemProperties["content-type"] as string,
            To = eventData.SystemProperties["to"] as string,
            CorrelationId = eventData.SystemProperties["correlation-id"] as string,
            Label = eventData.SystemProperties["subject"] as string,
            ReplyTo = eventData.SystemProperties["reply-to"] as string,
            ReplyToSessionId = eventData.SystemProperties["reply-to-group-name"] as string,
            MessageId = eventData.SystemProperties["message-id"] as string ?? eventData.SystemProperties.Offset,
            PartitionKey = eventData.SystemProperties.PartitionKey,
            SessionId = eventData.SystemProperties.PartitionKey
        };

        foreach (var property in eventData.Properties)
        {
            item.UserProperties.Add(property);
        }

        await output.AddAsync(item);
    }
}
```

This mapping is also implemented in the `Azure.Messaging.Replication.EventHubReplicationTasks.ForwardToServiceBus()` helper, which can be used instead:

```csharp
[FunctionName("Eh1ToQueueA")]
public static async Task Eh1ToQueueA(
    [EventHubTrigger("eh1", Connection = "Eh1ToQueueA-source-connection")]
    EventData[] input, 
    [ServiceBus("queueA", Connection = "Eh1ToQueueA-target-connection")]
    IAsyncCollector<Message> output,
    ILogger log)
{
   return EventHubReplicationTasks.ForwardToServiceBus(input, output, log);
}
```

### Configure and Deploy

Once you've created the tasks you need, you will build the project, configure
the [existing application host](../../../templates/README.md), and deploy.

The `Configure-Function.ps1` Powershell script calls the shared [Update-PairingConfiguration.ps1](../../../scripts/powershell/README.md) Powershell script and needs to be run once for each task in an existing Function
app, for the configured pairing.

For instance, assume the task `Eh1ToQueueA` from above. For this task, you would configure the Function application and the permissions on the messaging resources like this:

```powershell
Configure-Function.ps1  -ResourceGroupName "myreplicationapp"
                        -FunctionAppName "myreplicationapp"
                        -TaskName "Eh1ToQueueA"
                        -SourceEventHubNamespaceName "my1stnamespace"
                        -SourceEventHubName "eh1"
                        -TargetEventHubNamespaceName "my2ndnamespace"
                        -TargetQueueName "queue-a"
```

The script assumes that the messaging resources - here the Event Hub and the Queue - already exist. The configuration script will add the required configuration entries to the application configuration. 

Mind that this particular script currently only covers Event Hubs and Service Bus.

Replication applications are regular Azure Function applications and you can
therefore use any of the [available deployment
options](https://docs.microsoft.com/en-us/azure/azure-functions/functions-deployment-technologies).
For testing, you can also run the [application
locally](https://docs.microsoft.com/en-us/azure/azure-functions/functions-develop-local),
but with the messaging services in the cloud.

