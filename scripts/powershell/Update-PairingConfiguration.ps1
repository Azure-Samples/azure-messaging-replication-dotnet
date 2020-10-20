[CmdletBinding()]
param (
    # Name of the replication task
    [Parameter(Mandatory)]
    [String]
    $TaskName = "replication",
    # Name of the Functions Application
    [Parameter(Mandatory)]
    [String]
    $FunctionAppName,
    # Source Event Hub or Service Bus Namespace 
    [Parameter()]
    [String]
    $SourceNamespaceName,
    # Source Event Hub Name
    [Parameter()]
    [String]
    $SourceEventHubName,
    # Source Service Bus Queue Name
    [Parameter()]
    [String]
    $SourceQueueName,
    # Source Service Bus Topic Name
    [Parameter()]
    [String]
    $SourceTopicName,
    # Source Service Bus Topic Subscription Name
    [Parameter()]
    [String]
    $SourceSubscriptionName,
    # Target Event Hub or Service Bus Namespace 
    [Parameter(Mandatory)]
    [String]
    $TargetNamespaceName,
    # Target Event Hub Name
    [Parameter()]
    [String]
    $TargetEventHubName,
    # Target Queue Name
    [Parameter()]
    [String]
    $TargetQueueName,
    # Target Topic Name
    [Parameter()]
    [String]
    $TargetTopicName
)

$NamespaceDomain = "servicebus.windows.net"

function Update-EventHub  ([String] $NamespaceName, [String] $EventHubName, [Microsoft.Azure.Commands.ResourceManager.Cmdlets.SdkModels.PSResource] $FunctionApp, [bool] $IsReceiver) {
    # Update roles on source Event Hub for Managed Identity with RBAC
    $EventHubNamespace = $(Get-AzResource -resourcetype "Microsoft.EventHub/namespaces" -name $NamespaceName.Split('.')[0])
    if ( $EventHubNamespace ) {
        $EventHubNamespacePath = $EventHubNamespace.ResourceId
        $EventHubAuthorizationRule = $(Get-AzEventHubAuthorizationRule -ResourceGroupName $EventHubNamespace.ResourceGroupName -NamespaceName $EventHubNamespace.Name -EventHubName $EventHubName -Name "replicator" -ErrorAction SilentlyContinue)
        if ( -Not $EventHubAuthorizationRule ) {
            $EventHubAuthorizationRule = New-AzEventHubAuthorizationRule -ResourceGroupName $EventHubNamespace.ResourceGroupName -NamespaceName $EventHubNamespace.Name -EventHubName $EventHubName -Name "replicator" -Rights "Send", "Listen"
        }

        if ( $IsReceiver ) {
            If ( -Not $(Get-AzRoleAssignment -ObjectId $FunctionApp.Identity.PrincipalId -RoleDefinitionName "Azure Event Hubs Data Receiver" -Scope ($EventHubNamespacePath + "/eventHubs/" + $EventHubName) -ErrorAction SilentlyContinue)) {
                $null = New-AzRoleAssignment -ObjectId $FunctionApp.Identity.PrincipalId -RoleDefinitionName "Azure Event Hubs Data Receiver" -Scope ($EventHubNamespacePath + "/eventHubs/" + $EventHubName)
            }
            If ( -Not $(Get-AzEventHubConsumerGroup -ResourceGroupName $EventHubNamespace.ResourceGroupName -NamespaceName $EventHubNamespace.Name -EventHub $EventHubName -Name $TaskName -ErrorAction SilentlyContinue)) {
                $null = New-AzEventHubConsumerGroup -ResourceGroupName $EventHubNamespace.ResourceGroupName -NamespaceName $EventHubNamespace.Name -EventHub $EventHubName -Name $TaskName
            }
        }
        else {
            If ( -Not $(Get-AzRoleAssignment -ObjectId $FunctionApp.Identity.PrincipalId -RoleDefinitionName "Azure Event Hubs Data Sender" -Scope ($EventHubNamespacePath + "/eventHubs/" + $EventHubName) -ErrorAction SilentlyContinue)) {
                $null = New-AzRoleAssignment -ObjectId $FunctionApp.Identity.PrincipalId -RoleDefinitionName "Azure Event Hubs Data Sender" -Scope ($EventHubNamespacePath + "/eventHubs/" + $EventHubName)
            }
        }
        return $EventHubNamespacePath
    }    
}

function Update-ServiceBus  ([String] $NamespaceName, [String] $QueueName, [String] $TopicName, [String] $SubscriptionName, [Microsoft.Azure.Commands.ResourceManager.Cmdlets.SdkModels.PSResource] $FunctionApp, [bool] $IsReceiver) {

    if ( ($QueueName -and $TopicName) -or (-not $QueueName -and -not $TopicName) ) {
        Write-Error "QueueName and ServiceBusTopic name are mutually exclusive"
        return
    }
    if ( $TopicName -and $SubscriptionName -and -not $IsReceiver) {
        Write-Error "Must use receiver mode when specifying subscription"
    }
    if ( $TopicName -and $IsReceiver -and -not $SubscriptionName) {
        Write-Error "Receiver mode requires subscription name for topics"
    }

    # Update roles on source Event Hub for Managed Identity with RBAC
    $ServiceBusNamespace = $(Get-AzResource -resourcetype "Microsoft.ServiceBus/namespaces" -name $NamespaceName.Split('.')[0])
    if ( $ServiceBusNamespace ) {
        $ServiceBusNamespacePath = $ServiceBusNamespace.ResourceId

        if ( $QueueName ) {
            $ServiceBusQueue = $(Get-AzServiceBusQueue -ResourceGroupName $ServiceBusNamespace.ResourceGroupName -NamespaceName $ServiceBusNamespace.Name -QueueName $QueueName -ErrorAction SilentlyContinue)
            $ServiceBusAuthorizationRule = $(Get-AzServiceBusAuthorizationRule -ResourceGroupName $ServiceBusNamespace.ResourceGroupName -NamespaceName $ServiceBusNamespace.Name -QueueName $ServiceBusQueue.Name -Name "replicator" -ErrorAction SilentlyContinue)
            if ( -Not $ServiceBusAuthorizationRule ) {
                $ServiceBusAuthorizationRule = New-AzServiceBusAuthorizationRule -ResourceGroupName $ServiceBusNamespace.ResourceGroupName -NamespaceName $ServiceBusNamespace.Name -QueueName $ServiceBusQueue.Name -Name "replicator" -Rights "Send", "Listen"
            }

            if ( $IsReceiver ) {
                If ( -Not $(Get-AzRoleAssignment -ObjectId $FunctionApp.Identity.PrincipalId -RoleDefinitionName "Azure Service Bus Data Receiver" -Scope ($ServiceBusNamespacePath + "/queues/" + $ServiceBusQueue.Name) -ErrorAction SilentlyContinue)) {
                    $null = New-AzRoleAssignment -ObjectId $FunctionApp.Identity.PrincipalId -RoleDefinitionName "Azure Service Bus Data Receiver" -Scope ($ServiceBusNamespacePath + "/queues/" + $ServiceBusQueue.Name)
                }
            }
            else {
                If ( -Not $(Get-AzRoleAssignment -ObjectId $FunctionApp.Identity.PrincipalId -RoleDefinitionName "Azure Service Bus Data Sender" -Scope ($ServiceBusNamespacePath + "/queues/" + $ServiceBusQueue.Name) -ErrorAction SilentlyContinue)) {
                    $null = New-AzRoleAssignment -ObjectId $FunctionApp.Identity.PrincipalId -RoleDefinitionName "Azure Service Bus Data Sender" -Scope ($ServiceBusNamespacePath + "/queues/" + $ServiceBusQueue.Name)
                }
            }
        }
        else {
            $ServiceBusTopic = $(Get-AzServiceBusTopic -ResourceGroupName $ServiceBusNamespace.ResourceGroupName -NamespaceName $ServiceBusNamespace.Name -TopicName $TopicName -ErrorAction SilentlyContinue)
            $ServiceBusAuthorizationRule = $(Get-AzServiceBusAuthorizationRule -ResourceGroupName $ServiceBusNamespace.ResourceGroupName -NamespaceName $ServiceBusNamespace.Name -TopicName $ServiceBusTopic.Name -Name "replicator" -ErrorAction SilentlyContinue)
            if ( -Not $ServiceBusAuthorizationRule ) {
                $ServiceBusAuthorizationRule = New-AzServiceBusAuthorizationRule -ResourceGroupName $ServiceBusNamespace.ResourceGroupName -NamespaceName $ServiceBusNamespace.Name -TopicName $ServiceBusTopic.Name -Name "replicator" -Rights "Send", "Listen"
            }

            if ( $IsReceiver ) {
                If ( -Not $(Get-AzRoleAssignment -ObjectId $FunctionApp.Identity.PrincipalId -RoleDefinitionName "Azure Service Bus Data Receiver" -Scope ($ServiceBusNamespacePath + "/topics/" + $ServiceBusTopic.Name + "/subscriptions/" + $SubscriptionName) -ErrorAction SilentlyContinue)) {
                    $null = New-AzRoleAssignment -ObjectId $FunctionApp.Identity.PrincipalId -RoleDefinitionName "Azure Service Bus Data Receiver" -Scope ($ServiceBusNamespacePath + "/topics/" + $ServiceBusTopic.Name + "/subscriptions/" + $SubscriptionName)
                }
            }
            else {
                If ( -Not $(Get-AzRoleAssignment -ObjectId $FunctionApp.Identity.PrincipalId -RoleDefinitionName "Azure Service Bus Data Sender" -Scope ($ServiceBusNamespacePath + "/queues/" + $ServiceBusTopic.Name) -ErrorAction SilentlyContinue)) {
                    $null = New-AzRoleAssignment -ObjectId $FunctionApp.Identity.PrincipalId -RoleDefinitionName "Azure Service Bus Data Sender" -Scope ($ServiceBusNamespacePath + "/queues/" + $ServiceBusTopic.Name)
                }
            }
        }
        return $ServiceBusNamespacePath
    }    
}

function Get-EventHubConnectionString  ([String] $NamespaceName, [String] $EventHubName, [bool] $UseSAS = $true) {
    if ( $UseSAS ) {
        $EventHubNamespace = $(Get-AzResource -resourcetype "Microsoft.EventHub/namespaces" -name $NamespaceName.Split('.')[0])
        $EventHubKeyInfo = $(Get-AzEventHubKey -ResourceGroupName $EventHubNamespace.ResourceGroupName -NamespaceName $EventHubNamespace.Name -EventHubName $EventHubName -AuthorizationRuleName $TaskName -ErrorAction SilentlyContinue)
        if ( -Not $EventHubKeyInfo ) {
            $null = New-AzEventHubAuthorizationRule -ResourceGroupName $EventHubNamespace.ResourceGroupName -NamespaceName $EventHubNamespace.Name -EventHubName $EventHubName -Name "replicator" -Rights "Send", "Listen"
            $EventHubKeyInfo = $(Get-AzEventHubKey -ResourceGroupName $EventHubNamespace.ResourceGroupName -NamespaceName $EventHubNamespace.Name -EventHubName $EventHubName -AuthorizationRuleName "replicator")
        }
        return $EventHubKeyInfo.PrimaryConnectionString
    }
    else {
        return "Endpoint=sb://" + $NamespaceName + "." + $NamespaceDomain + ";EntityPath=" + $EventHubName + ";Authentication='Managed Identity';"    
    }
}

function Get-ServiceBusConnectionString  ([String] $NamespaceName, [String] $QueueName, [String] $TopicName, [String] $SubscriptionName, [bool] $UseSAS = $true) {
   
    if ( ($QueueName -and $TopicName) -or (-not $QueueName -and -not $TopicName) ) {
        Write-Error "QueueName and ServiceBusTopic name are mutually exclusive"
        return
    }

    $ServiceBusNamespace = $(Get-AzResource -resourcetype "Microsoft.ServiceBus/namespaces" -name $NamespaceName.Split('.')[0])
       
    if ( $UseSAS ) {
        if ( $QueueName ) {
            $ServiceBusKeyInfo = $(Get-AzServiceBusKey -ResourceGroupName $ServiceBusNamespace.ResourceGroupName -NamespaceName $ServiceBusNamespace.Name -QueueName $QueueName -AuthorizationRuleName $TaskName -ErrorAction SilentlyContinue)
            if ( -Not $ServiceBusKeyInfo ) {
                $null = New-AzServiceBusAuthorizationRule -ResourceGroupName $ServiceBusNamespace.ResourceGroupName -NamespaceName $ServiceBusNamespace.Name -QueueName $QueueName -Name "replicator" -Rights "Send", "Listen"
                $ServiceBusKeyInfo = $(Get-AzServiceBusKey -ResourceGroupName $ServiceBusNamespace.ResourceGroupName -NamespaceName $ServiceBusNamespace.Name -QueueName $QueueName -AuthorizationRuleName "replicator")
            }
        }
        else {
            $ServiceBusKeyInfo = $(Get-AzServiceBusKey -ResourceGroupName $ServiceBusNamespace.ResourceGroupName -NamespaceName $ServiceBusNamespace.Name -TopicName $TopicName -AuthorizationRuleName $TaskName -ErrorAction SilentlyContinue)
            if ( -Not $ServiceBusKeyInfo ) {
                $null =  New-AzServiceBusAuthorizationRule -ResourceGroupName $ServiceBusNamespace.ResourceGroupName -NamespaceName $ServiceBusNamespace.Name -TopicName $TopicName -Name "replicator" -Rights "Send", "Listen"
                $ServiceBusKeyInfo = $(Get-AzServiceBusKey -ResourceGroupName $ServiceBusNamespace.ResourceGroupName -NamespaceName $ServiceBusNamespace.Name -TopicName $TopicName -AuthorizationRuleName "replicator")
            }
        }
        return "Endpoint=sb://" + $NamespaceName + "." + $NamespaceDomain + ";SharedAccessKeyName=" + $ServiceBusKeyInfo.KeyName + ";SharedAccessKey=" + $ServiceBusKeyInfo.PrimaryKey    
    }
    elseif ( $QueueName ) {
        return "Endpoint=sb://" + $NamespaceName + "." + $NamespaceDomain + ";Authentication='Managed Identity';"    
    }
    elseif ( $TopicName -and $SubscriptionName ) {
        return "Endpoint=sb://" + $NamespaceName + "." + $NamespaceDomain + ";Authentication='Managed Identity';"    
    }
    elseif ( $TopicName ) {
        return "Endpoint=sb://" + $NamespaceName + "." + $NamespaceDomain + ";Authentication='Managed Identity';"    
    }
}

$FunctionApp = $(Get-AzResource -resourcetype "Microsoft.Web/sites" -name $FunctionAppName)
if ( -Not $FunctionApp) {    Write-Error "Function app $FunctionAppName not found"
    return;
}

if ( $SourceEventHubName ) {
    $null = Update-EventHub -NamespaceName $SourceNamespaceName -EventHubName $SourceEventHubName -FunctionApp $FunctionApp -IsReceiver $true 
    $SourceConnectionString = Get-EventHubConnectionString $SourceNamespaceName $SourceEventHubName
}
elseif ( $SourceQueueName ) {
    $null = Update-ServiceBus -NamespaceName $SourceNamespaceName -QueueName $SourceQueueName -FunctionApp $FunctionApp -IsReceiver $true
    $SourceConnectionString = Get-ServiceBusConnectionString -NamespaceName $SourceNamespaceName -QueueName $SourceQueueName
}
elseif ( $SourceTopicName -and $SourceSubscriptionName ) {
    $null = Update-ServiceBus -NamespaceName $SourceNamespaceName -TopicName $SourceTopicName -SubscriptionName $SourceSubscriptionName -FunctionApp $FunctionApp -IsReceiver $true
    $SourceConnectionString = Get-ServiceBusConnectionString -NamespaceName $SourceNamespaceName -TopicName $SourceTopicName -SubscriptionName $SourceSubscriptionName
}

if ( $TargetEventHubName ) {
    $null = Update-EventHub -NamespaceName $TargetNamespaceName -EventHubName $TargetEventHubName -FunctionApp $FunctionApp -IsReceiver $false
    $TargetConnectionString = Get-EventHubConnectionString $TargetNamespaceName $TargetEventHubName 
}
elseif ($TargetQueueName) {
    $null = Update-ServiceBus -NamespaceName $TargetNamespaceName -QueueName $TargetQueueName -FunctionApp $FunctionApp -IsReceiver $false
    $TargetConnectionString = Get-ServiceBusConnectionString -NamespaceName $TargetNamespaceName -QueueName $TargetQueueName 
}
elseif ($TargetTopicName) {
    $null = Update-ServiceBus -NamespaceName $TargetNamespaceName -TopicName $TargetTopicName -FunctionApp $FunctionApp -IsReceiver $false
    $TargetConnectionString = Get-ServiceBusConnectionString -NamespaceName $TargetNamespaceName -TopicName $TargetTopicsName 
}


$null = Update-AzFunctionAppSetting -Name $FunctionAppName -ResourceGroupName $ResourceGroupName -AppSetting @{ -join ($TaskName, "-source-connection") = $SourceConnectionString; -join ($TaskName, "-target-connection") = $TargetConnectionString }
