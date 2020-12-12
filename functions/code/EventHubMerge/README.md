## Merged Event Hubs (Active/Active)  (C#)

This project illustrates how to build and deploy a bi-directional replication
app that continuously merges the events of two Azure Event Hubs.

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

The bi-directional [merge](https://docs.microsoft.com/azure/event-hubs/event-hubs-federation-patterns#merge)
pattern can be readily implemented with this project.

### Replication topology 

For configuring and running this replication function, you need two Event Hubs
residing in different namespaces that may be located in different Azure regions.

Since we are replicating bi-directionally, we will refer to the Event Hubs as
*left* and *right*.

On both Event Hubs, you will need to create a dedicated [consumer
group](https://docs.microsoft.com/azure/event-hubs/event-hubs-features#consumer-groups)
for the replication function that will allow the functions to manage scaling and
keep track of its progress on the source event hub.

The following diagram shows an exemplary topology with a suggested convention
for naming the various elements. Here, the replication function name reflects
the name of the Event Hub it mirrors from source to target, and the consumer
group names reflect the replication app and function name.

The naming is ultimately up to you and will follow whatever conventions you
define for your scenario.

```markdown
              Left Event Hub                Replication App                Right Event Hub
+----------------------------------+ +-------------------------+  +----------------------------------+             
|     Namespace (West Europe)      | |      Function App       |  |       Namespace (East US 2)      |
|        "example-eh-weu"          | | "repl-example-weu-eus2" |  |        "example-eh-eus2"         |
|                                  | |                         |  |                                  |
| +-------------+                  | |  +------------------+   |  |                  +-------------+ |
  |             |                  | |  |     Function     |   |  |                  |             | |
  |   +-------------------------+       |                  |                         |  Event Hub  | 
  |   |     Consumer Group      |       | "telemetry-weu-  |                         | "telemetry" | 
  |   |"merge-example.telemetry"|====>==|     to-eus2"     |====>====================|             | 
  |   +-------------------------+       +------------------+                         |             | 
  |             |                                                                    |             | 
  |             |                       +------------------+         +-------------------------+   |
  |             |                       |     Function     |         |      Consumer Group     |   |
  |  Event Hub  |==================<====|                  |====<====|"merge-example.telemetry"|   |
  | "telemetry" |                       | "telemetry-eus2- |         +-------------------------+   |
  |             |                       |     to-weu"      |                         |             |
  +-------------+                       +------------------+                         +-------------+
```
#### Exemplary topology

For convenience, the project contains an [ARM
template](https://docs.microsoft.com/azure/event-hubs/event-hubs-resource-manager-namespace-event-hub)
in the [template folder](template) that allows you to quickly deploy an
exemplary topology with two Event Hub namespaces to try things out. The
general assumption is that you already have a topology in place.

To make it easier to deal with the various scripts below, let's start with
setting up a few script variables (Azure Cloud Shell, Bash) defining the names
of the resources we will set up. You will have to define your own unique names
for all variables prefixed with 'USER_'.

```bash
AZURE_LOCATION=westeurope
USER_RESOURCE_GROUP=example-eh-weu
USER_LEFT_NAMESPACE_NAME=example-eh1-weu
USER_RIGHT_NAMESPACE_NAME=example-eh2-weu
USER_FUNCTIONS_APP_NAME=example-eh-weu
USER_STORAGE_ACCOUNT=exampleehweu
```


You can deploy the template as follows, replacing the exemplary resource group
and namespace names to make them unique and choosing your preferred region.

First, if you have not done so, log into your account:

```azurecli
az login
```

The [az login](/cli/azure/reference-index#az_login) command signs you into your Azure account.

```azurecli
az group create --location $AZURE_LOCATION --name $USER_RESOURCE_GROUP
az deployment group create --resource-group $USER_RESOURCE_GROUP \
                           --template-file 'template\azuredeploy.json' \
                           --parameters LeftNamespaceName='$USER_LEFT_NAMESPACE_NAME' \
                                        RightNamespaceName='$USER_RIGHT_NAMESPACE_NAME' \
                                        FunctionAppName='$USER_FUNCTIONS_APP_NAME' 
```

The created Event Hubs are named "telemetry" in both namespaces. The name of
the consumer groups created on the Event Hubs is prefixed with the function app
name, e.g. "repl-example-weu.telemetry"

### Building, Configuring, and Deploying the Replication App

Leaning on the naming conventions of the exemplary topology, the project
implements two replication tasks named that perform the required copies.

You will find the functions in the [Tasks.cs](Tasks.cs) file.

> **IMPORTANT:**<br><br> 
> The attribute-driven configuration model for Azure Functions written in C# and
> Java requires that you modify the names of the target and source Event Hubs and
> the source consumer group in the attribute values to fit your topology names.
> Since we're cross-replicating two Event Hubs, the values are used multiple times
> and therefore configured in constants, which the attribute-based model requires. 

```csharp
using System;
using System.Collections.Generic;
using System.Threading.Tasks;
using Microsoft.Azure.EventHubs;
using Microsoft.Azure.WebJobs;
using Microsoft.Extensions.Logging;
using Azure.Messaging.Replication;

namespace EventHubToEventHubMerge
{
    public static class Tasks
    {
        static const string functionAppName = "merge-example";
        static const string taskTelemetryLeftToRight = "telemetry-westeurope-to-eastus2";
        static const string taskTelemetryRightToLeft =  "telemetry-eastus2-to-westeurope";
        static const string rightEventHubName = "telemetry";
        static const string leftEventHubName = "telemetry";
        static const string rightEventHubConnection = "telemetry-eus2-connection";
        static const string leftEventHubConnection = "telemetry-weu-connection";
        
        [FunctionName(taskTelemetryLeftToRight)]
        [ExponentialBackoffRetry(-1, "00:00:05", "00:05:00")]
        public static Task TelemetryLeftToRight(
            [EventHubTrigger(leftEventHubName, ConsumerGroup = $"{functionAppName}.{taskTelemetryLeftToRight}", Connection = leftEventHubConnection)] EventData[] input,
            [EventHub(rightEventHubName, Connection = rightEventHubConnection)] EventHubClient outputClient,
            ILogger log)
        {
            return EventHubReplicationTasks.ConditionalForwardToEventHub(input, outputClient, log, (inputEvent) => {
                const string replyTarget = $"{functionAppName}.{taskTelemetryLeftToRight}";
                if ( !inputEvent.Properties.ContainsKey("repl-target") || 
                     !string.Equals(inputEvent.Properties["repl-target"] as string, leftEventHubName) {
                      inputEvent.Properties["repl-target"] = rightEventHubName;
                      return inputEvent;
                }
                return null;
            });
        }

        [FunctionName(taskTelemetryRightToLeft)]
        [ExponentialBackoffRetry(-1, "00:00:05", "00:05:00")]
        public static Task TelemetryRightToLeft(
            [EventHubTrigger(rightEventHubName, ConsumerGroup = $"{functionAppName}.{taskTelemetryRightToLeft}", Connection = rightEventHubConnection)] EventData[] input,
            [EventHub(leftEventHubName, Connection = leftEventHubConnection)] EventHubClient outputClient,
            ILogger log)
        {
            return EventHubReplicationTasks.ConditionalForwardToEventHub(input, outputClient, log, (inputEvent) => {
                if ( !inputEvent.Properties.ContainsKey("repl-target") || 
                     !string.Equals(inputEvent.Properties["repl-target"] as string, rightEventHubName) {
                      inputEvent.Properties["repl-target"] = leftEventHubName;
                      return inputEvent;
                }
                return null;
            });
        }
    }
}
```

The `Connection` attribute values refer to the name of configuration entries in the
application settings of the Functions application. The [setup](#setup) step below
explains how to set those.

The code calls the pre-built helper method
`EventHubReplicationTasks.ConditionalForwardToEventHub` from the
[`Azure.Messaging.Replication`](/src/Azure.Messaging.Replication/) project which
also resides in this repository. The method conditionally copies the events from the source
batch to the given Event Hub client while preserving the [correct order for each stream](https://docs.microsoft.com/azure/event-hubs/event-hubs-federation-patterns#service-assigned-metadata) and [adding annotations for service-assigned metadata](https://docs.microsoft.com/azure/event-hubs/event-hubs-federation-patterns#streams-and-order-preservation).

The condition is realized using a callback of type `Func<EventData,EventData>`
that suppresses forwarding the event if the custom "repl-target" property is
present and its value corresponds to the name of the source Event Hub. If that
is the case, the event has been replicated into source Event Hub and shall no
longer be replicated out. Otherwise, the property is set to the name of the
target Event Hub.

A published NuGet assembly is not available, but will be made available
later as part of an update to the Azure Functions runtime.

### Setup

Before we can deploy and run the replication application, we need to create an
Azure Functions host and then configure that host such that the connection
strings for the source and target Event Hubs are available for the replication
task to use.

> **NOTE**<br><br>
> Mind that all shown parameter values are examples and you will have to adapt them to
> your chosen names for resource groups and namespaces and function applications.

#### Create the Functions App

> **NOTE**<br><br>In the [templates](/templates/README.md) folder of this repository, you will
find a set of ARM templates that simplify this step.

Before you can deploy your function code to Azure, you need to create three resources:

- A resource group, which is a logical container for related resources.
- A Storage account, which maintains state and other information about your projects.
- A function app, which provides the environment for executing your function code. A function app maps to your local function project and lets you group functions as a logical unit for easier management, deployment, and sharing of resources.

If you replicate data across regions, you will have to pick one of the regions
to host the replicator.

Use the following commands to create these items. 

1. If you haven't done so already, sign in to Azure:

    Azure CLI
    ```azurecli
    az login
    ```

    The [az login](/cli/azure/reference-index#az_login) command signs you into your Azure account.

2. Reuse the resource group of your Event Hub(s) or create a new one: 

    ```azurecli
    az group create --name $USER_RESOURCE_GROUP --location $AZURE_LOCATION
    ```
    
    The [az group create](/cli/azure/group#az_group_create) command creates a resource group. You generally create your resource group and resources in a region near you, using an available region returned from the `az account list-locations` command.

    
3. Create a general-purpose storage account in your resource group and region:

    ```azurecli
    az storage account create --name $USER_STORAGE_ACCOUNT --location $AZURE_LOCATION --resource-group $USER_RESOURCE_GROUP --sku Standard_LRS
    ```

    The [az storage account create](/cli/azure/storage/account#az_storage_account_create) command creates the storage account. The storage account is required for Azure Functions to manage its internal state and is also used to keep the checkpoints for the source Event Hubs.

    Set USER_STORAGE_ACCOUNT to a name that is appropriate to you and unique in Azure Storage. Names must contain three to 24 characters numbers and lowercase letters only. `Standard_LRS` specifies a general-purpose account, which is [supported by Functions](../articles/azure-functions/storage-considerations.md#storage-account-requirements).


4. Create an Azure Functions app 
        
    ```azurecli
    az functionapp create --resource-group $USER_RESOURCE_GROUP --consumption-plan-location $AZURE_LOCATION --runtime dotnet --functions-version 3 --name $USER_FUNCTIONS_APP_NAME --storage-account $USER_STORAGE_ACCOUNT
    ```
    The [az functionapp create](/cli/azure/functionapp#az_functionapp_create) command creates the function app in Azure. 

    Set USER_FUNCTIONS_APP_NAME to a globally unique name appropriate to you. The USER_FUNCTIONS_APP_NAME value is also the default DNS domain prefix for the function app.

    This command creates a function app running in your specified language runtime under the [Azure Functions Consumption Plan](functions-scale.md#consumption-plan), which is free for the amount of usage you incur here. The command also provisions an associated Azure Application Insights instance in the same resource group, with which you can monitor your function app and view logs. For more information, see [Monitor Azure Functions](functions-monitoring.md). The instance incurs no costs until you activate it.


#### Configure the Function App

The exemplary task refers to a *right* Event Hub connection ("telemetry-eus2_connection") and a *left* Event Hub connection ("telemetry-weu-connection") for the trigger and output binding attribute `Connection` property values:

Those values directly correspond to entries in the function app's [application settings](https://docs.microsoft.com/azure/azure-functions/functions-how-to-use-azure-function-app-settings#settings) and we will set those to valid connection strings for the respective Event Hub.

##### Configure the connections

On the both Event Hubs, we will add (or reuse) a SAS authorization rule that is to be used to send and retrieve events. The authorization rule is created on the Event Hubs directly and specifies both 'Listen' and 'Send' permissions. The example below shows only the left side; the right side is equivalent.

> **NOTE**<br><br>
> The Azure Functions trigger for Event Hubs does not yet support role-based access control integration for managed identities.

``` azurecli
az eventhubs eventhub authorization-rule create \
                          --resource-group $USER_RESOURCE_GROUP \
                          --namespace-name $USER_LEFT_NAMESPACE_NAME \
                          --eventhub-name telemetry \
                          --name replication-sendlisten \
                          --rights {send,listen}
```

We will then [obtain the primary connection string](https://docs.microsoft.com/azure/event-hubs/event-hubs-get-connection-string) for the rule and transfer that into the application settings, here using the bash Azure Cloud Shell:

```azurecli
cxnstring = $(az eventhubs eventhub authorization-rule keys list \
                    --resource-group $USER_RESOURCE_GROUP \
                    --namespace-name $USER_LEFT_NAMESPACE_NAME \
                    --eventhub-name telemetry \
                    --name replication-sendlisten \
                    --output=json | jq -r .primaryConnectionString)
az functionapp config appsettings set --name $USER_FUNCTIONS_APP_NAME \
                    --resource-group $USER_RESOURCE_GROUP \
                    --settings "telemetry-weu-connection=$cxnstring"
```

We must also configure the name of the consumer group that is created for and used by the function. 

```azurecli
az functionapp config appsettings set --name $USER_FUNCTIONS_APP_NAME \
                    --resource-group $USER_RESOURCE_GROUP \
                    --settings "telemetry-left-consumergroup=$USER_FUNCTIONS_APP_NAME.telemetry"
```

#### Deploying the application

Replication applications are regular Azure Function applications and you can
therefore use any of the [available deployment
options](https://docs.microsoft.com/en-us/azure/azure-functions/functions-deployment-technologies).
For testing, you can also run the [application
locally](https://docs.microsoft.com/en-us/azure/azure-functions/functions-develop-local),
but with the messaging services in the cloud.

Using the Azure Functions tools, the simplest way to deploy the application is to run the Core Function Tools CLI tool from the project directory:

```azurecli
func azure functionapp publish "merge-example-weu" --force
```

### Monitoring

To learn how you can monitor your replication app, please refer to the [monitoring section](https://docs.microsoft.com/azure/azure-functions/configure-monitoring?tabs=v2) of the Azure Functions documentation.

A particularly useful visual tool for monitoring replication tasks is the Application Insights [Application Map](https://docs.microsoft.com/azure/azure-monitor/app/app-map), which is automatically generated from the captured monitoring information and allows exploring the reliability and performance of the replication task sosurce and target transfers.

For immediate diagnostic insights, you can work with the [Live Metrics](https://docs.microsoft.com/azure/azure-monitor/app/live-stream) portal tool, which provides low latency visualization of log details.