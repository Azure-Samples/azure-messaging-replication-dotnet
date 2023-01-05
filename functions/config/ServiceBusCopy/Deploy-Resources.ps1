[CmdletBinding()]
param (
    # Name of the Azure Resource Group to deploy to
    [Parameter(Mandatory)]
    [String]
    $ResourceGroupName,
    # Azure Location
    [Parameter(Mandatory)]
    [String]
    $Location
)

$null = New-AzResourceGroupDeployment -ResourceGroupName $ResourceGroupName -Location $Location -TemplateFile "$PSScriptRoot\template\azuredeploy.json"