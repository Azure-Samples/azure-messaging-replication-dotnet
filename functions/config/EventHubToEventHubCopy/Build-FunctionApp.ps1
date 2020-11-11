# Build the Functions Code
pushd $PSScriptRoot

if ( $(Get-ChildItem -Directory bin) ) {
    Remove-Item -Recurse bin
}
dotnet build "..\..\..\src\Azure.Messaging.Replication\Azure.Messaging.Replication.csproj" -o dotnet 2>&1 > dotnet\build.log
Move-Item -Force "dotnet\bin" .    

# Sync the required extensions into the build
func extensions sync --csx 2>&1 >> dotnet\build.log
func extensions install 2>&1 >> dotnet\build.log
Remove-Item extensions.csproj 2>&1 >> dotnet\build.log

popd