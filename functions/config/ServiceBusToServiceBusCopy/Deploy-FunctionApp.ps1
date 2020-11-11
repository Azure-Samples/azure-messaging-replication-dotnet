[CmdletBinding()]
param (
    # Name of the replication app
    [Parameter(Mandatory)]
    [String]
    $FunctionAppName
)

pushd $PSScriptRoot

# Deploy
func azure functionapp publish $FunctionAppName --force 2>&1 >> deploy.log

popd