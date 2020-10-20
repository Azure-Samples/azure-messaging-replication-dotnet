## Powershell Utility Scripts

### Update-PairingConfiguration.ps1

This Powershell script configures a pair of Events Hubs, Service Bus Queues, or
Service Bus Topics with Subscriptions, and any combination of those, for use
with a single replication task. The "source" designates the entity from which
messages are read, the "target" designates the entity to which messages are
being forwarded.


```powershell
.\Update-PairingConfiguration.ps1
   -TaskName <String>
   -FunctionAppName <String>
   -SourceNamespaceName <String>
   [-SourceEventHubName] <String> 
   [-SourceQueueName] <String> 
   [-SourceTopicName] <String> 
   [-SourceSubscriptionName] <String> 
    -TargetNamespaceName <String>
   [-TargetEventHubName] <String>
   [-TargetQueueName] <String>
   [-TargetTopicName] <String>
```

Arguments:

* **`-TaskName`** (Mandatory) - Name of the task. Must match the name of the function that is being configured.
* **`-FunctionAppName`** (Mandatory) - Name of the Azure Function. Must match the name of the Azure Functions application.
* **`-SourceNamespaceName`** (Mandatory) - Name of the source Event Hubs or Service Bus namespace. It's not required to provide the fully qualified domain name. The unqualified namespace name is sufficient.
* **`-SourceEventHubName`** or **`-SourceQueueName`** or **`-SourceTopicName`**/**`-SourceSubscriptionName`** (Mutually exclusive and mandatory) - Name of the source entity. Must specify only one option. `-SourceTopicName` and `-SourceSubscriptionName` must be specified together.
* **`-TargetNamespaceName`** (Mandatory) - Name of the target Event Hubs or Service Bus namespace. The unqualified namespace name is sufficient.
* **`-TargetEventHubName`** or **`-TargetQueueName`** or **`-TargetTopicName`** (Mutually exclusive and mandatory) - Name of the target entity. Must specify only one.