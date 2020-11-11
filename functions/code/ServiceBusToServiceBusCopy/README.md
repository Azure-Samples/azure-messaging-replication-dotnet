## Service Bus to Service Bus Copy

This project builds on the [baseline application](../CodeBaseApp/README.md) and
provides a pre-configured task that copies event streams between two Service Bus queues.
The project also included an Azure Resource manage template to easily deploy an
Service Bus namespace and two Service Bus queues, so that you can quickly try things out.

The project implements a single function,
[`QueueAToQueueB`](ServiceBusToServiceBusCopy.cs) that references the included library of
standard tasks (`Azure.Messaging.Replication`), which is generally recommended.

The relevant code is a simple as this:

```csharp
[FunctionName("QueueAtoQueueB")]
public static Task QueueAtoQueueB(
    [ServiceBusTrigger("queue-a", Connection = "QueueAtoQueueB-source-connection")] Message[] input,
    [ServiceBus("queue-b", Connection = "QueueAtoQueueB-target-connection")] IAsyncCollector<Message> output,
    ILogger log)
{
    return ServiceBusReplicationTasks.ForwardToServiceBus(input, output, log);
}
```

The `Connection` values refer to the name of configuration entries in the
application settings of the Functions application. The configuration step below
sets these. 

As explained in the baseline application description, you can also modify the
event while your code is in control.

### Setup

This example includes an Azure Resource Manager template that creates a new
standard Service Bus namespace and two Service Bus queues, named "queue-a" and "queue-b". You can
deploy the template into a new or existing resource group with the included
PowerShell script, for example:

```powershell
.\Deploy-Resources.ps1 -ResourceGroupName myresourcegroup -Location westeurope -NamespaceName -mynamespace
```

After this step, you will need to build the project and configure the [existing
Function application host](../../../templates/README.md).

The `Configure-Function.ps1` Powershell script calls the shared
[Update-PairingConfiguration.ps1](../../../scripts/powershell/README.md)
Powershell script and needs to be run once for each task in an existing Function
app, for the configured pairing.

For the task at hand, you will configure the Function application and the
permissions on the messaging resources like this. Mind that we host both Event
Hubs in the same namespace to keep the example simple. 

```powershell
Configure-Function.ps1  -ResourceGroupName "myreplicationapp"
                        -FunctionAppName "myreplicationapp"
                        -TaskName "QueueAToQueueB"
                        -SourceNamespaceName "mynamespace"
                        -SourceEventHubName "queue-a"
                        -TargetNamespaceName "mynamespace"
                        -TargetQueueName "queue-b"
```

To cleanup the Service Bus, you can use the supplied `Remove-ServiceBus.ps1` script.

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
