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
PROTOBUF_NAME="${NAME_START}com_google_protobuf${QUOTE_END}"
PROTOBUF_REGEX="${ARCHIVE_HEADER}${ANY}${PROTOBUF_NAME}${ANY}${FOOTER}"
TF_DIR="/tensorflow"
DOWNLOAD_DIR="download"
INSTALL_DIR="/usr/local"
CMAKE_DIR="."


PROTOBUF_HASH_REGEX="sha256\s*=\s*\\\"${ANY_HEX}\\\"\s*"
HASH_SED="s/\s*sha256${QUOTE_START}\(${ANY_HEX}\)\\\"\s*/\1/p"
ARCHIVE_HASH_SED="s/\s*${PROTOBUF_VERSION_LABEL}${QUOTE_START}\(${ANY_HEX}\)\\\"\s*/\1/p"

PROTOBUF_TEXT=$(grep -Pzo ${PROTOBUF_REGEX} ${TF_DIR}/tensorflow/workspace.bzl)
PROTOBUF_URLS_TEXT=$(echo ${PROTOBUF_TEXT} | grep -Pzo "urls\s=\s\[[^\)]*\]")
PROTOBUF_HASH_TEXT=$(echo ${PROTOBUF_TEXT} | grep -Pzo ${PROTOBUF_HASH_REGEX})

PROTOBUF_HASH=$(echo "${PROTOBUF_HASH_TEXT}" | sed -n ${HASH_SED})
echo "protobuf_hash: ${PROTOBUF_HASH}"
PROTOBUF_URL=$(echo "${PROTOBUF_URLS_TEXT}" | grep -o "\"http[a-zA-Z0-9:/.]*\"" | head -1 | sed "s/\"//g")
echo "protobuf_url: ${PROTOBUF_URL}"
PROTOBUF_URLS[0]=${PROTOBUF_URL}

PROTOBUF_ARCHIVE_HASH=$(echo ${PROTOBUF_URL} | sed "s/http[a-zA-Z0-9:\/.]*\/google\/protobuf\/archive\///" | sed "s/.tar.gz//")
echo "protobuf_archive_hash: ${PROTOBUF_ARCHIVE_HASH}"
echo "Downlaoding Protobuf to ${DOWNLOAD_DIR}"
mkdir -p ${DOWNLOAD_DIR}
cd ${DOWNLOAD_DIR}

rm -rf protobuf-${PROTOBUF_ARCHIVE_HASH}
rm -f ${PROTOBUF_ARCHIVE_HASH}.tar.gz*
wget ${PROTOBUF_URL}

tar -zxf ${PROTOBUF_ARCHIVE_HASH}.tar.gz
cd protobuf-${PROTOBUF_ARCHIVE_HASH}



# configure
./autogen.sh
./configure --prefix=${INSTALL_DIR}
echo "Starting protobuf install."
# build and install
make -j$(nproc)
make check || exit 1
make install
if [ `id -u` == 0 ]; then
	ldconfig
fi

cd ..

rm ${PROTOBUF_ARCHIVE_HASH}.tar.gz
cd ..

echo "Protobuf has been installed to ${INSTALL_DIR}"

# try to locate protobuf in INSTALL_DIR
if [ -d "${INSTALL_DIR}/include/google/protobuf" ]; then
       	echo -e "${GREEN}Found Protobuf in ${INSTALL_DIR}${NO_COLOR}"
else
    	echo -e "${YELLOW}Warning: Could not find Protobuf in ${INSTALL_DIR}${NO_COLOR}"
fi



PROTOBUF_OUT="${CMAKE_DIR}/Protobuf_VERSION.cmake"
echo "set(Protobuf_URL ${PROTOBUF_URL})" > ${PROTOBUF_OUT}

echo "set(Protobuf_INSTALL_DIR ${INSTALL_DIR})" >> ${PROTOBUF_OUT}
echo "Wrote Protobuf_VERSION.cmake to ${CMAKE_DIR}"
cp FindProtobuf.cmake ${CMAKE_DIR}
echo "Copied FindProtobuf.cmake to ${CMAKE_DIR}"

echo -e "${GREEN}Done${NO_COLOR}"
exit 0
