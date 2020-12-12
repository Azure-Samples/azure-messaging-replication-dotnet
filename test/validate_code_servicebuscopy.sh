#!/bin/bash

echo "ServiceBusCopy Validation (Code). (Patience! This will take a while!)"

# start in script dir 
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
pushd $DIR  > /dev/null

LOGFILE=$DIR/servicebuscopy_code.log 
rm -f $LOGFILE

USER_SUFFIX=$(date +"%03j%02y%02H%02M%02S")

if [ "$AZURE_LOCATION" == '' ]; then
   AZURE_LOCATION=westeurope
fi

CREATE_RESOURCE_GROUP=false
if [ ! $USER_RESOURCE_GROUP ]; then
   CREATE_RESOURCE_GROUP=true
   USER_RESOURCE_GROUP='sbcopysmp-'$USER_SUFFIX
fi

USER_LEFT_NAMESPACE_NAME='sbcopysmp-left-'$USER_SUFFIX
USER_RIGHT_NAMESPACE_NAME='sbcopysmp-right-'$USER_SUFFIX
USER_FUNCTIONS_APP_NAME='sbcopysmp-'$USER_SUFFIX
USER_STORAGE_ACCOUNT='sbcopysmp'$USER_SUFFIX

quit() {
    echo "error, quitting"
    if [ $CREATE_RESOURCE_GROUP ]; then 
       az group delete --name $USER_RESOURCE_GROUP --yes >> $LOGFILE 2>&1
    fi    
    exit $1
}

# go into project dir
pushd ../functions/code/ServiceBusCopy > /dev/null

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
                                        rightNamespaceName="$USER_RIGHT_NAMESPACE_NAME" >> $LOGFILE 2>&1

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
az servicebus queue authorization-rule create \
                          --resource-group $USER_RESOURCE_GROUP \
                          --namespace-name $USER_LEFT_NAMESPACE_NAME \
                          --queue-name jobs-transfer \
                          --name replication-listen \
                          --rights listen >> $LOGFILE 2>&1
retval=$?
if [ $retval -ne 0 ]; then
    quit $retval
fi

cxnstring_left=$(az servicebus queue authorization-rule keys list \
                    --resource-group $USER_RESOURCE_GROUP \
                    --namespace-name $USER_LEFT_NAMESPACE_NAME \
                    --queue-name jobs-transfer \
                    --name replication-listen \
                    --output=json | jq -r .primaryConnectionString) 
retval=$?
if [ $retval -ne 0 ]; then
    quit $retval
fi

regex_strip_entity_path="(.*);EntityPath=.*;*(.*)$"
if [[ $cxnstring_left =~ $regex_strip_entity_path ]]; then
   cxnstring_left="${BASH_REMATCH[1]};${BASH_REMATCH[2]}"
fi

az functionapp config appsettings set --name $USER_FUNCTIONS_APP_NAME \
                    --resource-group $USER_RESOURCE_GROUP \
                    --settings "jobs-transfer-source-connection=$cxnstring_left" >> $LOGFILE 2>&1
retval=$?
if [ $retval -ne 0 ]; then
    quit $retval
fi
echo "Authorization rule set"

echo "Creating and setting authorization rule on namespace $USER_RIGHT_NAMESPACE_NAME ..."
az servicebus queue authorization-rule create \
                          --resource-group $USER_RESOURCE_GROUP \
                          --namespace-name $USER_RIGHT_NAMESPACE_NAME \
                          --queue-name jobs \
                          --name replication-send \
                          --rights send >> $LOGFILE 2>&1
retval=$?
if [ $retval -ne 0 ]; then
    quit $retval
fi

cxnstring_right=$(az servicebus queue authorization-rule keys list \
                    --resource-group $USER_RESOURCE_GROUP \
                    --namespace-name $USER_RIGHT_NAMESPACE_NAME \
                    --queue-name jobs \
                    --name replication-send \
                    --output=json | jq -r .primaryConnectionString)
retval=$?
if [ $retval -ne 0 ]; then
    quit $retval
fi

regex_strip_entity_path="(.*);EntityPath=.*;*(.*)$"
if [[ $cxnstring_right =~ $regex_strip_entity_path ]]; then
   cxnstring_right="${BASH_REMATCH[1]};${BASH_REMATCH[2]}"
fi

az functionapp config appsettings set --name $USER_FUNCTIONS_APP_NAME \
                    --resource-group $USER_RESOURCE_GROUP \
                    --settings "jobs-target-connection=$cxnstring_right" >> $LOGFILE 2>&1

retval=$?
if [ $retval -ne 0 ]; then
    quit $retval
fi
echo "Authorization rule set"


echo "Publishing functions app $USER_FUNCTIONS_APP_NAME ..."
func azure functionapp publish "$USER_FUNCTIONS_APP_NAME" --force >> $LOGFILE 2>&1
retval=$?
if [ $retval -ne 0 ]; then
    quit $retval
fi
echo "Functions app deployed"

popd > /dev/null

pushd "$DIR/ServiceBusCopyValidation" > /dev/null
echo "Building validation app ..."
dotnet build >> $LOGFILE 2>&1
echo "Running validation app ..."

cxnstring_left=$(az servicebus namespace authorization-rule keys list \
                    --resource-group $USER_RESOURCE_GROUP \
                    --namespace-name $USER_LEFT_NAMESPACE_NAME \
                    --name RootManageSharedAccessKey \
                    --output=json | jq -r .primaryConnectionString)
cxnstring_right=$(az servicebus namespace authorization-rule keys list \
                    --resource-group $USER_RESOURCE_GROUP \
                    --namespace-name $USER_RIGHT_NAMESPACE_NAME \
                    --name RootManageSharedAccessKey \
                    --output=json | jq -r .primaryConnectionString)

az webapp log tail --resource-group $USER_RESOURCE_GROUP --name $USER_FUNCTIONS_APP_NAME >> $LOGFILE 2>&1 &

dotnet bin/Debug/netcoreapp3.1/ServiceBusCopyValidation.dll \
   -t "$cxnstring_left" -s "$cxnstring_right" \
   -qt jobs-transfer -qs jobs >> $LOGFILE 2>&1

retval=$?
if [ $retval -ne 0 ]; then
    echo -t "$cxnstring_left" -s "$cxnstring_right"
    exit 1
fi
echo "Validation done"

echo "Deleting resource group ..."
az group delete --name $USER_RESOURCE_GROUP --yes >> $LOGFILE 2>&1
echo "Resource group deleted"

popd > /dev/null
popd > /dev/null

