[CmdletBinding()]
param (
    # Name of the replication app
    [Parameter(Mandatory)]
    [String]
    $FunctionAppName
)

# Deploy
func azure functionapp publish $FunctionAppName --force