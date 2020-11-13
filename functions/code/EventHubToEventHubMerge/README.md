## Event Hub to Event Hub Merge

This project builds on the [baseline application](../CodeBaseApp/README.md) and
provides a pre-configured task that merges the event streams of two Event Hubs.
The project also included an Azure Resource manager template to easily deploy an
Event Hub namespace and two Event Hubs, so that you can quickly try things out.

The project [implements](EventHubToEventHubMerge.cs) two functions, `Eh1ToEh2`
and `Eh2ToEh1` that references the included library of standard tasks
(`Azure.Messaging.Replication`).

The relevant code is:

```csharp
[FunctionName("Eh1ToEh2")]
[ExponentialBackoffRetry(-1, "00:00:05", "00:05:00")]
public static Task Eh1ToEh2(
    [EventHubTrigger("eh1", ConsumerGroup = "Eh1ToEh2", Connection = "Eh1ToEh2-source-connection")] EventData[] input,
    [EventHub("eh2", Connection = "Eh1ToEh2-target-connection")] EventHubClient outputClient,
    ILogger log)
{
    return EventHubReplicationTasks.ForwardToEventHub(input, outputClient, log, (event) => {
        // if the event didn't get into eh1 by ways of replication, move it into eh2 and mark it for eh2
        if ( !event.Properties.ContainsKey("repl-target") || event.Properties["repl-target"] != "eh1") {
                event.Properties["repl-target"] = "eh2";
                return event;
        }
        return null;
    });
}

[FunctionName("Eh2ToEh1")]
[ExponentialBackoffRetry(-1, "00:00:05", "00:05:00")]
public static Task Eh2ToEh1(
    [EventHubTrigger("eh2", ConsumerGroup = "Eh2ToEh1", Connection = "Eh2ToEh1-source-connection")] EventData[] input,
    [EventHub("eh1", Connection = "Eh2ToEh1-target-connection")] EventHubClient outputClient,
    ILogger log)
{
    return EventHubReplicationTasks.ForwardToEventHub(input, outputClient, log, (event) => {
        // if the event didn't get into eh2 by ways of replication, move it into eh1 and mark it for eh1
        if ( !event.Properties.ContainsKey("repl-target") || event.Properties["repl-target"] != "eh2") {
                event.Properties["repl-target"] = "eh1";
                return event;
        }
        return null;
    });
}
```

The key difference to the simple copy scenario is that the functions check, by
evaluating the `repl-target` user property, whether the event has been marked
has having been replicated into the source Event Hub. If that is so, the
replication ignores the event by returning `null` from the factory callback.
Otherwise, the incoming event is returned after having been marked up with the
same property indicating the target Event Hub name. This technique avoids
already replicated events to bounce between two or more Event Hubs that are
being merged in this fashion.

The `Connection` values refer to the name of configuration entries in the
application settings of the Functions application. The configuration step below
sets these.

As explained in the baseline application description, you can also modify the
event while your code is in control.

### Setup

This example includes an Azure Resource Manager template that creates a new
standard Event Hub namespace and two Event Hubs, named "eh1" and "eh2. You can
deploy the template into a new or existing resource group with the included
PowerShell script, for example:

```powershell
.\Deploy-Resources.ps1 -ResourceGroupName myresourcegroup -Location westeurope -NamespaceName -mynamespace
```

After this step, you will need to build the project and configure the [existing
Function application host](../../../templates/README.md).

The  `Configure-Function.ps1` Powershell script calls the shared
[Update-PairingConfiguration.ps1](../../../scripts/powershell/README.md)
Powershell script and needs to be run once for each task in an existing Function
app, for the configured pairing.

For the task at hand, you will configure the Function application and the
permissions on the messaging resources like this. Mind that we host both Event
Hubs in the same namespace to keep the example simple. 

```powershell
Configure-Function.ps1  -FunctionAppName "myreplicationapp"
                        -TaskName "Eh1ToEh2"
                        -SourceNamespaceName "mynamespace"
                        -SourceEventHubName "eh1"
                        -TargetNamespaceName "mynamespace"
                        -TargetEventHubName "eh2"

Configure-Function.ps1  -FunctionAppName "myreplicationapp"
                        -TaskName "Eh2ToEh1"
                        -SourceNamespaceName "mynamespace"
                        -SourceEventHubName "eh2"
                        -TargetNamespaceName "mynamespace"
                        -TargetEventHubName "eh1"
```

To cleanup the Event Hub, you can use the supplied `Remove-EventHub.ps1` script.

### Deployment

Replication applications are regular Azure Function applications and you can
therefore use any of the [available deployment
options](https://docs.microsoft.com/en-us/azure/azure-functions/functions-deployment-technologies).
For testing, you can also run the [application
locally](https://docs.microsoft.com/en-us/azure/azure-functions/functions-develop-local),
but with the messaging services in the cloud.

Using the Azure Functions tools, the simplest way to deploy the application is 

```powershell
func azure functionapp publish "myreplicationapp" --force
```
