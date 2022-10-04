[CmdletBinding()]
param (
    # Name of the Function App
    [Parameter(Mandatory)]
    [String]
    $FunctionAppName,
    # Name of the Resource Group
    [Parameter(Mandatory)]
    [String]
    $ResourceGroupName,
    # Source Event Hubs Namespace
    [Parameter(Mandatory)]
    [String]
    $LeftNamespacename,
    # Name of the source Event Hub
    [Parameter(Mandatory)]
    [String]
    $LeftEventHubName,
    # Target Event Hubs Namespace
    [Parameter(Mandatory)]
    [String]
    $RightNamespacename,
    # Name of the target Event Hub
    [Parameter(Mandatory)]
    [String]
    $RightEventHubName
)

# Left Event Hub

$null = az eventhubs eventhub authorization-rule create --resource-group $ResourceGroupName --namespace-name $LeftNamespacename --eventhub-name $LeftEventHubName --name replication-sendlisten --rights Send Listen
$cxnstringleft = $(az eventhubs eventhub authorization-rule keys list --resource-group $ResourceGroupName --namespace-name $LeftNamespacename --eventhub-name $LeftEventHubName --name replication-sendlisten --output=json | ConvertFrom-Json -AsHashtable).primaryConnectionString
$null = az functionapp config appsettings set --name $FunctionAppName --resource-group $ResourceGroupName --settings "$LeftEventHubName-left-connection=$cxnstringleft"
$null = az functionapp config appsettings set --name $FunctionAppName --resource-group $ResourceGroupName --settings "telemetry-left-consumergroup=$FunctionAppName.telemetry"

# Right Event Hub

$null = az eventhubs eventhub authorization-rule create --resource-group $ResourceGroupName --namespace-name $RightNamespacename --eventhub-name $RightEventHubName --name replication-sendlisten --rights Send Listen
$cxnstringleft = $(az eventhubs eventhub authorization-rule keys list --resource-group $ResourceGroupName --namespace-name $RightNamespacename --eventhub-name $RightEventHubName --name replication-sendlisten --output=json | ConvertFrom-Json -AsHashtable).primaryConnectionString
$null = az functionapp config appsettings set --name $FunctionAppName --resource-group $ResourceGroupName --settings "$RightEventHubName-right-connection=$cxnstringleft"
$null = az functionapp config appsettings set --name $FunctionAppName --resource-group $ResourceGroupName --settings "telemetry-right-consumergroup=$FunctionAppName.telemetry"