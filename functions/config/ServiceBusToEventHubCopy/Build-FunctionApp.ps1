
pushd $PSScriptRoot

# Build the Functions Code
if ( $(Get-ChildItem -Directory bin) ) {
    Remove-Item -Recurse bin
}
dotnet build ..\..\..\src\Azure.Messaging.Replication\Azure.Messaging.Replication.csproj -o dotnet 2>&1 > dotnet\build.log
Move-Item -Force "dotnet\bin" .    

# Sync the required extensions into the build
func extensions sync --csx
func extensions install
Remove-Item extensions.csproj

popd