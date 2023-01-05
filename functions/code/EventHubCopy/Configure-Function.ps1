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

$null = az eventhubs eventhub authorization-rule create --resource-group $ResourceGroupName --namespace-name $SourceNamespacename --eventhub-name $SourceEventHubName --name replication-listen --rights listen

$cxnstringsource = $(az eventhubs eventhub authorization-rule keys list --resource-group $ResourceGroupName --namespace-name $SourceNamespacename --eventhub-name $SourceEventHubName --name replication-listen --output=json | ConvertFrom-Json -AsHashtable).primaryConnectionString
	
$null = az functionapp config appsettings set --name $FunctionAppName --resource-group $ResourceGroupName --settings "$SourceEventHubName-source-connection=$cxnstringsource"

$null = az functionapp config appsettings set --name $FunctionAppName --resource-group $ResourceGroupName --settings "telemetry-source-consumergroup=$FunctionAppName.telemetry"

$null = az eventhubs eventhub authorization-rule create --resource-group $ResourceGroupName --namespace-name $TargetNamespacename --eventhub-name $TargetEventHubName --name replication-send --rights send

$cxnstringtarget = $(az eventhubs eventhub authorization-rule keys list --resource-group $ResourceGroupName --namespace-name $TargetNamespacename --eventhub-name $TargetEventHubName --name replication-send --output=json | ConvertFrom-Json -AsHashtable).primaryConnectionString

$null = az functionapp config appsettings set --name $FunctionAppName --resource-group $ResourceGroupName --settings "$TargetEventHubName-target-connection=$cxnstringtarget"