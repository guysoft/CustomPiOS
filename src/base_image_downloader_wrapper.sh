#!/usr/bin/env bash
set +x
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

source "$DIR/argparse.bash" || exit 1
argparse "$@" <<EOF || exit 1

parser.add_argument('WORKSPACE_SUFFIX', nargs='?', default="default", help="The workspace folder suffix used folder")
parser.add_argument('-s', '--sha256', action='store_true', help='Create a sha256 hash for the .img file in .sha256')
EOF

if [ -z "${CUSTOM_PI_OS_PATH}" ];then
    echo "Error: you must have \${CUSTOM_PI_OS_PATH} set"
    exit 1
fi

# source "${DIST_PATH}/config"
source "${CUSTOM_PI_OS_PATH}/config" "${WORKSPACE_SUFFIX}"

python3 ${CUSTOM_PI_OS_PATH}/custompios_core/base_image_downloader.py "${WORKSPACE_SUFFIX}"

