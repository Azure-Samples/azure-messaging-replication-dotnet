# This script is meand to be run as the validation stage of the 
# build process and under an existing Azure PowerShell context.
# This may be provided by the AzurePowerShell task in Azure Pipelines

$ErrorActionPreference = "Stop"

function Get-EventHubConnectionString  ([String] $NamespaceName, [String] $EventHubName, [bool] $UseSAS = $true) {
    if ( $UseSAS ) {
        $EventHubNamespace = $(Get-AzResource -resourcetype "Microsoft.EventHub/namespaces" -name $NamespaceName.Split('.')[0])
        $EventHubKeyInfo = $(Get-AzEventHubKey -ResourceGroupName $EventHubNamespace.ResourceGroupName -NamespaceName $EventHubNamespace.Name -EventHubName $EventHubName -AuthorizationRuleName "testapp" -ErrorAction SilentlyContinue)
        if ( -Not $EventHubKeyInfo ) {
            $null = New-AzEventHubAuthorizationRule -ResourceGroupName $EventHubNamespace.ResourceGroupName -NamespaceName $EventHubNamespace.Name -EventHubName $EventHubName -Name "testapp" -Rights "Send", "Listen"
            $EventHubKeyInfo = $(Get-AzEventHubKey -ResourceGroupName $EventHubNamespace.ResourceGroupName -NamespaceName $EventHubNamespace.Name -EventHubName $EventHubName -AuthorizationRuleName "testapp")
        }
        return $EventHubKeyInfo.PrimaryConnectionString
    }
    else {
        return "Endpoint=sb://" + $NamespaceName + "." + $NamespaceDomain + ";EntityPath=" + $EventHubName + ";Authentication='Managed Identity';"    
    }
}

function Test-ConfigApp([String] $Location, [String] $RGName) {
    
    Write-Host " - Deploy Event Hubs"
    & "$PSScriptRoot\..\functions\config\EventHubToEventHubCopy\Deploy-Resources.ps1" -ResourceGroupName $RGName -Location $Location -NamespaceName $RGName 
    
    Write-Host " - Build Project"
    & "$PSScriptRoot\..\functions\config\EventHubToEventHubCopy\Build-FunctionApp.ps1" 
    
    Write-Host " - Configure App"
    & "$PSScriptRoot\..\functions\config\EventHubToEventHubCopy\Configure-Function.ps1" -TaskName EventHubAToEventHubB -FunctionAppName $RGName -SourceNamespacename $RGName -SourceEventHubName eventHubA -TargetNamespaceName $RGname -TargetEventHubName eventHubB
    
    Write-Host " - Deploy Function"
    & "$PSScriptRoot\..\functions\config\EventHubToEventHubCopy\Deploy-FunctionApp.ps1" -FunctionAppName $RGName

    Write-Host " - Run Test"
    pushd "$PSScriptRoot\EventHubCopyValidation"
    & ".\bin\Debug\netcoreapp3.1\EventHubCopyValidation.exe" -t "$(Get-EventHubConnectionString -NamespaceName $RGName -EventHubName eventHubA -UseSAS $true)" -s "$(Get-EventHubConnectionString -NamespaceName $RGName -EventHubName eventHubB -UseSAS $true)" -et eventHubA -es eventHubB -cg '\$Default' 2>&1 >> "$PSScriptRoot\run.log"
    $result = $LastExitCode 
    popd
    return $result
}

function Test-CodeApp([String] $Location, [String] $RGName) {
    Write-Host " - Deploy Event Hubs"
    & "$PSScriptRoot\..\functions\code\EventHubToEventHubCopy\Deploy-Resources.ps1" -ResourceGroupName $RGName -Location $Location -NamespaceName $RGName 
    
    Write-Host " - Configure App"
    & "$PSScriptRoot\..\functions\code\EventHubToEventHubCopy\Configure-Function.ps1" -TaskName Eh1toEh2 -FunctionAppName $RGName -SourceNamespacename $RGName -SourceEventHubName eh1 -TargetNamespaceName $RGname -TargetEventHubName eh2
    
    Write-Host " - Deploy Function"
    & "$PSScriptRoot\..\functions\code\EventHubToEventHubCopy\Deploy-FunctionApp.ps1" -FunctionAppName $RGName

    Write-Host " - Run Test"
    pushd "$PSScriptRoot\EventHubCopyValidation"
    & ".\bin\Debug\netcoreapp3.1\EventHubCopyValidation.exe" -t "$(Get-EventHubConnectionString -NamespaceName $RGName -EventHubName "eh1" -UseSAS $true)" -s "$(Get-EventHubConnectionString -NamespaceName $RGName -EventHubName "eh2" -UseSAS $true)" -et eh1 -es eh2 -cg '\$Default' 2>&1 >> "$PSScriptRoot\run.log"
    $result = $LastExitCode 
    popd

    return $result
}

Write-Host "Building Test project"
pushd "$PSScriptRoot\EventHubCopyValidation"
dotnet build "EventHubCopyValidation.csproj" -c Debug 2>&1 > build.log
popd

Write-Host "Scenario Config/Consumption"
$RGName = "msgrepl$(Get-Date -UFormat '%s')"
$Location = "westeurope"
Write-Host " - Create App Host"
& "$PSScriptRoot\..\templates\Deploy-FunctionsConsumptionPlan.ps1" -ResourceGroupName $RGName -Location $Location
$result = Test-ConfigApp -Location $Location -RGName $RGName
Write-Host " - Undeploy App"
$null = Remove-AzResourceGroup -Name $RGname -Force

if ( $result -ne 0) {
    Write-Host "result $result"
    return $result
}

Write-Host "Scenario Config Premium/Consumption"
$RGName = "msgrepl$(Get-Date -UFormat '%s')"
$Location = "westeurope"
Write-Host " - Create App Host"
& "$PSScriptRoot\..\templates\Deploy-FunctionsPremiumPlan.ps1" -ResourceGroupName $RGName -Location $Location
$result = Test-ConfigApp -Location $Location -RGName $RGName
Write-Host " - Undeploy App"
$null = Remove-AzResourceGroup -Name $RGname -Force

if ( $result -ne 0) {
    return $result
}

Write-Host "Scenario Code/Consumption"
$RGName = "msgrepl$(Get-Date -UFormat '%s')"
$Location = "westeurope"
Write-Host " - Create App Host"
& "$PSScriptRoot\..\templates\Deploy-FunctionsConsumptionPlan.ps1" -ResourceGroupName $RGName -Location $Location
$result = Test-CodeApp -Location $Location -RGName $RGName
Write-Host " - Undeploy App"
$null = Remove-AzResourceGroup -Name $RGname -Force

if ( $result -ne 0) {
    return $result
}

Write-Host "Scenario Code/Premium"
$RGName = "msgrepl$(Get-Date -UFormat '%s')"
$Location = "westeurope"
Write-Host " - Create App Host"
& "$PSScriptRoot\..\templates\Deploy-FunctionsPremiumPlan.ps1" -ResourceGroupName $RGName -Location $Location
$result = Test-CodeApp -Location $Location -RGName $RGName
Write-Host " - Undeploy App"
$null = Remove-AzResourceGroup -Name $RGname -Force

return $result