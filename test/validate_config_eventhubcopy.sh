#!/bin/bash

echo "EventHubCopy Validation (Config). (Patience! This will take a while!)"

# start in script dir 
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
pushd $DIR  > /dev/null

LOGFILE=$DIR/eventhubcopy_config.log 
rm -f $LOGFILE

USER_SUFFIX=$(date +"%03j%02y%02H%02M%02S")

if [ "$AZURE_LOCATION" == '' ]; then
   AZURE_LOCATION=westeurope
fi

CREATE_RESOURCE_GROUP=false
if [ ! $USER_RESOURCE_GROUP ]; then
   CREATE_RESOURCE_GROUP=true
   USER_RESOURCE_GROUP='ehcopysmp-'$USER_SUFFIX
fi

USER_LEFT_NAMESPACE_NAME='ehcopysmp-left-'$USER_SUFFIX
USER_RIGHT_NAMESPACE_NAME='ehcopysmp-right-'$USER_SUFFIX
USER_FUNCTIONS_APP_NAME='ehcopysmp-'$USER_SUFFIX
USER_STORAGE_ACCOUNT='ehcopysmp'$USER_SUFFIX

quit() {
    if [ $CREATE_RESOURCE_GROUP ]; then 
       az group delete --name $USER_RESOURCE_GROUP --yes >> $LOGFILE 2>&1
    fi
    echo "error, quitting"
    exit $1
}

# go into project dir
pushd ../functions/config/EventHubCopy > /dev/null

if [ $CREATE_RESOURCE_GROUP ]; then
    echo "Creating resource group ..."
    az group create --name $USER_RESOURCE_GROUP --location $AZURE_LOCATION >> $LOGFILE 2>&1
    retval=$?
    if [ $retval -ne 0 ]; then
        exit $retval
    fi
    echo "Resource group $USER_RESOURCE_GROUP created"
fi

echo "Deploying resource template ..."
az deployment group create  --resource-group "$USER_RESOURCE_GROUP" \
                            --template-file="template/azuredeploy.json" \
                            --parameters leftNamespaceName="$USER_LEFT_NAMESPACE_NAME" \
                                        rightNamespaceName="$USER_RIGHT_NAMESPACE_NAME" \
                                        functionsAppName="$USER_FUNCTIONS_APP_NAME" >> $LOGFILE 2>&1

retval=$?
if [ $retval -ne 0 ]; then
    quit $retval
fi
echo "Resource template deployed"

echo "Creating storage account ..."
az storage account create --name "$USER_STORAGE_ACCOUNT" \
                          --location "$AZURE_LOCATION" \
                          --resource-group "$USER_RESOURCE_GROUP" \
                          --sku Standard_LRS >> $LOGFILE 2>&1
retval=$?
if [ $retval -ne 0 ]; then
    quit $retval
fi
echo "Storage account $USER_STORAGE_ACCOUNT created"

echo "Creating functions application ..."
az functionapp create --resource-group $USER_RESOURCE_GROUP \
                      --consumption-plan-location $AZURE_LOCATION \
                      --runtime dotnet --functions-version 3 \
                      --name $USER_FUNCTIONS_APP_NAME \
                      --storage-account $USER_STORAGE_ACCOUNT >> $LOGFILE 2>&1
retval=$?
if [ $retval -ne 0 ]; then
    quit $retval
fi
echo "Functions application $USER_FUNCTIONS_APP_NAME created"


echo "Creating and setting authorization rule on namespace $USER_LEFT_NAMESPACE_NAME ..."
az eventhubs eventhub authorization-rule create \
                          --resource-group $USER_RESOURCE_GROUP \
                          --namespace-name $USER_LEFT_NAMESPACE_NAME \
                          --eventhub-name telemetry \
                          --name replication-listen \
                          --rights listen >> $LOGFILE 2>&1
retval=$?
if [ $retval -ne 0 ]; then
    quit $retval
fi

cxnstring_left=$(az eventhubs eventhub authorization-rule keys list \
                    --resource-group $USER_RESOURCE_GROUP \
                    --namespace-name $USER_LEFT_NAMESPACE_NAME \
                    --eventhub-name telemetry \
                    --name replication-listen \
                    --output=json | jq -r .primaryConnectionString) 
retval=$?
if [ $retval -ne 0 ]; then
    quit $retval
fi

az functionapp config appsettings set --name $USER_FUNCTIONS_APP_NAME \
                    --resource-group $USER_RESOURCE_GROUP \
                    --settings "telemetry-source-connection=$cxnstring_left" >> $LOGFILE 2>&1
retval=$?
if [ $retval -ne 0 ]; then
    quit $retval
fi
echo "Authorization rule set"

echo "Setting the consumer group name"
az functionapp config appsettings set --name $USER_FUNCTIONS_APP_NAME \
                    --resource-group $USER_RESOURCE_GROUP \
                    --settings "telemetry-source-consumergroup=$USER_FUNCTIONS_APP_NAME.telemetry" >> $LOGFILE 2>&1
retval=$?
if [ $retval -ne 0 ]; then
    quit $retval
fi
echo "Consumer group name set"

echo "Creating and setting authorization rule on namespace $USER_RIGHT_NAMESPACE_NAME ..."
az eventhubs eventhub authorization-rule create \
                          --resource-group $USER_RESOURCE_GROUP \
                          --namespace-name $USER_RIGHT_NAMESPACE_NAME \
                          --eventhub-name telemetry \
                          --name replication-send \
                          --rights send >> $LOGFILE 2>&1
retval=$?
if [ $retval -ne 0 ]; then
    quit $retval
fi

cxnstring_right=$(az eventhubs eventhub authorization-rule keys list \
                    --resource-group $USER_RESOURCE_GROUP \
                    --namespace-name $USER_RIGHT_NAMESPACE_NAME \
                    --eventhub-name telemetry \
                    --name replication-send \
                    --output=json | jq -r .primaryConnectionString)
retval=$?
if [ $retval -ne 0 ]; then
    quit $retval
fi

az functionapp config appsettings set --name $USER_FUNCTIONS_APP_NAME \
                    --resource-group $USER_RESOURCE_GROUP \
                    --settings "telemetry-target-connection=$cxnstring_right" >> $LOGFILE 2>&1

retval=$?
if [ $retval -ne 0 ]; then
    quit $retval
fi
echo "Authorization rule set"

bash ./build_functionapp.sh

echo "Publishing functions app $USER_FUNCTIONS_APP_NAME ..."
func azure functionapp publish "$USER_FUNCTIONS_APP_NAME" --force >> $LOGFILE 2>&1
retval=$?
if [ $retval -ne 0 ]; then
    quit $retval
fi
echo "Functions app deployed"

popd > /dev/null

pushd "$DIR/EventHubCopyValidation" > /dev/null
echo "Building validation app ..."
dotnet build >> $LOGFILE 2>&1
echo "Running validation app ..."

cxnstring_left=$(az eventhubs namespace authorization-rule keys list \
                    --resource-group $USER_RESOURCE_GROUP \
                    --namespace-name $USER_LEFT_NAMESPACE_NAME \
                    --name RootManageSharedAccessKey \
                    --output=json | jq -r .primaryConnectionString)
cxnstring_right=$(az eventhubs namespace authorization-rule keys list \
                    --resource-group $USER_RESOURCE_GROUP \
                    --namespace-name $USER_RIGHT_NAMESPACE_NAME \
                    --name RootManageSharedAccessKey \
                    --output=json | jq -r .primaryConnectionString)

dotnet bin/Debug/netcoreapp3.1/EventHubCopyValidation.dll \
   -t "$cxnstring_left" -s "$cxnstring_right" \
   -et telemetry -es telemetry -cg '\$Default' >> $LOGFILE 2>&1

retval=$?
if [ $retval -ne 0 ]; then
    quit $retval
fi
echo "Validation done"

echo "Deleting resource group ..."
az group delete --name $USER_RESOURCE_GROUP --yes >> $LOGFILE 2>&1
echo "Resource group deleted"

popd > /dev/null
popd > /dev/null

