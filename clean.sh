#!/bin/bash
rm -r termux*
rm *.apk
if docker container ls | grep termux-package-builder
then
    docker container stop termux-package-builder
fi
if docker container ls -a | grep termux-package-builder
then
    docker container rm termux-package-builder
fi