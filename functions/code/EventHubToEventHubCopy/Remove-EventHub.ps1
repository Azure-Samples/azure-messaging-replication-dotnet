[CmdletBinding()]
param (
    # Event Hub Namespace
    [Parameter()]
    [String]
    $NamespaceName
)

$EventHubNamespace = $(Get-AzResource -resourcetype "Microsoft.EventHub/namespaces" -name $NamespaceName.Split('.')[0])
if ( -not $EventHubNamespace ) {
    throw "The Event Hub $NamespaceName does not exist."
}
if ( Remove-AzEventHubNamespace -Name $EventHubNamespace.Name -ResourceGroupName $EventHubNamespace.ResourceGroupName -PassThru ) {
    Write-Output "Removing the Event Hub will take a few moments to take effect"
} else {
    throw "Removing the Event Hub failed."
}