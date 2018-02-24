#Write-Host $PSScriptRoot

$Dest=$pwd
echo $PSScriptRoot > $Dest/custompios_path_win
<##!/bin/bash

# Distro Path
DEST=$PWD
if [ ! -z $1 ]; then
    DEST=$1
fi
# CustomPiOS path
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

echo "${DIR}" > ${DEST}/custompios_path
#>