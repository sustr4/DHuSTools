#!/bin/bash

if [ "$1" == "" ]; then
	1>&2 echo "Specify first reporting month as argument (e.g., 2022-08)"
	exit 1
fi

for count in {0..5}; do

	countPlus=$(( $count + 1 ))

	FROM=`date +%s -d "$1-01 + $count months"`
	if [ $? -ne 0 ]; then
		1>&2 echo "Failed using \"$1\" as starting month. \"$1-01\" is not a valid date."
		exit 1
	fi

	TILL=`date +%s -d "$1-01 + $countPlus months"`
	
	firefox "https://nagios.cesnet.cz/cgi-bin/icinga2-classicui/avail.cgi?t1=${FROM}&t2=${TILL}&show_log_entries=&host=fe1.dhr.cesnet.cz&service=Product+Source+Latency&assumeinitialstates=yes&assumestateretention=yes&assumestatesduringnotrunning=yes&includesoftstates=no&initialassumedhoststate=0&initialassumedservicestate=6&timeperiod=[+Current+time+range+]&backtrack=8"

done

