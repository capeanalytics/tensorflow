#!/usr/bin/env bash
RED="\033[1;31m"
YELLOW="\033[1;33m"
GREEN="\033[0;32m"
NO_COLOR="\033[0m"


ANY="[^\)]*"
ANY_NO_QUOTES="[^\)\\\"]*"
ANY_HEX="[a-fA-F0-9]*"
ARCHIVE_HEADER="tf_http_archive\(\s*"
NAME_START="name\s*=\s*\\\""
QUOTE_START="\s*=\s*\\\""
QUOTE_END="\\\"\s*,\s*"
FOOTER="\)"
EIGEN_NAME="${NAME_START}eigen_archive${QUOTE_END}"
EIGEN_REGEX="${ARCHIVE_HEADER}${ANY}${EIGEN_NAME}${ANY}${FOOTER}"
TF_DIR="/tensorflow"
DOWNLOAD_DIR="download"
INSTALL_DIR="/usr/local"
CMAKE_DIR="."


EIGEN_HASH_REGEX="sha256\s*=\s*\\\"${ANY_HEX}\\\"\s*"
HASH_SED="s/\s*sha256${QUOTE_START}\(${ANY_HEX}\)\\\"\s*/\1/p"
ARCHIVE_HASH_SED="s/\s*${EIGEN_VERSION_LABEL}${QUOTE_START}\(${ANY_HEX}\)\\\"\s*/\1/p"

EIGEN_TEXT=$(grep -Pzo ${EIGEN_REGEX} ${TF_DIR}/tensorflow/workspace.bzl)
EIGEN_URLS_TEXT=$(echo ${EIGEN_TEXT} | grep -Pzo "urls\s=\s\[[^\)]*\]")
EIGEN_HASH_TEXT=$(echo ${EIGEN_TEXT} | grep -Pzo ${EIGEN_HASH_REGEX})

EIGEN_HASH=$(echo "${EIGEN_HASH_TEXT}" | sed -n ${HASH_SED})
echo "eigen_hash: ${EIGEN_HASH}"
EIGEN_URL=$(echo "${EIGEN_URLS_TEXT}" | grep -o "\"http[a-zA-Z0-9:/.]*\"" | head -1 | sed "s/\"//g")
echo "eigen_url: ${EIGEN_URL}"
EIGEN_URLS[0]=${EIGEN_URL}

EIGEN_ARCHIVE_HASH=$(echo ${EIGEN_URL} | sed "s/http[a-zA-Z0-9:\/.]*\/eigen\/eigen\/get\///" | sed "s/.tar.gz//")
echo "eigen_archive_hash: ${EIGEN_ARCHIVE_HASH}"
echo "Downlaoding Eigen to ${DOWNLOAD_DIR}"
mkdir -p ${DOWNLOAD_DIR}
cd ${DOWNLOAD_DIR}

rm -rf eigen-eigen-${EIGEN_ARCHIVE_HASH}
rm -f ${EIGEN_ARCHIVE_HASH}.tar.gz*
wget ${EIGEN_URL}

tar -zxf ${EIGEN_ARCHIVE_HASH}.tar.gz
cd eigen-eigen-${EIGEN_ARCHIVE_HASH}
# create build directory and build
mkdir build
cd build
cmake -DCMAKE_INSTALL_PREFIX=${INSTALL_DIR} ..
make -j$(nproc)
make install
echo "Installation complete"
echo "Cleaning up..."
# clean up
cd ../..
rm -rf eigen-eigen-${EIGEN_ARCHIVE_HASH}
rm -f ${EIGEN_ARCHIVE_HASH}.tar.gz*
cd ..

if [ -d "${INSTALL_DIR}/include/eigen/eigen-eigen-${EIGEN_ARCHIVE_HASH}" ]; then
	# this is how eiegn was stored in older version of TensorFlow
        echo -e "${GREEN}Found Eigen in ${INSTALL_DIR}${NO_COLOR}"
elif [ -d "${INSTALL_DIR}/include/eigen3" ]; then
	# this is the new way
	echo -e "${GREEN}Found Eigen in ${INSTALL_DIR}${NO_COLOR}"
	OLD_EIGEN=0
else
	echo -e "${YELLOW}Warning: Could not find Eigen in ${INSTALL_DIR}${NO_COLOR}"
fi

# output Eigen information to file
EIGEN_OUT="${CMAKE_DIR}/Eigen_VERSION.cmake"
echo "set(Eigen_URL ${EIGEN_URL})" > ${EIGEN_OUT}
echo "set(Eigen_ARCHIVE_HASH ${EIGEN_ARCHIVE_HASH})" >> ${EIGEN_OUT}
echo "set(Eigen_HASH SHA256=${EIGEN_HASH})" >> ${EIGEN_OUT}
if [ ${OLD_EIGEN} -eq 1 ]; then
    	echo "set(Eigen_DIR eigen-eigen-${EIGEN_ARCHIVE_HASH})" >> ${EIGEN_OUT}
else
	echo "set(Eigen_DIR eigen3)" >> ${EIGEN_OUT}
fi

echo "set(Eigen_INSTALL_DIR ${INSTALL_DIR})" >> ${EIGEN_OUT}
echo "Eigen_VERSION.cmake written to ${CMAKE_DIR}"
# perform specific operations regarding installation
if [ "${GENERATE_MODE}" == "external" ]; then
	cp ${SCRIPT_DIR}/Eigen.cmake ${CMAKE_DIR}
	echo "Wrote Eigen_VERSION.cmake and Eigen.cmake to ${CMAKE_DIR}"
elif [ "${GENERATE_MODE}" == "installed" ]; then
	cp ${SCRIPT_DIR}/FindEigen.cmake ${CMAKE_DIR}
	echo "FindEigen.cmake copied to ${CMAKE_DIR}"
fi


echo -e "${GREEN}Done${NO_COLOR}"
exit 0
