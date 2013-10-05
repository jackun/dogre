#!/usr/bin/bash

if [[ $# -eq 0 ]]
then
	# Because this script is too dumb 
	echo Generate '_package.d' file per directory \(actually printed to stdout\), pass a/b/*.d as argument.
	exit 1
fi

echo -e "public\\n{"

for i in $@;do

	if [[ "$i" == *_package.d ]]
	then
		continue
	fi

	i=${i%%.d}
	MODULE=`dirname $i|sed 's/\//\./g'`
	FILE=`basename $i`

	if [ "x$MODULE" == "x." ]; then
		MODULE=$FILE
	else
		MODULE=$MODULE.$FILE
	fi

	echo -e \\timport $MODULE\;

done

echo "}"

