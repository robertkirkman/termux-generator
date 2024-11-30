#!/bin/bash
set -x
rm -rf termux* 2>/dev/null
rm *.apk 2>/dev/null
if docker container ls | grep termux-generator-package-builder >/dev/null
then
    docker container kill termux-generator-package-builder >/dev/null
fi
if docker container ls -a | grep termux-generator-package-builder >/dev/null
then
    docker container rm termux-generator-package-builder >/dev/null
fi
