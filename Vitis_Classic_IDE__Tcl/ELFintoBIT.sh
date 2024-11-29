#!/bin/bash

argWORKSPACE=""
argAPPNAME=""
argOUTPUT=
export ETOB_WORKSPACE=""
export ETOB_APPNAME=""
export ETOB_OUTPUT=""


# detect the absolute directory path of this script
SCRPATH=$(dirname "${BASH_SOURCE[0]}")


# parse the command line arguments
OPTIND=1
while getopts "w:a:o:" callarg
do
    case ${callarg} in
        w)
            argWORKSPACE=${OPTARG}
            export ETOB_WORKSPACE=$argWORKSPACE
            ;;
        a)
            argAPPNAME=${OPTARG}
            export ETOB_APPNAME=$argAPPNAME
            ;;
        o)
            argOUTPUT=${OPTARG}
            export ETOB_OUTPUT=$argOUTPUT
            ;;
        *)
            ;;
    esac
done


# call the tcl script through xsct
echo "Calling  xsct ELFintoBIT.tcl"
if [ -z "$argWORKSPACE" ]; then
    :
else
    echo "    with Vitis workspace path  ${argWORKSPACE}"
fi

if [ -z "$argAPPNAME" ]; then
    :
else
    echo "    with application name  ${argAPPNAME}"
fi

if [ -z "$argOUTPUT" ]; then
    :
else
    echo "    with output bitstream  ${argOUTPUT}"
fi

xsct ${SCRPATH}/ELFintoBIT.tcl
