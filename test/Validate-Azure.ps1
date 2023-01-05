# This script is meant to be run as the validation stage of the 
# build process and under an existing Azure PowerShell context.
# This may be provided by the AzurePowerShell task in Azure Pipelines

#exit  0

"========== TEST RUN AT : $(Get-Date) ==========" > "$PSScriptRoot\run.log"

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

function Get-ServiceBusConnectionString  ([String] $NamespaceName, [String] $QueueName, [bool] $UseSAS = $true) {
    if ( $UseSAS ) {
        $ServiceBusNamespace = $(Get-AzResource -resourcetype "Microsoft.ServiceBus/namespaces" -name $NamespaceName.Split('.')[0])
        $ServiceBusKeyInfo = $(Get-AzServiceBusKey -ResourceGroupName $ServiceBusNamespace.ResourceGroupName -NamespaceName $ServiceBusNamespace.Name -Queue $QueueName -AuthorizationRuleName "testapp" -ErrorAction SilentlyContinue)
        if ( -Not $ServiceBusKeyInfo ) {
            $null = New-AzServiceBusAuthorizationRule -ResourceGroupName $ServiceBusNamespace.ResourceGroupName -NamespaceName $ServiceBusNamespace.Name -Queue $QueueName -Name "testapp" -Rights "Send", "Listen"
            $ServiceBusKeyInfo = $(Get-AzServiceBusKey -ResourceGroupName $ServiceBusNamespace.ResourceGroupName -NamespaceName $ServiceBusNamespace.Name -Queue $QueueName -AuthorizationRuleName "testapp")
        }
        return $ServiceBusKeyInfo.PrimaryConnectionString
    }
    else {
        return "Endpoint=sb://" + $NamespaceName + "." + $NamespaceDomain + ";EntityPath=" + $QueueName + ";Authentication='Managed Identity';"    
    }
}

function Test-EventHubsConfigApp([String] $Location, [String] $RGName, [String] $FAName) {
    
    Write-Host " - Deploy Event Hubs"
    & "$PSScriptRoot\..\functions\config\EventHubCopy\Deploy-Resources.ps1" -ResourceGroupName $RGName -FunctionAppName $FAName -Location $Location
    
    Write-Host " - Build Project"
    & "$PSScriptRoot\..\functions\config\EventHubCopy\Build-FunctionApp.ps1" 
    
    Write-Host " - Configure App"
    & "$PSScriptRoot\..\functions\config\EventHubCopy\Configure-Function.ps1" -ResourceGroupName $RGName -FunctionAppName $FAName -SourceNamespacename "eventhubcopyconfig-left" -SourceEventHubName telemetry -TargetNamespaceName "eventhubcopyconfig-right" -TargetEventHubName telemtry
    
    Write-Host " - Deploy Function"
    & "$PSScriptRoot\..\functions\config\EventHubCopy\Deploy-FunctionApp.ps1" -FunctionAppName $FAName

    Write-Host " - Run Test"
    pushd "$PSScriptRoot\EventHubCopyValidation" > $null
    & ".\bin\Debug\netcoreapp3.1\EventHubCopyValidation.exe" -t "$(Get-EventHubConnectionString -NamespaceName "eventhubcopyconfig-left" -EventHubName telemetry -UseSAS $true)" -s "$(Get-EventHubConnectionString -NamespaceName "eventhubcopyconfig-right" -EventHubName telemetry -UseSAS $true)" -et telemetry -es telemetry -cg '\$Default' 2>&1 >> "$PSScriptRoot\run.log"
    $result = $LastExitCode 
    popd > $null
    return $result
}

function Test-EventHubsCodeApp([String] $Location, [String] $RGName, [String] $FAName) {
    Write-Host " - Deploy Event Hubs"
    & "$PSScriptRoot\..\functions\code\EventHubCopy\Deploy-Resources.ps1" -ResourceGroupName $RGName -Location $Location -FunctionAppName $FAName
    
    Write-Host " - Configure App"
    & "$PSScriptRoot\..\functions\code\EventHubCopy\Configure-Function.ps1" -FunctionAppName $FAName -ResourceGroupName $RGName -SourceNamespacename "eventhubcopy-left" -SourceEventHubName "telemetry" -TargetNamespaceName "eventhubcopy-right" -TargetEventHubName "telemetry"
    
    Write-Host " - Deploy Function"
    & "$PSScriptRoot\..\functions\code\EventHubCopy\Deploy-FunctionApp.ps1" -FunctionAppName $FAName

    Write-Host " - Run Test"
    pushd "$PSScriptRoot\EventHubCopyValidation" > $null
    & ".\bin\Debug\netcoreapp3.1\EventHubCopyValidation.exe" -t "$(Get-EventHubConnectionString -NamespaceName "eventhubcopy-left" -EventHubName "telemetry" -UseSAS $true)" -s "$(Get-EventHubConnectionString -NamespaceName "eventhubcopy-right" -EventHubName "telemetry" -UseSAS $true)" -et telemetry -es telemetry -cg ($FAName+".telemetry") 2>&1 >> "$PSScriptRoot\run.log"
    $result = $LastExitCode 
    popd > $null

    return $result
}

function Test-EventHubsMergeCodeApp([String] $Location, [String] $RGName, [string] $FAName) {
    Write-Host " - Deploy Event Hubs"
    & "$PSScriptRoot\..\functions\code\EventHubMerge\Deploy-Resources.ps1" -ResourceGroupName $RGName -FunctionAppName $FAName -Location $Location
    
    Write-Host " - Configure App"
    & "$PSScriptRoot\..\functions\code\EventHubMerge\Configure-Function.ps1" -ResourceGroupName $RGName -FunctionAppName $FAName -LeftNamespacename "eventhubmerge-left" -LeftEventHubName "telemetry" -RightNamespaceName "eventhubmerge-right" -RightEventHubName "telemetry"
    
    Write-Host " - Deploy Function"
    & "$PSScriptRoot\..\functions\code\EventHubMerge\Deploy-Function.ps1" -FunctionAppName $FAName

    Write-Host " - Run Test"
    pushd "$PSScriptRoot\EventHubCopyValidation" > $null
    & ".\bin\Debug\netcoreapp3.1\EventHubCopyValidation.exe" -t "$(Get-EventHubConnectionString -NamespaceName "eventhubmerge-left" -EventHubName "telemetry" -UseSAS $true)" -s "$(Get-EventHubConnectionString -NamespaceName "eventhubmerge-right" -EventHubName "telemetry" -UseSAS $true)" -et "telemetry" -es "telemetry" -cg '\$Default' 2>&1 >> "$PSScriptRoot\run.log"
    $result = $LastExitCode 
    if ( $result -ne 0 )
    {
        return $result
    }
    & ".\bin\Debug\netcoreapp3.1\EventHubCopyValidation.exe" -t "$(Get-EventHubConnectionString -NamespaceName "eventhubmerge-left" -EventHubName "telemetry" -UseSAS $true)" -s "$(Get-EventHubConnectionString -NamespaceName "eventhubmerge-right" -EventHubName "telemetry" -UseSAS $true)" -et "telemetry" -es "telemetry" -cg '\$Default' 2>&1 >> "$PSScriptRoot\run.log"
    $result = $LastExitCode 
    popd > $null

    return $result
}

function Test-ServiceBusConfigApp([String] $Location, [String] $RGName, [String] $FAName) {
    
    Write-Host " - Deploy Service Bus"
    & "$PSScriptRoot\..\functions\config\ServiceBusCopy\Deploy-Resources.ps1" -ResourceGroupName $RGName -Location $Location
    
    Write-Host " - Build Project"
    & "$PSScriptRoot\..\functions\config\ServiceBusCopy\Build-FunctionApp.ps1" 
    
    Write-Host " - Configure App"
    & "$PSScriptRoot\..\functions\config\ServiceBusCopy\Configure-Function.ps1" -ResourceGroupName $RGName -FunctionAppName $FAName -SourceNamespacename "servicebuscopy-left" -SourceQueueName "jobs-transfer" -TargetNamespaceName "servicebuscopy-right" -TargetQueueName "jobs"
    
    Write-Host " - Deploy Function"
    & "$PSScriptRoot\..\functions\config\ServiceBusCopy\Deploy-FunctionApp.ps1" -FunctionAppName $FAName

    Write-Host " - Run Test"
    pushd "$PSScriptRoot\ServiceBusCopyValidation" > $null
    & ".\bin\Debug\netcoreapp3.1\ServiceBusCopyValidation.exe" -s "$(Get-ServiceBusConnectionString -NamespaceName "servicebuscopy-left" -QueueName "jobs-transfer" -UseSAS $true)" -t "$(Get-ServiceBusConnectionString -NamespaceName "servicebuscopy-right" -QueueName "jobs" -UseSAS $true)" -qt "jobs" -qs "jobs-transfer" 2>&1 >> "$PSScriptRoot\run.log"
    $result = $LastExitCode 
    popd > $null
    return $result
}

function Test-ServiceBusCodeApp([String] $Location, [String] $RGName, [String] $FAName) {
    Write-Host " - Deploy Service Bus"
    & "$PSScriptRoot\..\functions\code\ServiceBusCopy\Deploy-Resources.ps1" -ResourceGroupName $RGName -Location $Location
    
    Write-Host " - Configure App"
    & "$PSScriptRoot\..\functions\code\ServiceBusCopy\Configure-Function.ps1" -ResourceGroupName $RGName -FunctionAppName $FAName -SourceNamespacename "servicebuscopy-left" -SourceQueueName "jobs-transfer" -TargetNamespaceName "servicebuscopy-right" -TargetQueueName "jobs"
    
    Write-Host " - Deploy Function"
    & "$PSScriptRoot\..\functions\code\ServiceBusCopy\Deploy-FunctionApp.ps1" -FunctionAppName $FAName

    Write-Host " - Run Test"
    pushd "$PSScriptRoot\ServiceBusCopyValidation" > $null
    & ".\bin\Debug\netcoreapp3.1\ServiceBusCopyValidation.exe" -s "$(Get-ServiceBusConnectionString -NamespaceName "servicebuscopy-left" -QueueName "jobs-transfer" -UseSAS $true)" -t "$(Get-ServiceBusConnectionString -NamespaceName "servicebuscopy-right" -QueueName "jobs" -UseSAS $true)" -qt "jobs" -qs "jobs-transfer" 2>&1 >> "$PSScriptRoot\run.log"
    $result = $LastExitCode 
    popd > $null

    return $result
}

Write-Host "Building Test projects"
pushd "$PSScriptRoot\EventHubCopyValidation" > $null
dotnet build "EventHubCopyValidation.csproj" -c Debug 2>&1 > build.log
popd > $null

pushd "$PSScriptRoot\ServiceBusCopyValidation" > $null
dotnet build "ServiceBusCopyValidation.csproj" -c Debug 2>&1 > build.log
popd > $null

# Write-Host "Event Hub Scenario Code/Consumption"
# $RGName = "mjrmsgrepl$(Get-Date -UFormat '%s')"
# $Location = "westeurope"
# Write-Host " - Create App Host"
# & "$PSScriptRoot\..\templates\Deploy-FunctionsConsumptionPlan.ps1" -ResourceGroupName $RGName -Location $Location
# $appName = (Get-AzResourceGroupDeployment -ResourceGroupName $RGName -Name "azuredeploy").Outputs.functionsAppName.value
# $result = Test-EventHubsCodeApp -Location $Location -RGName $RGName -FAName $appName 
# Write-Host " - Undeploy App"
# $null = Remove-AzResourceGroup -Name $RGname -Force

# if ( $result -ne 0) {
#     exit $result
# }

# Write-Host "Event Hub Scenario Code/Premium"
# $RGName = "msgrepl$(Get-Date -UFormat '%s')"
# $Location = "westeurope"
# Write-Host " - Create App Host"
# & "$PSScriptRoot\..\templates\Deploy-FunctionsPremiumPlan.ps1" -ResourceGroupName $RGName -Location $Location
# $appName = (Get-AzResourceGroupDeployment -ResourceGroupName $RGName -Name "azuredeploy").Outputs.functionsAppName.value
# $result = Test-EventHubsCodeApp -Location $Location -RGName $RGName -FAName $appName
# Write-Host " - Undeploy App"
# $null = Remove-AzResourceGroup -Name $RGname -Force

# if ( $result -ne 0) {
#     Write-Host "result $result"
#     exit $result
# }

# Write-Host "Event Hub Merge Scenario Code/Consumption"
# $RGName = "msgrepl$(Get-Date -UFormat '%s')"

# $Location = "westeurope"
# Write-Host " - Create App Host"
# & "$PSScriptRoot\..\templates\Deploy-FunctionsConsumptionPlan.ps1" -ResourceGroupName $RGName -Location $Location
# $appName = (Get-AzResourceGroupDeployment -ResourceGroupName $RGName -Name "azuredeploy").Outputs.functionsAppName.value
# $result = Test-EventHubsMergeCodeApp -Location $Location -RGName $RGName -FAName $appName
# Write-Host " - Undeploy App"
# $null = Remove-AzResourceGroup -Name $RGname -Force

# if ( $result -ne 0) {
#     exit $result
# }

# Write-Host "Event Hub Merge Scenario Code/Premium"
# $RGName = "msgrepl$(Get-Date -UFormat '%s')"
# $Location = "westeurope"
# Write-Host " - Create App Host"
# & "$PSScriptRoot\..\templates\Deploy-FunctionsPremiumPlan.ps1" -ResourceGroupName $RGName -Location $Location
# $appName = (Get-AzResourceGroupDeployment -ResourceGroupName $RGName -Name "azuredeploy").Outputs.functionsAppName.value
# $result = Test-EventHubsMergeCodeApp -Location $Location -RGName $RGName -FAName $appName
# Write-Host " - Undeploy App"
# $null = Remove-AzResourceGroup -Name $RGname -Force

# if ( $result -ne 0) {
#     Write-Host "result $result"
#     exit $result
# }

# Write-Host "Event Hub Scenario Config/Consumption"
# $RGName = "msgrepl$(Get-Date -UFormat '%s')"
# $Location = "westeurope"
# Write-Host " - Create App Host"
# & "$PSScriptRoot\..\templates\Deploy-FunctionsConsumptionPlan.ps1" -ResourceGroupName $RGName -Location $Location
# $appName = (Get-AzResourceGroupDeployment -ResourceGroupName $RGName -Name "azuredeploy").Outputs.functionsAppName.value
# $result = Test-EventHubsConfigApp -Location $Location -RGName $RGName -FAName $appName
# Write-Host " - Undeploy App"
# $null = Remove-AzResourceGroup -Name $RGname -Force

# if ( $result -ne 0) {
#     Write-Host "result $result"
#     exit $result
# }

# Write-Host "Event Hub Scenario Config Premium/Consumption"
# $RGName = "msgrepl$(Get-Date -UFormat '%s')"
# $Location = "westeurope"
# Write-Host " - Create App Host"
# & "$PSScriptRoot\..\templates\Deploy-FunctionsPremiumPlan.ps1" -ResourceGroupName $RGName -Location $Location
# $appName = (Get-AzResourceGroupDeployment -ResourceGroupName $RGName -Name "azuredeploy").Outputs.functionsAppName.value
# $result = Test-EventHubsConfigApp -Location $Location -RGName $RGName -FAName $appName
# Write-Host " - Undeploy App"
# $null = Remove-AzResourceGroup -Name $RGname -Force

# if ( $result -ne 0) {
#     exit $result
# }


Write-Host "Service Bus Scenario Config/Consumption"
$RGName = "msgrepl$(Get-Date -UFormat '%s')"
$Location = "westeurope"
Write-Host " - Create App Host"
& "$PSScriptRoot\..\templates\Deploy-FunctionsConsumptionPlan.ps1" -ResourceGroupName $RGName -Location $Location
$appName = (Get-AzResourceGroupDeployment -ResourceGroupName $RGName -Name "azuredeploy").Outputs.functionsAppName.value
$result = Test-ServiceBusConfigApp -Location $Location -RGName $RGName -FAName $appName
Write-Host " - Undeploy App"
$null = Remove-AzResourceGroup -Name $RGname -Force

if ( $result -ne 0) {
    Write-Host "result $result"
    exit $result
}

exit 0

Write-Host "Service Bus Scenario Config Premium/Consumption"
$RGName = "msgrepl$(Get-Date -UFormat '%s')"
$Location = "westeurope"
Write-Host " - Create App Host"
& "$PSScriptRoot\..\templates\Deploy-FunctionsPremiumPlan.ps1" -ResourceGroupName $RGName -Location $Location
$appName = (Get-AzResourceGroupDeployment -ResourceGroupName $RGName -Name "azuredeploy").Outputs.functionsAppName.value
$result = Test-ServiceBusConfigApp -Location $Location -RGName $RGName -FAName $appName
Write-Host " - Undeploy App"
$null = Remove-AzResourceGroup -Name $RGname -Force

if ( $result -ne 0) {
    exit $result
}

Write-Host "Service Bus Scenario Code/Consumption"
$RGName = "msgrepl$(Get-Date -UFormat '%s')"
$Location = "westeurope"
Write-Host " - Create App Host"
& "$PSScriptRoot\..\templates\Deploy-FunctionsConsumptionPlan.ps1" -ResourceGroupName $RGName -Location $Location
$appName = (Get-AzResourceGroupDeployment -ResourceGroupName $RGName -Name "azuredeploy").Outputs.functionsAppName.value
$result = Test-ServiceBusCodeApp -Location $Location -RGName $RGName -FAName $appName
Write-Host " - Undeploy App"
$null = Remove-AzResourceGroup -Name $RGname -Force

if ( $result -ne 0) {
    exit $result
}

Write-Host "Service Bus Scenario Code/Premium"
$RGName = "msgrepl$(Get-Date -UFormat '%s')"
$Location = "westeurope"
Write-Host " - Create App Host"
& "$PSScriptRoot\..\templates\Deploy-FunctionsPremiumPlan.ps1" -ResourceGroupName $RGName -Location $Location
$appName = (Get-AzResourceGroupDeployment -ResourceGroupName $RGName -Name "azuredeploy").Outputs.functionsAppName.value
$result = Test-ServiceBusCodeApp -Location $Location -RGName $RGName -FAName $appName
Write-Host " - Undeploy App"
$null = Remove-AzResourceGroup -Name $RGname -Force

exit $result
