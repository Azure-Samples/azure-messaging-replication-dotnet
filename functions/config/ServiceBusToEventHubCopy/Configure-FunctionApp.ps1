[CmdletBinding()]
param (
    # Name of the replication task
    [Parameter(Mandatory)]
    [String]
    $TaskName,
    # Name of the Functions Application
    [Parameter(Mandatory)]
    [String]
    $FunctionAppName,
    # Source Event Hub or Service Bus Namespace 
    [Parameter()]
    [String]
    $SourceNamespaceName,
    # Source Event Hub Name
    [Parameter()]
    [String]
    $SourceEventHubName,
    # Source Service Bus Queue Name
    [Parameter()]
    [String]
    $SourceQueueName,
    # Source Service Bus Topic Name
    [Parameter()]
    [String]
    $SourceTopicName,
    # Source Service Bus Topic Subscription Name
    [Parameter()]
    [String]
    $SourceSubscriptionName,
    # Target Event Hub or Service Bus Namespace 
    [Parameter(Mandatory)]
    [String]
    $TargetNamespaceName,
    # Target Event Hub Name
    [Parameter()]
    [String]
    $TargetEventHubName,
    # Target Queue Name
    [Parameter()]
    [String]
    $TargetQueueName,
    # Target Topic Name
    [Parameter()]
    [String]
    $TargetTopicName
)

& ("$PSScriptRoot\..\..\..\scripts\powershell\Update-PairingConfiguration.ps1") @args