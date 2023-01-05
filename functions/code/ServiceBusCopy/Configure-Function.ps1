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

$null = az servicebus queue authorization-rule create --resource-group $ResourceGroupName --namespace-name $SourceNamespacename --queue-name jobs-transfer --name replication-listen --rights listen
$cxnstring = $(az servicebus queue authorization-rule keys list --resource-group $ResourceGroupName --namespace-name $SourceNamespacename --queue-name jobs-transfer --name replication-listen --output=json | ConvertFrom-Json -AsHashtable).primaryConnectionString 
$null = az functionapp config appsettings set --name $FunctionAppName --resource-group $ResourceGroupName --settings "jobs-transfer-source-connection=$cxnstring"

# Configure the target

$null = az servicebus queue authorization-rule create --resource-group $ResourceGroupName --namespace-name $TargetNamespacename --queue-name "jobs" --name replication-send --rights send
$cxnstring = $(az servicebus queue authorization-rule keys list --resource-group $ResourceGroupName --namespace-name $TargetNamespacename --queue-name $TargetQueueName --name replication-send --output=json | ConvertFrom-Json -AsHashtable).primaryConnectionString
$null = az functionapp config appsettings set --name $FunctionAppName --resource-group $ResourceGroupName --settings "jobs-target-connection=$cxnstring"