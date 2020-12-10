## Service Bus All-Active (C#)

This project illustrates how to build and deploy a replication function that
bi-directionally mirrors copies of messages sent to alternative Service Bus
topics (each acting as a queue) that reside in different namespaces.

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

### Replication topology

For configuring and running this replication function, you need two identically
configured Service Bus topics in different namespaces. The namespaces may be
located in different Azure regions.

Since we are replicating bi-directionally, we will refer to the namespaces and
topics as *left* and *right*.

In Service Bus, replication will not copy messages, but move messages from
source and target, with the moved messages being deleted from the source. 

To create mirrored queues where a second queue contains copies of the messages
sent into the primary queue, the primary queue needs to be a topic where a
'main' subscription acts like the queue endpoint for the application, and a
'replication' subscription gets copies of messages that are being replicated.

This example covers bi-directional replication between two such topics. All
messages sent to either topic will also become available on the respective other
topic's 'main' subscription. 

> **NOTE**
>
> Messages that have been consumed and deleted from one of the 'main' topic
> subscriptions will not be removed from the other, meaning that this pattern
> does not preserve competing consumer semantics. This pattern is suitable for
> scenarios where data is being shared out into multiple regions or if redundant
> processing is generally desired. It is also suitable for scenarios that can
> detect and ignore duplicates and where even brief availability issues
> lasting several seconds to a few minutes can cause substantial business
> disruptions: passengers cannot board a train or flight, spectators cannot enter
> a venue or stadium, in-person payments cannot be processed.

The following diagram shows an exemplary topology with a suggested convention
for naming the various elements. Here, the replication function name reflects
the name of the Service Bus queue it copies from source to target.


```markdown
      Source Topic               Replication App              Target Topic
+-------------------------+ +-------------------------+  +-----------------------+              
| Namespace (West Europe) | |      Function App       |  | Namespace (East US 2) |
|  "example-sb-weu"       | | "repl-example-weu-eus2" |  |  "example-sb-eus2"    |
|                         | |                         |  |                       |
| +-----------------+     | |  +-----------------+    |  |   +-----------------+ |
  |                 |          |    Function     |           |                 |
  |   Service Bus   |   +------|   "jobsLeft"    |----->-----|  Service Bus    | 
  |      Topic      |   |      +-----------------+           |     Topic       |
  |      "jobs"     |---C-<-+                                |     "jobs"      |
  | +-----+ +-----+ |   |   |  +-----------------+           | +-----+ +-----+ |
  +-|     |-|     |-+   |   |  |    Function     |           +-|     |-|     |-+
    | main| |repl |-->--+   +--|   "jobsRight"   |-----<-------| repl| |main |
    +-----+ +-----+            +-----------------+             +-----+ +-----+ 
       |                                                                  |
       V                                                                  V
```

#### Exemplary topology

For convenience, the project contains an [ARM
template](https://docs.microsoft.com/azure/event-hubs/event-hubs-resource-manager-namespace-event-hub)
in the [template folder](template) that allows you to quickly deploy an
exemplary topology inside a single Service Bus namespace to try things out. The
general assumption is that you already have a topology in place.

To make it easier to deal with the various scripts below, let's start with
setting up a few script variables (Azure Cloud Shell, Bash) defining the names
of the resources we will set up. You will have to define your own unique names
for all variables prefixed with 'USER_'.

```bash
AZURE_LOCATION=westeurope
USER_RESOURCE_GROUP=example-sb-weu
USER_SB_NAMESPACE_NAME=example-sb-weu
USER_FUNCTIONS_APP_NAME=example-sb-weu
USER_STORAGE_ACCOUNT=examplesbweu
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
                           --parameters NamespaceName='$USER_SB_NAMESPACE_NAME' \
                                        FunctionAppName='$USER_FUNCTIONS_APP_NAME' 
```

The created Service Bus queues are named "jobs-transfer" and "jobs". The name of
the consumer group created on "telemetry" is prefixed with the function app
name, e.g. "repl-example-weu.telemetry"

### Building, Configuring, and Deploying the Replication App

Leaning on the naming conventions of the exemplary topology, the project
implements two replication tasks named "jobsLeft" and "jobsRight" that perform
the replication is the respective direction.

You will find the functions in the [Tasks.cs](Tasks.cs) file. 

> **IMPORTANT:**<br><br> 
> The attribute-driven configuration model for Azure Functions written in C# and
> Java requires that you modify the names of the target and source Event Hubs and
> the source consumer group in the attribute values to fit your topology names.

```csharp
[FunctionName("jobs")]
[ExponentialBackoffRetry(-1, "00:00:05", "00:05:00")]
public static Task Jobs(
    [ServiceBusTrigger(TopicName = "jobs", SubscriptionName = "repl", Connection = "jobs-source-connection")] Message[] input,
    [ServiceBus("jobs", Connection = "jobs-target-connection")] IAsyncCollector<Message> output,
    ILogger log)
{
    return ServiceBusReplicationTasks.ForwardToServiceBus(input, output, log);
}
```

The `Connection` attribute values refer to the name of configuration entries in the
application settings of the Functions application. The [setup](#setup) step below
explains how to set those.

The code calls the pre-built helper method
`EventHubReplicationTasks.ForwardToEventHub` from the
[`Azure.Messaging.Replication`](/src/Azure.Messaging.Replication/) project which
also resides in this repository. The method copies the events from the source
batch to the given Event Hub client while preserving the [correct order for each stream](https://docs.microsoft.com/azure/event-hubs/event-hubs-federation-patterns#service-assigned-metadata) and [adding annotations for service-assigned metadata](https://docs.microsoft.com/azure/event-hubs/event-hubs-federation-patterns#streams-and-order-preservation).

The alternative `EventHubReplicationTasks.ConditionalForwardToEventHub` method
allows the application to pass a factory callback of type
`Func<EventData,EventData>`. The callback can suppress forwarding of a specific
event by returning `null` and therefore act as a filter. The callback can also
drop information from the event (reduce) or add information to it (enrich), and
it can transcode or transform the payload.

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

The task above has two attribute `Connection` property values:

- On the trigger attribute, there's a "jobs-source-connection" value:<br>
  `[ServiceBusTrigger(TopicName = "jobs", SubscriptionName = "repl", Connection = "jobs-source-connection")]`
- On the output binding attribute, there's a "jobs-target-connection" value:<br>
  `[EventHub("jobs", Connection = "jobs-target-connection")]`

Those values directly correspond to entries in the function app's [application settings](https://docs.microsoft.com/azure/azure-functions/functions-how-to-use-azure-function-app-settings#settings) and we will set those to valid connection strings for the respective Event Hub.

##### Configure the connections

On the source Event Hub, we will add (or reuse) a SAS authorization rule that is to be used to retrieve messages from the Event Hub. The authorization rule is created on the source Event Hub directly and limited to the 'Listen' permission.

> **NOTE**<br><br>
> The Azure Functions trigger for Event Hubs does not yet support role-based access control integration for managed identities.

``` azurecli
az servicebus topic authorization-rule create \
                          --resource-group $USER_RESOURCE_GROUP \
                          --namespace-name $USER_SB_NAMESPACE_NAME \
                          --topic-name jobs \
                          --name replication-listen \
                          --rights listen
```

We will then [obtain the primary connection string](https://docs.microsoft.com/azure/event-hubs/event-hubs-get-connection-string) for the rule and transfer that into the application settings, here using the bash Azure Cloud Shell:

```azurecli
cxnstring = $(az servicebus topic authorization-rule keys list \
                    --resource-group $USER_RESOURCE_GROUP \
                    --namespace-name $USER_SB_NAMESPACE_NAME \
                    --topic-name jobs \
                    --name replication-listen \
                    --output=json | jq -r .primaryConnectionString)
az functionapp config appsettings set --name $USER_FUNCTIONS_APP_NAME \
                    --resource-group $USER_RESOURCE_GROUP \
                    --settings "jobs-source-connection=$cxnstring"
```

#### Configure the target

Configuring the target is very similar, but you will create or reuse a SAS rule that grants "Send" permission:

``` azurecli
az servicebus topic authorization-rule create \
                          --resource-group $USER_RESOURCE_GROUP \
                          --namespace-name $USER_SB_NAMESPACE_NAME \
                          --topic-name jobs \
                          --name replication-send \
                          --rights send
```

We will then again [obtain the primary connection string](https://docs.microsoft.com/azure/event-hubs/event-hubs-get-connection-string) for the rule and transfer that into the application settings:

```azurecli
cxnstring = $(az servicebus topic authorization-rule keys list \
                    --resource-group $USER_RESOURCE_NAME \
                    --namespace-name $USER_SB_NAMESPACE_NAME \
                    --topic-name jobs \
                    --name replication-send \
                    --output=json | jq -r .primaryConnectionString)
az functionapp config appsettings set --name $USER_FUNCTIONS_APP_NAME \
                    --resource-group example-eh \
                    --settings "jobs-target-connection=$cxnstring"
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
func azure functionapp publish $USER_FUNCTIONS_APP_NAME --force
```

### Monitoring

To learn how you can monitor your replication app, please refer to the [monitoring section](https://docs.microsoft.com/azure/azure-functions/configure-monitoring?tabs=v2) of the Azure Functions documentation.

A particularly useful visual tool for monitoring replication tasks is the Application Insights [Application Map](https://docs.microsoft.com/azure/azure-monitor/app/app-map), which is automatically generated from the captured monitoring information and allows exploring the reliability and performance of the replication task sosurce and target transfers.

For immediate diagnostic insights, you can work with the [Live Metrics](https://docs.microsoft.com/azure/azure-monitor/app/live-stream) portal tool, which provides low latency visualization of log details.