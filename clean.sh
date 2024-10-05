#!/bin/bash
rm -r termux* 2>/dev/null
rm *.apk 2>/dev/null
if docker container ls | grep termux-package-builder >/dev/null
then
    docker container stop termux-package-builder >/dev/null
fi
if docker container ls -a | grep termux-package-builder >/dev/null
then
    docker container rm termux-package-builder >/dev/null
fi