#!/bin/sh

if [ "$#" -ne 2 ]; then
    echo "Illegal number of parameters"
    return 1
fi

path=$1
text=$2

if [ ! -d $path ]; then
  echo "$path does not exist."
  return 1
fi
FILES=$(find $path -type f)
X=$(find $path -type f | wc -l)
Y=0

for f in "$FILES"
do
    c=$(cat $f | grep $text | wc -l)
    Y=$(echo "$((c+Y))")
done

echo "The number of files are $X and the number of matching lines are $Y"