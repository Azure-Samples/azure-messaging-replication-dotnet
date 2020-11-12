## Test projects

This folder contains two test scenarios

The `BuildAll.sln` project is used during check-in validation in GitHub and ensures that the code builds correctly.

The `Validate-Azure.ps1` script sets up and runs all the example applications in Azure to verify their functionality.

The script calls the documented helper scripts and to create and configure:

* Setup of Consumption and Premium Azure Functions hosts 
* Service Bus and/or Event Hub namespaces and entities
* Configuration for those entities
* Deployment of the functions application

Once a function is completely set up and configured the end-to-end test project included herein is run to ensure to run events/messages through the replication setup to verify that no messagesr are lost and that m,essages that are expected to be received in a particular order (sessions and event streams with partition keys) are indeed received in that order. 