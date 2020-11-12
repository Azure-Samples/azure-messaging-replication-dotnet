[CmdletBinding()]
param (
    # Name of the resouce group
    [Parameter(Mandatory)]
    [String]
    $ResourceGroupName,
    # Deployment location
    [Parameter(Mandatory)]
    [String]
    $Location,
    # Service Bus Namespace
    [Parameter()]
    [String]
    $NamespaceName
)

if ( -not $(Get-AzResourceGroup -Name $ResourceGroupName) ) { 
   $null = New-AzResourceGroup -Name $ResourceGroupName -Location $Location 
}
$null = New-AzResourceGroupDeployment -ResourceGroupName $ResourceGroupName -TemplateFile "$PSScriptRoot\template\azuredeploy.json" -ServiceBusNamespaceName $NamespaceName -ServiceBusQueueName1 "queueA" -ServiceBusQueueName2 "queueB"

