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
    $SourceNamespacename,
    # Name of the source Event Hub
    [Parameter(Mandatory)]
    [String]
    $SourceEventHubName,
    # Target Event Hubs Namespace
    [Parameter(Mandatory)]
    [String]
    $TargetNamespacename,
    # Name of the target Event Hub
    [Parameter(Mandatory)]
    [String]
    $TargetEventHubName
)

# Configure the source

$null = az eventhubs eventhub authorization-rule create --resource-group $ResourceGroupName --namespace-name $SourceNamespacename --eventhub-name "telemetry" --name "replication-listen" --rights Listen
$cxnstring = $(az eventhubs eventhub authorization-rule keys list --resource-group $ResourceGroupName --namespace-name $SourceNamespacename --eventhub-name "telemetry" --name "replication-listen" --output=json | ConvertFrom-Json -AsHashtable).primaryConnectionString
$null = az functionapp config appsettings set --name $FunctionAppName --resource-group $ResourceGroupName --settings "telemetry-source-connection=$cxnstring"
$null = az functionapp config appsettings set --name $FunctionAppName --resource-group $ResourceGroupName --settings "telemetry-source-consumergroup=$FunctionAppName.telemetry"

# Configure the target

$null = az eventhubs eventhub authorization-rule create --resource-group $ResourceGroupName --namespace-name $TargetNamespacename --eventhub-name "telemetry" --name replication-send --rights Send
$cxnstring = $(az eventhubs eventhub authorization-rule keys list --resource-group $ResourceGroupName --namespace-name $TargetNamespacename --eventhub-name "telemetry" --name replication-send --output=json | ConvertFrom-Json -AsHashtable ).primaryConnectionString
$null = az functionapp config appsettings set --name $FunctionAppName --resource-group $ResourceGroupName --settings "telemetry-target-connection=$cxnstring"