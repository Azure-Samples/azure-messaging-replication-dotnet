# Messaging Replication Function app on the Premium plan 

[![Deploy To Azure](https://raw.githubusercontent.com/Azure/azure-quickstart-templates/master/1-CONTRIBUTION-GUIDE/images/deploytoazure.svg?sanitize=true)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fclemensv%2Fazure-messaging-replication-dotnet%2Fmaster%2Ftemplates%2Fpremium%2Fazuredeploy.json)
[![Deploy To Azure US Gov](https://raw.githubusercontent.com/Azure/azure-quickstart-templates/master/1-CONTRIBUTION-GUIDE/images/deploytoazuregov.svg?sanitize=true)](https://portal.azure.us/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fclemensv%2Fazure-messaging-replication-dotnet%2Fmaster%2Ftemplates%2Fpremium%2Fazuredeploy.json)
[![Visualize](https://raw.githubusercontent.com/Azure/azure-quickstart-templates/master/1-CONTRIBUTION-GUIDE/images/visualizebutton.svg?sanitize=true)](http://armviz.io/#/?load=https%3A%2F%2Fraw.githubusercontent.com%2Fclemensv%2Fazure-messaging-replication-dotnet%2Fmaster%2Ftemplates%2Fpremium%2Fazuredeploy.json)

Azure Functions is a solution for running small pieces of code, or functions, in the cloud. You can write just the code you need for the problem at hand, without worrying about a whole application or the infrastructure to run it.

For more information about Azure Functions, see the following articles:

- [Azure Functions Overview](https://azure.microsoft.com/documentation/articles/functions-overview/)
- [Quickstart: Create and deploy Azure Functions resources from an ARM template](https://docs.microsoft.com/azure/azure-functions/functions-create-first-function-resource-manager)


## Overview and deployed resources

The following resources are deployed as part of the solution:

### Azure Function Premium Plan

The [Azure Functions Premium plan](https://docs.microsoft.com/azure/azure-functions/functions-premium-plan) which enables virtual network integration.

+ **Microsoft.Web/serverfarms**: The Azure Functions Premium plan (a.k.a. Elastic Premium plan)

### Function App

The function app to be deployed as part of the Azure Functions Premium plan.

+ **Microsoft.Web/sites**: The function app instance.

### Application Insights

Application Insights is used to provide [monitoring for the Azure Function](https://docs.microsoft.com/azure/azure-functions/functions-monitoring).

+ **Microsoft.Insights/components**: The Application Insights instance used by the Azure Function for monitoring.

### Azure Storage

The Azure Storage account used by the Azure Function.

+ **Microsoft.Storage/storageAccounts**: [Azure Functions requires a storage account](https://docs.microsoft.com/azure/azure-functions/storage-considerations) for the function app instance.

## Deployment steps

You can click the "deploy to Azure" button at the beginning of this document or follow the instructions for command line deployment using the scripts in the root of this repo.
