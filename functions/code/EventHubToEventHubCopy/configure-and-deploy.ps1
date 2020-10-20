[CmdletBinding()]
param (
    # Name of the replication task
    [Parameter(Mandatory)]
    [String]
    $TaskName = "replication",
    # Name of the Azure Resource Group
    [Parameter(Mandatory)]
    [String]
    $ResourceGroupName,
    # Name of the Functions Application
    [Parameter(Mandatory)]
    [String]
    $FunctionAppName,
    # Source Event Hub Namespace FQDN
    [Parameter(Mandatory)]
    [String]
    $SourceEventHubNamespaceFQDN,
    # Source EventHub Name
    [Parameter(Mandatory)]
    [String]
    $SourceEventHubName,
    # Target Event Hub Namespace FQDN
    [Parameter(Mandatory)]
    [String]
    $TargetEventHubNamespaceFQDN,
    # Source EventHub Name
    [Parameter(Mandatory)]
    [String]
    $TargetEventHubName
)

function Update-EventHub  ([String] $EventHubNamespaceFQDN, [String] $EventHubName, [Microsoft.Azure.Commands.ResourceManager.Cmdlets.SdkModels.PSResource] $FunctionApp, [bool] $IsReceiver) {
    # Update roles on source Event Hub for Managed Identity with RBAC
    $EventHubNamespace = $(Get-AzResource -resourcetype "Microsoft.EventHub/namespaces" -name $EventHubNamespaceFQDN.Split('.')[0])
    if ( $EventHubNamespace ) {
        $EventHubNamespacePath = $EventHubNamespace.ResourceId
        $EventHubAuthorizationRule = $(Get-AzEventHubAuthorizationRule -ResourceGroupName $EventHubNamespace.ResourceGroupName -NamespaceName $EventHubNamespace.Name -EventHubName $EventHubName -Name $TaskName -ErrorAction SilentlyContinue)
        if ( -Not $EventHubAuthorizationRule ) {
            $EventHubAuthorizationRule = New-AzEventHubAuthorizationRule -ResourceGroupName $EventHubNamespace.ResourceGroupName -NamespaceName $EventHubNamespace.Name -EventHubName $EventHubName -Name $TaskName -Rights "Send","Listen"
        }

        if ( $IsReceiver ) {
            If ( -Not $(Get-AzRoleAssignment -ObjectId $FunctionApp.Identity.PrincipalId -RoleDefinitionName "Azure Event Hubs Data Receiver" -Scope ($EventHubNamespacePath + "/eventHubs/" + $EventHubName) -ErrorAction SilentlyContinue)) {
                New-AzRoleAssignment -ObjectId $FunctionApp.Identity.PrincipalId -RoleDefinitionName "Azure Event Hubs Data Receiver" -Scope ($EventHubNamespacePath + "/eventHubs/" + $EventHubName)
            }
            If ( -Not $(Get-AzEventHubConsumerGroup -ResourceGroupName $EventHubNamespace.ResourceGroupName -NamespaceName $EventHubNamespace.Name -EventHub $EventHubName -Name replication -ErrorAction SilentlyContinue)) {
                New-AzEventHubConsumerGroup -ResourceGroupName $EventHubNamespace.ResourceGroupName -NamespaceName $EventHubNamespace.Name -EventHub $EventHubName -Name replication
            }
        } else {
            If ( -Not $(Get-AzRoleAssignment -ObjectId $FunctionApp.Identity.PrincipalId -RoleDefinitionName "Azure Event Hubs Data Sender" -Scope ($EventHubNamespacePath + "/eventHubs/" + $EventHubName) -ErrorAction SilentlyContinue)) {
                New-AzRoleAssignment -ObjectId $FunctionApp.Identity.PrincipalId -RoleDefinitionName "Azure Event Hubs Data Sender" -Scope ($EventHubNamespacePath + "/eventHubs/" + $EventHubName)
            }
        }
        return $EventHubNamespacePath
    }    
}

function Get-ConnectionString  ([String] $EventHubNamespaceFQDN, [String] $EventHubName, [bool] $UseSAS = $true) {
    if ( $UseSAS ) {
        $EventHubNamespace = $(Get-AzResource -resourcetype "Microsoft.EventHub/namespaces" -name $EventHubNamespaceFQDN.Split('.')[0])
        $EventHubKeyInfo = $(Get-AzEventHubKey -ResourceGroupName $EventHubNamespace.ResourceGroupName -NamespaceName $EventHubNamespace.Name -EventHubName $EventHubName -AuthorizationRuleName $TaskName)
        if ( -Not $EventHubKeyInfo ) {
            New-AzEventHubAuthorizationRule -ResourceGroupName $EventHubNamespace.ResourceGroupName -NamespaceName $EventHubNamespace.Name -EventHubName $EventHubName -Name $TaskName -Rights "Send","Listen"
            $EventHubKeyInfo = $(Get-AzEventHubKey -ResourceGroupName $EventHubNamespace.ResourceGroupName -NamespaceName $EventHubNamespace.Name -EventHubName $EventHubName -AuthorizationRuleName $TaskName)
        }
        return $EventHubKeyInfo.PrimaryConnectionString
    }
    else {
        return "Endpoint=sb://" + $EventHubNamespaceFQDN + ";EntityPath=" + $EventHubName + ";Authentication='Managed Identity';"    
    }
}

$SubscriptionsPath = "/subscriptions/" + $(Get-AzContext).Subscription.Id
$FunctionAppResourcePath = $SubscriptionsPath + "/resourceGroups/" + $ResourceGroupName + "/providers/Microsoft.Web/sites/" + $FunctionAppName
$FunctionApp = Get-AzResource -ResourceId $FunctionAppResourcePath

Update-EventHub $SourceEventHubNamespaceFQDN $SourceEventHubName $FunctionApp $true
Update-EventHub $TargetEventHubNamespaceFQDN $TargetEventHubName $FunctionApp $false

$SourceEventHubConnectionString = Get-ConnectionString $SourceEventHubNamespaceFQDN $SourceEventHubName 
$TargetEventHubConnectionString = Get-ConnectionString $TargetEventHubNamespaceFQDN $TargetEventHubName 

Update-AzFunctionAppSetting -Name $FunctionAppName -ResourceGroupName $ResourceGroupName -AppSetting @{ -join($TaskName,"-source-eventhub-connection") = $SourceEventHubConnectionString; -join ($TaskName,"-target-eventhub-connection") = $TargetEventHubConnectionString }


func azure functionapp publish $FunctionAppName