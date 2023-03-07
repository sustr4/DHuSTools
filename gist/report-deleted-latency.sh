#!/bin/bash
# Lists all deleted products reported by the remote site

	URL="https://fe1.dhr.cesnet.cz"
	UPWD="-n"
	NOW=`date -d 'yesterday 00:00:00' "+%s"`
	START=1659304800 # Start from 1st August 2022

	SSTRING=`date -d @$START "+%Y-%m-%dT%H:%M:%S.000"`
	let ETIME=$START+86400
	ESTRING=`date -d @$NOW "+%Y-%m-%dT%H:%M:%S.000"`
	PAGESIZE=100
	SKIP=0

	

	let COUNT=$PAGESIZE+1
	while [ $COUNT -gt $PAGESIZE ]; do
		COUNT=0
		SEG=`curl -sS $UPWD ${URL}/odata/v1/DeletedProducts?%24format=text/csv\&%24select=Name,IngestionDate,CreationDate\&%24skip=$SKIP\&%24top=$PAGESIZE\&%24filter=CreationDate%20gt%20datetime%27${SSTRING}%27%20and%20CreationDate%20lt%20datetime%27${ESTRING}%27`
		while read -r line; do
			if [ $COUNT -ne 0 ]; then
				echo $line;
			fi
			let COUNT=$COUNT+1
		done <<< $SEG
		let SKIP=$SKIP+$PAGESIZE
	done

