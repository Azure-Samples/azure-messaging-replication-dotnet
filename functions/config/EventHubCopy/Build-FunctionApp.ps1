# Build the Functions Code
pushd $PSScriptRoot > $null

if ( $(Get-ChildItem -Directory bin -ErrorAction SilentlyContinue) ) {
    Remove-Item -Recurse bin
}
dotnet build "..\..\..\src\Azure.Messaging.Replication\Azure.Messaging.Replication.csproj" -o dotnet 2>&1 > build.log
Move-Item -Force "dotnet\bin" .    

# Sync the required extensions into the build
func extensions sync --csx 2>&1 >> build.log
func extensions install 2>&1 >> build.log
Remove-Item extensions.csproj 2>&1 >> build.log

popd > $null
