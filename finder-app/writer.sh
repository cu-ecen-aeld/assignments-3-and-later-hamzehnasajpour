#!/bin/sh

if [ "$#" -ne 2 ]; then
    echo "Illegal number of parameters"
    return 1
fi

writefile=$1
writestr=$2

dirname=$(dirname $writefile)
mkdir -p $dirname

echo $writestr > $writefile
if [ ! -f $writefile ]; then
  return 1
fi