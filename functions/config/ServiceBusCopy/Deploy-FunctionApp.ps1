[CmdletBinding()]
param (
    # Name of the Azure Function App
    [Parameter(Mandatory)]
    [String]
    $FunctionAppName
)

pushd "$PSScriptRoot" > $null
$null = func azure functionapp publish "$FunctionAppName" --force
popd > $null