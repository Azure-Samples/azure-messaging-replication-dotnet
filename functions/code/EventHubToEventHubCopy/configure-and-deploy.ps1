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

Write-Output "Creating or updating Event Hub namespace"
$null = New-AzResourceGroupDeployment -ResourceGroupName $ResourceGroup -TemplateFile ".\template\azuredeploy.json" -NamespaceName $NamespaceName
Write-Output "Configuring Event Hub namespace and application"
& ".\Configure-Function.ps1" -TaskName Eh1ToEh2 -FunctionAppName $FunctionAppName -SourceNamespaceName $NamespaceName -SourceEventHub "eh1" -TargetNamespaceName $NamespaceName -TargetEventHub "eh2"
Write-Output "Deploying application"
func azure functionapp publish $FunctionAppName