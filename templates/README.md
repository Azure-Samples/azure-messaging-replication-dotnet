## Setup scripts and Azure Resource Manager Templates

The Powershell scripts in this folder and the Azure Resource manager templates
in the sub-folders help creating an Azure Functions environment for hosting
replication tasks. 

All scripts create a new Azure resource group in a given location and then
create an Azure Functions application along with further resources required to
run and manage a replication application.

The application configuration and code is deployed into these application
environments based on the projects from the parallel [functions](../functions) folder.

It's recommended to run replication tasks in an Azure region with [Application
Insights
support](https://azure.microsoft.com/en-us/global-infrastructure/services/?products=monitor)
and the scripts assume this.

The scripts use the latest Azure Powershell modules and assume that you are [logged in](https://docs.microsoft.com/powershell/azure/authenticate-azureps) and have selected an [active subscription](https://docs.microsoft.com/powershell/azure/manage-subscriptions-azureps) in case you have multiple.

### Deploy-FunctionsConsumptionPlan.ps1

```powershell
Deploy-FunctionsConsumptionPlan
   [-ResourceGroupName] <String>
   [-Location] <String>
```

Creates a new Azure resource group, an Azure storage account, an [Azure Function app using the consumption plan](https://docs.microsoft.com/en-us/azure/azure-functions/functions-scale#consumption-plan), a new system managed identity associated with
the Azure Function app, and enables Azure Monitor Application Insights.

The storage account and the function application will use the same name as the resource group.

### Deploy-FunctionsPremiumPlan.ps1

```powershell
Deploy-FunctionsPremiumPlan
   [-ResourceGroupName] <String>
   [-Location] <String>
```

Creates a new Azure resource group, an Azure storage account, an Azure Function
app using the [Azure Functions Premium Plan (EP1)](https://docs.microsoft.com/en-us/azure/azure-functions/functions-premium-plan),
a new system managed identity associated with the Azure Function app, and
enables Azure Monitor Application Insights.

The storage account and the function application will use the same name as the resource group.

### Deploy-FunctionsPremiumPlanVNet.ps1

```powershell
Deploy-FunctionsPremiumPlan
   [-ResourceGroupName] <String>
   [-Location] <String>
```

Creates a new Azure resource group, an Azure storage account, an Azure Function
app using the [Azure Functions Premium Plan (EP1)](https://docs.microsoft.com/en-us/azure/azure-functions/functions-premium-plan) with VNet integration, a new
system managed identity associated with the Azure Function app, and enables
Azure Monitor Application Insights.

The storage account and the function application will use the same name as the resource group.

Edit the [azuredeploy.parameters.json](premium-vnet/azuredeploy.parameters.json)
file to change the names of the virtual network.

## Azure Resource Manager Templates

* [Consumption Plan](consumption) - Consumption plan deployment
* [Premium Plan](premium) - Premium plan deployment
* [Premium Plan with VNet](premium-vnet) - Premium plan with VNet deployment
