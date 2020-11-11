[CmdletBinding()]
param (
    # Service Bus Namespace
    [Parameter()]
    [String]
    $NamespaceName
)

$ServiceBusNamespace = $(Get-AzResource -resourcetype "Microsoft.ServiceBus/namespaces" -name $NamespaceName.Split('.')[0])
if ( -not $ServiceBusNamespace ) {
    throw "The Service Bus $NamespaceName does not exist."
}
if ( Remove-AzServiceBusNamespace -Name $ServiceBusNamespace.Name -ResourceGroupName $ServiceBusNamespace.ResourceGroupName -PassThru ) {
    Write-Host "Removing the Service Bus namespace will take a few moments to take effect"
} else {
    throw "Removing the Service Bus namespace failed."
}