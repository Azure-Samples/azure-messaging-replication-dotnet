cxnstring="Endpoint=sb://ehcopysmp-left-34620142154.servicebus.windows.net/;SharedAccessKeyName=RootManageSharedAccessKey;SharedAccessKey=cAERQZcX6dgHA3oXhtcPnDl7du3+pCzTNLiCg0lbaq0=;EntityName=foo"
regex="(.*);EntityName=.*;*(.*)$"
if [[ $cxnstring =~ $regex ]]; then
   cxnstring=${BASH_REMATCH[1]}";"${BASH_REMATCH[2]}
fi
echo $cxnstring