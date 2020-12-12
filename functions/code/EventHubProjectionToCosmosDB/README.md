## Event Hub To Cosmos DB (C#)

This project illustrates how to build and deploy a simple copy replication
function that project data from an Event Hub into Cosmos DB.

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

The [log projection](https://docs.microsoft.com/azure/event-hubs/event-hubs-federation-patterns#log-projection)
patterns can be implemented with this project.

### Monitoring

To learn how you can monitor your replication app, please refer to the [monitoring section](https://docs.microsoft.com/azure/azure-functions/configure-monitoring?tabs=v2) of the Azure Functions documentation.

A particularly useful visual tool for monitoring replication tasks is the Application Insights [Application Map](https://docs.microsoft.com/azure/azure-monitor/app/app-map), which is automatically generated from the captured monitoring information and allows exploring the reliability and performance of the replication task sosurce and target transfers.

For immediate diagnostic insights, you can work with the [Live Metrics](https://docs.microsoft.com/azure/azure-monitor/app/live-stream) portal tool, which provides low latency visualization of log details.