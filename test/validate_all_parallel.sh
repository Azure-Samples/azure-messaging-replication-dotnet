#!/bin/bash

rm -f *.log

bash validate_code_eventhubcopy.sh &
bash validate_config_eventhubcopy.sh &
bash validate_code_servicebuscopy.sh &
bash validate_config_servicebuscopy.sh &
bash validate_code_eventhubmerge.sh &
bash validate_code_servicebusallactive.sh &
bash validate_code_servicebusactivepassive.sh &
