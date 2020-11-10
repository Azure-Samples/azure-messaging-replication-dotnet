[CmdletBinding()]
param (
    # Name of the Azure Resource Group to create
    [Parameter(Mandatory)]
    [String]
    $ResourceGroupName,
    # Azure Location
    [Parameter(Mandatory)]
    [String]
    $Location
)


New-AzResourceGroup -Name $ResourceGroupName -Location $Location
New-AzResourceGroupDeployment -ResourceGroupName $ResourceGroupName -Location $Location -TemplateParameterFile "$PSScriptRoot\consumption\azuredeploy.parameters.json" -TemplateFile "$PSScriptRoot\consumption\azuredeploy.json"