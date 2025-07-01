#!/bin/bash
set -euxo pipefail

# Determine the directory where the script resides
SCRIPT_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
ROOT_DIR=${SCRIPT_DIR}/..
TOOLS_DIR=${ROOT_DIR}/tools
# Base directory for downloads and builds on /dev/shmem
BASE_DIR="/dev/shm/scorep_build"
mkdir -p "$BASE_DIR" "$TOOLS_DIR"

# -------------------------------
# Score-P configuration
# -------------------------------
SCOREP_VERSION="9.1"
SCOREP_TARBALL_URL="https://perftools.pages.jsc.fz-juelich.de/cicd/scorep/tags/scorep-${SCOREP_VERSION}/scorep-${SCOREP_VERSION}.tar.gz"
SCOREP_TARBALL_NAME="scorep-${SCOREP_VERSION}.tar.gz"
SCOREP_SRC_DIR="${BASE_DIR}/scorep_source"

# -----------------------------------------
# Step 0: Download and extract Score-P source
# -----------------------------------------
if [ ! -d "${SCOREP_SRC_DIR}" ]; then
  echo "Downloading and extracting Score-P (${SCOREP_VERSION})..."
  mkdir -p "${SCOREP_SRC_DIR}"
  cd "$BASE_DIR"
  wget "$SCOREP_TARBALL_URL" -O "$SCOREP_TARBALL_NAME"
  tar -xf "$SCOREP_TARBALL_NAME" -C "${SCOREP_SRC_DIR}" --strip-components=1
  cd "${SCRIPT_DIR}"
else
  echo "Score-P source already exists at ${SCOREP_SRC_DIR}"
fi

for toolchain in "${ROOT_DIR}"/toolchains/* ; do

	source "$toolchain"
	echo "Evaluating Toolchain '${TOOLCHAIN:?}'"

	SCOREP_BUILD_DIR="${BASE_DIR}/scorep_${TOOLCHAIN:?}"
	SCOREP_INSTALL_DIR="${TOOLS_DIR}/scorep_${TOOLCHAIN:?}"
	
	if [ ! -d "${SCOREP_INSTALL_DIR:?}" ]; then
	  echo "Building and installing Score-P..."
	  rm -rf "${SCOREP_BUILD_DIR:?}"
	  mkdir -p "${SCOREP_BUILD_DIR:?}"
	  cd "${SCOREP_BUILD_DIR:?}"
	  "${SCOREP_SRC_DIR}"/configure --prefix="${SCOREP_INSTALL_DIR:?}"  \
	    --without-shmem \
	    --with-mpi=${SCOREP_MPI:?} \
	    --with-libgotcha=download \
	    --with-libunwind=download \
	    --with-libbfd=download \
	    --with-nocross-compiler-suite=${SCOREP_NOCROSS_COMPILER:?}

	  make -j 16
	  make install
	  cd "${SCRIPT_DIR:?}"
	  rm -rf "${SCOREP_BUILD_DIR:?}"
	else
	  echo "Score-P already installed at ${SCOREP_INSTALL_DIR:?}"
	fi

	echo "Build Successful"
done
