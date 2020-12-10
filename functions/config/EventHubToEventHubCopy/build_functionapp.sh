#!/bin/bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
pushd $DIR 

if [[ -d bin ]]; then  
    rm -rf bin
fi

dotnet build "..\..\..\src\Azure.Messaging.Replication\Azure.Messaging.Replication.csproj" -o dotnet 2>&1 > build.log
mv --force $DIR/dotnet/bin $DIR/bin   

# Sync the required extensions into the build
func extensions sync --csx 2>&1 >> build.log
func extensions install 2>&1 >> build.log
rm extensions.csproj 2>&1 >> build.log

popd
