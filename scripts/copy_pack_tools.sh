#!/bin/bash
cd `dirname $0`
LICHEE_DIR=/pub/release/a20-orig/a20/lichee/
DST=../allwinner-tools/livesuit/a20

rm ${DST} -rf
mkdir -p ${DST}/
cp ${LICHEE_DIR}/tools/pack/chips/sun7i/eFex ${DST} -ar
cp ${LICHEE_DIR}/tools/pack/chips/sun7i/eGon ${DST} -ar
cp ${LICHEE_DIR}/tools/pack/chips/sun7i/wboot ${DST} -ar

cp ${LICHEE_DIR}/tools/pack/pctools/linux/eDragonEx ${DST} -ar
cp ${LICHEE_DIR}/tools/pack/pctools/linux/fsbuild200 ${DST} -ar
cp ${LICHEE_DIR}/tools/pack/pctools/linux/mod_update ${DST} -ar

cp ${LICHEE_DIR}/tools/pack/chips/sun7i/configs/linux/default ${DST} -ar
