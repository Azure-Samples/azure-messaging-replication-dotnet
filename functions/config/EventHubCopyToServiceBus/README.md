## Event Hub to Event Hub Copy (Configuration)

This project illustrates how to configure and deploy a copy replication function
that moves data between two Azure Event Hubs without you having to write or
modify any code.

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
              Source Event Hub                              Replication App              Target Event Hub
+-----------------------------------------------------+ +-------------------------+  +-----------------------+              
|             Namespace (West Europe)                 | |      Function App       |  | Namespace (East US 2) |
|               "example-eh-weu"                      | | "repl-example-weu-eus2" |  |  "example-eh-eus2"    |
|                                                     | |                         |  |                       |
| +-------------+                                     | |      +-------------+    |  |   +---------------+   |
  |             +-----------------------------------+          | Replication |           |               |
  |  Event Hub  |     Consumer Group                |          |  Function   |           |   Event Hub   | 
  |             | "repl-example-weu-eus2.telemetry" |---->-----|             |----->-----|               |
  | "telemetry" |                                   |          | "telemetry" |           |  "telemetry"  |
  |             +-----------------------------------+          |             |           |               |
  +-------------+                                              +-------------+           +---------------+
```

#### Exemplary topology

For convenience, the project contains an [ARM
template](https://docs.microsoft.com/azure/event-hubs/event-hubs-resource-manager-namespace-event-hub)
in the [template folder](template) that allows you to quickly deploy an
exemplary topology inside a single Event Hub namespace to try things out. The
general assumption is that you already have a topology in place.

You can deploy the template as follows, replacing the exemplary resource group
and namespace names to make them unique and choosing your preferred region.

First, if you have not done so, log into your account:

```azurecli
az login
```

The [az login](/cli/azure/reference-index#az_login) command signs you into your Azure account.

```azurecli
az group create --location "westeurope" --name "example-eh"
az deployment group create --resource-group "example-eh" \
                           --template-file "template\azuredeploy.json" \
                           --parameters NamespaceName='example-eh-weu' \
                                        FunctionAppName='repl-example-weu' 
```

The created Event Hubs are named "telemetry" and "telemetry-copy". The name of
the consumer group created on "telemetry" is prefixed with the function app
name, e.g. "repl-example-weu.telemetry"

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
            "name": "input" 
        },
        {
            "direction": "out",
            "type": "eventHub",
            "connection": "telemetry-target-connection",
            "eventHubName": "telemetry-copy",
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
    "entryPoint": "Azure.Messaging.Replication.EventHubReplicationTasks.ForwardToEventHub"
}
```

The `connection` values refer to the name of configuration entries in the
application settings of the Functions application. The [setup](#setup) step below
explains how to set those.

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
    az group create --name example-eh --location westeurope
    ```
    
    The [az group create](/cli/azure/group#az_group_create) command creates a resource group. You generally create your resource group and resources in a region near you, using an available region returned from the `az account list-locations` command.

    
3. Create a general-purpose storage account in your resource group and region:

    ```azurecli
    az storage account create --name <STORAGE_NAME> --location westeurope --resource-group example-eh --sku Standard_LRS
    ```

    The [az storage account create](/cli/azure/storage/account#az_storage_account_create) command creates the storage account. The storage account is required for Azure Functions to manage its internal state and is also used to keep the checkpoints for the source Event Hubs.

    Replace `<STORAGE_NAME>` with a name that is appropriate to you and unique in Azure Storage. Names must contain three to 24 characters numbers and lowercase letters only. `Standard_LRS` specifies a general-purpose account, which is [supported by Functions](../articles/azure-functions/storage-considerations.md#storage-account-requirements).


4. Create an Azure Functions app 
        
    ```azurecli
    az functionapp create --resource-group example-eh --consumption-plan-location westeurope --runtime dotnet --functions-version 3 --name <APP_NAME> --storage-account <STORAGE_NAME>
    ```
    The [az functionapp create](/cli/azure/functionapp#az_functionapp_create) command creates the function app in Azure. 
    
    Replace `<STORAGE_NAME>` with the name of the account you used in the previous step, and replace `<APP_NAME>` with a globally unique name appropriate to you. The `<APP_NAME>` is also the default DNS domain for the function app. 
    
    This command creates a function app running in your specified language runtime under the [Azure Functions Consumption Plan](functions-scale.md#consumption-plan), which is free for the amount of usage you incur here. The command also provisions an associated Azure Application Insights instance in the same resource group, with which you can monitor your function app and view logs. For more information, see [Monitor Azure Functions](functions-monitoring.md). The instance incurs no costs until you activate it.

#### Configure the Function App

The task above has two `connection` property values. Those values directly correspond to entries in the function app's [application settings](https://docs.microsoft.com/azure/azure-functions/functions-how-to-use-azure-function-app-settings#settings) and we will set those to valid connection strings for the respective Event Hub.

##### Configure the source

On the source Event Hub, we will add (or reuse) a SAS authorization rule that is to be used to retrieve messages from the Event Hub. The authorization rule is created on the source Event Hub directly and limited to the 'Listen' permission.
> **NOTE**<br><br>
> The Azure Functions trigger for Event Hubs does not yet support roled-based access control integration for managed identities.

``` azurecli
az eventhubs eventhub authorization-rule create \
                          --resource-group example-eh \
                          --namespace-name example-eh-weu \
                          --eventhub-name telemetry \
                          --name replication-listen \
                          --rights listen
```

We will then [obtain the primary connection string](https://docs.microsoft.com/azure/event-hubs/event-hubs-get-connection-string) for the rule and transfer that into the application settings, here using the bash Azure Cloud Shell:

```azurecli
cxnstring = $(az eventhubs eventhub authorization-rule keys list \
                    --resource-group example-eh \
                    --namespace-name example-eh-weu \
                    --eventhub-name telemetry \
                    --name replication-listen \
                    --output=json | jq -r .primaryConnectionString)
az functionapp config appsettings set --name repl-example-weu \
                    --resource-group example-eh \
                    --settings "telemetry-source-connection=$cxnstring"
```

#### Configure the target

Configuring the target is very similar, but you will create or reuse a SAS rule that grants "Send" permission:

``` azurecli
az eventhubs eventhub authorization-rule create \
                          --resource-group example-eh \
                          --namespace-name example-eh-weu \
                          --eventhub-name telemetry-copy \
                          --name replication-send \
                          --rights send
```

We will then again [obtain the primary connection string](https://docs.microsoft.com/azure/event-hubs/event-hubs-get-connection-string) for the rule and transfer that into the application settings:

```azurecli
cxnstring = $(az eventhubs eventhub authorization-rule keys list \
                    --resource-group example-eh \
                    --namespace-name example-eh-weu \
                    --eventhub-name telemetry-copy \
                    --name replication-send \
                    --output=json | jq -r .primaryConnectionString)
az functionapp config appsettings set --name repl-example-weu \
                    --resource-group example-eh \
                    --settings "telemetry-target-connection=$cxnstring"
```

#### Deploying the application

Configuration-based applications still require putting a deployment package together.

To build the project, run

- PowerShell: `Build-FunctionApp.ps1`
- Bash: `build_functionapp.sh`

Once you've built the project, you deploy the entire project directory as an application.

Replication applications are regular Azure Function applications and you can
therefore use any of the [available deployment
options](https://docs.microsoft.com/en-us/azure/azure-functions/functions-deployment-technologies).
For testing, you can also run the [application
locally](https://docs.microsoft.com/en-us/azure/azure-functions/functions-develop-local),
but with the messaging services in the cloud.

Using the Azure Functions tools, the simplest way to deploy the application is to run the Core Function Tools CLI trool from ther project directory:

```azurecli
func azure functionapp publish "repl-example-weu" --force
```

### Monitoring

To learn how you can monitor your replication app, please refer to the [monitoring section](https://docs.microsoft.com/azure/azure-functions/configure-monitoring?tabs=v2) of the Azure Functions documentation.

A particularly useful visual tool for monitoring replication tasks is the Application Insights [Application Map](https://docs.microsoft.com/azure/azure-monitor/app/app-map), which is automatically generated from the captured monitoring information and allows exploring the reliability and performance of the replication task sosurce and target transfers.

For immediate diagnostic insights, you can work with the [Live Metrics](https://docs.microsoft.com/azure/azure-monitor/app/live-stream) portal tool, which provides low latency visualization of log details.