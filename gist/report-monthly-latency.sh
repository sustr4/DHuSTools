#!/bin/bash

BROWSER="echo"
#BROWSER="google-chrome"
#BROWSER="forefox"

if [ "$1" == "" ]; then
	1>&2 echo "Specify first reporting month as argument (e.g., 2022-08)"
	exit 1
fi

if [ "$2" == "" ]; then
	SYN="0"
	1>&2 echo "Showing for synchronizer ${SYN}. Give a second argument as synchronizer no. to select another."
else
	SYN=$2
fi


for count in {0..5}; do

	countPlus=$(( $count + 1 ))

	FROM=`date +%s -d "$1-01 + $count months"`
	if [ $? -ne 0 ]; then
		1>&2 echo "Failed using \"$1\" as starting month. \"$1-01\" is not a valid date."
		exit 1
	fi

	TILL=`date +%s -d "$1-01 + $countPlus months"`

	${BROWSER} "https://nagios.cesnet.cz/pnp4nagios/index.php/zoom?host=fe1.dhr.cesnet.cz&srv=Product_Latency&view=3&source=${SYN}&end=${TILL}&start=${FROM}&graph_width=1024&graph_height=768"

done

