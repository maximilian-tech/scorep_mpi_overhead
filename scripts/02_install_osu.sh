#!/bin/bash
set -euxo pipefail

# Determine the directory where the script resides
SCRIPT_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
ROOT_DIR=${SCRIPT_DIR}/..
TOOLS_DIR=${ROOT_DIR}/tools
# Base directory for downloads and builds on /dev/shmem
BASE_DIR="/dev/shm/osu_build"
mkdir -p "$BASE_DIR" "$TOOLS_DIR"

# -------------------------------
# Score-P configuration
# -------------------------------
OSU_VERSION="7.5-1"
OSU_TARBALL_URL="https://mvapich.cse.ohio-state.edu/download/mvapich/osu-micro-benchmarks-${OSU_VERSION}.tar.gz"
OSU_TARBALL_NAME="osu-micro-benchmarks-${OSU_VERSION}.tar.gz"
OSU_SRC_DIR="${BASE_DIR}/osu_source"

export SCOREP_WRAPPER_INSTRUMENTER_FLAGS="--nocompiler --io=none --thread=none --nokokkos"

# -----------------------------------------
# Step 0: Download and extract Score-P source
# -----------------------------------------
if [ ! -d "${OSU_SRC_DIR}" ]; then
  echo "Downloading and extracting Score-P (${OSU_VERSION})..."
  mkdir -p "${OSU_SRC_DIR}"
  cd "$BASE_DIR"
  wget "$OSU_TARBALL_URL" -O "$OSU_TARBALL_NAME"
  tar -xf "$OSU_TARBALL_NAME" -C "${OSU_SRC_DIR}" --strip-components=1
  cd "${SCRIPT_DIR}"
else
  echo "OSU source already exists at ${OSU_SRC_DIR}"
fi

for toolchain in "${ROOT_DIR}"/toolchains/* ; do
    
    for SCOREP_WRAPPER_VALUE in OFF ON ; do
    
        source "$toolchain"
        echo "Evaluating Toolchain '${TOOLCHAIN:?}'"
        
        # Put Score-P into PATH
        export PATH=${TOOLS_DIR}/scorep_${TOOLCHAIN:?}/bin:$PATH
        
        
        OSU_BUILD_DIR="${BASE_DIR}/osu_${TOOLCHAIN:?}_scorep${SCOREP_WRAPPER_VALUE}"
        OSU_INSTALL_DIR="${TOOLS_DIR}/osu_${TOOLCHAIN:?}_scorep${SCOREP_WRAPPER_VALUE}"
        
        if [ ! -d "${OSU_INSTALL_DIR:?}" ]; then
            echo "Building and installing OSU..."
            rm -rf "${OSU_BUILD_DIR:?}"
            mkdir -p "${OSU_BUILD_DIR:?}"
            cd "${OSU_BUILD_DIR:?}"
            SCOREP_WRAPPER=OFF "${OSU_SRC_DIR}"/configure \
                --prefix="${OSU_INSTALL_DIR:?}"  \
                CC="scorep-${OSU_CC:?}" \
                CXX="scorep-${OSU_CXX:?}"

            SCOREP_WRAPPER=${SCOREP_WRAPPER_VALUE} make -j 8
            SCOREP_WRAPPER=${SCOREP_WRAPPER_VALUE} make install
            cd "${SCRIPT_DIR:?}"
        else
            echo "OSU already installed at ${OSU_INSTALL_DIR:?}"
        fi

        echo "Build Successful"
    done

done
