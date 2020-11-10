# This script is meand to be run as the validation stage of the 
# build process and under an existing Azure PowerShell context.
# This may be provided by the AzurePowerShell task in Azure Pipelines


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

$RGName = "msgrepl$(Get-Date -UFormat '%s')"
$Location = "westeurope"

& "$PSScriptRoot\..\templates\Deploy-FunctionsConsumptionPlan.ps1" -ResourceGroupName $RGName -Location $Location
& "$PSScriptRoot\..\functions\config\EventHubToEventHubCopy\Deploy-Resources.ps1" -ResourceGroupName $RGName -Location $Location -NamespaceName $RGName 
& "$PSScriptRoot\..\functions\config\EventHubToEventHubCopy\Build-FunctionApp.ps1" 
& "$PSScriptRoot\..\functions\config\EventHubToEventHubCopy\Configure-Function.ps1" -TaskName EventHubAToEventHubB -FunctionAppName $RGName -SourceNamespacename $RGName -SourceEventHubName eventHubA -TargetNamespaceName $RGname -TargetEventHubName eventHubB
& "$PSScriptRoot\..\functions\config\EventHubToEventHubCopy\Deploy-FunctionApp.ps1" -FunctionAppName $RGName



pushd "$PSScriptRoot\EventHubCopyValidation"
dotnet build "EventHubCopyValidation.csproj" -c Debug
& ".\bin\Debug\netcoreapp3.1\EventHubCopyValidation.exe" -t "$(Get-EventHubConnectionString -NamespaceName $RGName -EventHubName eventHubA -UseSAS $true)" -s "$(Get-EventHubConnectionString -NamespaceName $RGName -EventHubName eventHubB -UseSAS $true)" -et eventHubA -es eventHubB -cg '\$Default'
popd

Remove-AzResourceGroup -Name $RGname -Force