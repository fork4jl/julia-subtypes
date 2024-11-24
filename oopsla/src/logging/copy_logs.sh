#!/bin/bash

###########
#
# Run from the dir with project directories
# 1st argument: output directory
#
###########

OUT=$1

if [ -z $OUT ]
then 
    echo "Output directory is not provided as a script argument"
    exit 1
fi

if [[ -d $OUT ]]; then
    rm -rf $OUT
fi

mkdir $OUT
find . \
        -maxdepth 2 \
        -type f \
        \( -name "*.jl" -or -name "*.json" -or -name "*.txt" \) \
        -exec cp --parents {} $OUT \;

