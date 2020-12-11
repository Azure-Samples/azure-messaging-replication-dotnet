#!/bin/bash

rm -f *.log

bash validate_code_eventhubcopy.sh
retval=$?
if [ $retval -ne 0 ]; then
    exit $retval
fi
bash validate_config_eventhubcopy.sh
retval=$?
if [ $retval -ne 0 ]; then
    exit $retval
fi

bash validate_code_servicebuscopy.sh
retval=$?
if [ $retval -ne 0 ]; then
    exit $retval
fi
bash validate_config_servicebuscopy.sh
retval=$?
if [ $retval -ne 0 ]; then
    exit $retval
fi

bash validate_code_eventhubmerge.sh
retval=$?
if [ $retval -ne 0 ]; then
    exit $retval
fi

bash validate_code_servicebusallactive.sh
retval=$?
if [ $retval -ne 0 ]; then
    exit $retval
fi

bash validate_code_servicebusactivepassive.sh
retval=$?
if [ $retval -ne 0 ]; then
    exit $retval
fi

