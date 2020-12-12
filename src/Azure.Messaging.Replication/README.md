## Helper methods for replication tasks

This project implements direct and conditional forwarding methods to copy events and messages 
between Service Bus and Event Bus sources and targets. All methods are static.

In the context of a replication task, you use the helpers as follows:

### Event Hubs
For an Event Hubs trigger, use the
[EventHubReplicationTasks](EventHubReplicationTasks.cs), which take a batch of
events as input. For Event Hub outputs you must pass a bound `EventHubClient`, for Service Bus outputs a bound `IAsyncCollector<Message>`.

```csharp
[FunctionName("telemetry")]
[ExponentialBackoffRetry(-1, "00:00:05", "00:05:00")]
public static Task Telemetry(
    [EventHubTrigger("telemetry", ConsumerGroup = "%telemetry-source-consumergroup%", Connection = "telemetry-source-connection")] EventData[] input,
    [EventHub("telemetry-copy", Connection = "telemetry-target-connection")] EventHubClient outputClient,
    ILogger log)
{
    return EventHubReplicationTasks.ForwardToEventHub(input, outputClient, log);
}
```

### Service Bus

For a Service Bus trigger, use the
[ServiceBusReplicationTasks](ServiceBusReplicationTasks.cs), which take a batch of
messages as input. 

```csharp
[FunctionName("jobs-transfer")]
[ExponentialBackoffRetry(-1, "00:00:05", "00:05:00")]
public static Task JobsTransfer(
    [ServiceBusTrigger("jobs-transfer", Connection = "jobs-transfer-source-connection")] Message[] input,
    [ServiceBus("jobs", Connection = "jobs-target-connection")] IAsyncCollector<Message> output,
    ILogger log)
{
    return ServiceBusReplicationTasks.ForwardToServiceBus(input, output, log);
}
```

### Conditional forwarding

The conditional variants expect a callback function, which gets a message/event
passed as input and returns either `null` for that message/event to be filtered
out from replication, or a new/modified message/event, or the exact input
message/event. The following example is a filter that also adds an annotation:

```csharp
[FunctionName(taskTelemetryLeft)]
[ExponentialBackoffRetry(-1, "00:00:05", "00:05:00")]
public static Task TelemetryLeft(
    [EventHubTrigger(leftEventHubName, ConsumerGroup = leftEventHubConsumerGroup, Connection = leftEventHubConnection)] EventData[] input,
    [EventHub(rightEventHubName, Connection = rightEventHubConnection)] EventHubClient outputClient,
    ILogger log)
{
    return EventHubReplicationTasks.ConditionalForwardToEventHub(input, outputClient, log, (inputEvent) => {
        if ( !inputEvent.Properties.ContainsKey("repl-target") || 
                !string.Equals(inputEvent.Properties["repl-target"] as string, leftEventHubName)) {
                inputEvent.Properties["repl-target"] = rightEventHubName;
                return inputEvent;
        }
        return null;
    });
}
```

## Methods overview

The direct forwarding functions are:

| Source      | Target      | Entry Point 
|-------------|-------------|------------------------------------------------------------------------
| Event Hub   | Event Hub   | `Azure.Messaging.Replication.EventHubReplicationTasks.ForwardToEventHub`
| Event Hub   | Service Bus | `Azure.Messaging.Replication.EventHubReplicationTasks.ForwardToServiceBus`
| Service Bus | Event Hub   | `Azure.Messaging.Replication.ServiceBusReplicationTasks.ForwardToEventHub`
| Service Bus | Service Bus | `Azure.Messaging.Replication.ServiceBusReplicationTasks.ForwardToServiceBus`

The conditional forwarding functions are:

| Source      | Target      | Entry Point 
|-------------|-------------|------------------------------------------------------------------------
| Event Hub   | Event Hub   | `Azure.Messaging.Replication.EventHubReplicationTasks.ConditionalForwardToEventHub`
| Event Hub   | Service Bus | `Azure.Messaging.Replication.EventHubReplicationTasks.ConditionalForwardToServiceBus`
| Service Bus | Event Hub   | `Azure.Messaging.Replication.ServiceBusReplicationTasks.ConditionalForwardToEventHub`
| Service Bus | Service Bus | `Azure.Messaging.Replication.ServiceBusReplicationTasks.ConditionalForwardToServiceBus`
