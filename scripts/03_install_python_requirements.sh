#!/bin/bash
set -euxo pipefail

# Determine the directory where the script resides
SCRIPT_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
ROOT_DIR=${SCRIPT_DIR}/..
TOOLS_DIR=${ROOT_DIR}/tools

mkdir -p "$TOOLS_DIR"

VENV_DIR="${TOOLS_DIR}/venv"

# -----------------------------------------
# Step 0: Download and extract Score-P source
# -----------------------------------------
if [ ! -d "${VENV_DIR}" ]; then
    source ${ROOT_DIR}/toolchains/gompi2024a
    
    echo "Installing to VENV (${VENV_DIR})..."
    
    python3 -m venv ${VENV_DIR}
    source ${VENV_DIR}/bin/activate
    pip3 install --upgrade pip
    
    pip3 install pandas matplotlib numpy

    cd "${SCRIPT_DIR}"
else
    echo "Virtual VENV does already exist ${VENV_DIR}"
fi
