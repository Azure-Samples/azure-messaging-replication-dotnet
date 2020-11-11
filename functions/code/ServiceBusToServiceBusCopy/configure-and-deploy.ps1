[CmdletBinding()]
param (
    # Name of the Functions Application
    [Parameter(Mandatory)]
    [String]
    $FunctionAppName,
    # Event Hub Respurce Group
    [Parameter(Mandatory)]
    [String]
    $ResourceGroup,
    # Event Hub Namespace
    [Parameter(Mandatory)]
    [String]
    $NamespaceName
)

Write-Host "Creating or updating Service Bus namespace"
$null = New-AzResourceGroupDeployment -ResourceGroupName $ResourceGroup -TemplateFile "$PSScriptRoot\template\azuredeploy.json" -NamespaceName $NamespaceName
Write-Host "Configuring Service Bus namespace and application"
& ".\Configure-Function.ps1" -TaskName QueueAToQueueB -FunctionAppName $FunctionAppName -SourceNamespaceName $NamespaceName -SourceQueue "queue-a" -TargetNamespaceName $NamespaceName -TargetQueue "queue-b"
Write-Host "Deploying application"
func azure functionapp publish $FunctionAppName 2>&1 > deploy.log