# Build the Functions Code
if ( -not $(Get-ChildItem -Directory bin) ) {
    Remove-Item -Recurse bin
}
dotnet build ..\..\..\src\Azure.Messaging.Replication\Azure.Messaging.Replication.csproj -o dotnet
Move-Item dotnet\bin .    

# Sync the required extensions into the build
func extensions sync --csx
func extensions install
Remove-Item extensions.csproj