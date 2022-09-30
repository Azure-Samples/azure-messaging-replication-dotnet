[CmdletBinding()]
param (
    # Name of the Azure Resource Group to deploy to
    [Parameter(Mandatory)]
    [String]
    $ResourceGroupName,
    # Azure Location
    [Parameter(Mandatory)]
    [String]
    $Location,
    # Name of the Namespace
    [Parameter(Mandatory)]
    [String]
    $NamespaceName,
    # Name of the Functions App
    [Parameter(Mandatory)]
    [String]
    $FunctionAppName
)

$null = New-AzResourceGroupDeployment -ResourceGroupName $ResourceGroupName -Location $Location -functionsAppName $FunctionAppName -TemplateFile "$PSScriptRoot\template\azuredeploy.json"