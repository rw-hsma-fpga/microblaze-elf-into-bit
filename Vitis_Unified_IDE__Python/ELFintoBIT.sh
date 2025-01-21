#!/bin/bash

# detect the absolute directory path of this script
SCRPATH=$(dirname "${BASH_SOURCE[0]}")
SCRPATH=$(realpath "${SCRPATH}")

command="ELFintoBIT.py"

for i in "$@"
do
    if [ "$i" != "0" ]
    then
        ALLARGS="${ALLARGS} ${i}"
    fi  
done

echo "Calling:"
echo "vitis -s ${SCRPATH}/${command} ${ALLARGS}"
vitis -s ${SCRPATH}/${command} ${ALLARGS}