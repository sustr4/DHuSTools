#!/bin/bash

#DEBUG=1
ID="$1"
HOST="https://dhr1.cesnet.cz/"
declare -A COLLECTION
COLLECTION["S2"]="https://resto.c-scale.zcu.cz/collections/S2-experimental"
COLLECTION["S1"]="https://resto.c-scale.zcu.cz/collections/S1-experimental"
COLLECTION["S3"]="https://resto.c-scale.zcu.cz/collections/S3-experimental"
COLLECTION["S5"]="https://resto.c-scale.zcu.cz/collections/S5-experimental"
TMP="/tmp"
SUCCPREFIX="/var/tmp/register-stac-success-"
ERRPREFIX="/var/tmp/register-stac-error-"

######################################
#
# Initial checks and settings
#
######################################

if [ "${ID}" == "" ]; then
	1>&2 echo $0: No ID specified
	exit 1
fi

RUNDATE=`date +%Y-%m-%d`

######################################
#
# Get metadata from DHuS Database
#
######################################

XML=`curl -n -o - "${HOST}odata/v1/Products(%27${ID}%27)/Nodes"`
TITLE=`echo "${XML}" | sed "s/.*<entry>.*<link href=.Nodes('\([^']*\).*/\1/"`
PREFIX=`echo "${XML}" | sed "s/.*<entry>.*<id>\([^<]*\).*/\1/"`
PRODUCTURL=`echo "${PREFIX}" | sed 's/\\Nodes.*//'`
PLATFORM="${TITLE:0:2}"

1>&2 echo Getting metadata for $TITLE "(ID: ${ID})"
1>&2 echo Download prefix: ${PREFIX}
1>&2 echo Platform prefix: ${PLATFORM}
1>&2 echo Using colection: ${COLLECTION[${PLATFORM}]}

######################################
#
# Extract metadata files (manifests)
#
######################################

ORIGDIR=`pwd`

mkdir -p "${TMP}/register-stac.$$"

cd "${TMP}/register-stac.$$"

mkdir "${TITLE}"

# Get manifest

if [ "$PLATFORM" == "S1" -o "$PLATFORM" == "S2" ]; then
	MANIFEST="${TITLE}/manifest.safe"
	curl -n -o "${MANIFEST}" "${PREFIX}/Nodes(%27manifest.safe%27)/%24value"
elif [ "$PLATFORM" == "S3" -o "$PLATFORM" == "S3p" ]; then
	MANIFEST="${TITLE}/xfdumanifest.xml"
	curl -n -o "${MANIFEST}" "${PREFIX}/Nodes(%27xfdumanifest.xml%27)/%24value"
else
	MANIFEST="${TITLE}"
	rmdir "${TITLE}"
	curl -n -o "${MANIFEST}" "${PREFIX}/%24value"
fi

# download other metadata files line by line (Only for S1 and S2)
if [ "$PLATFORM" == "S1" -o "$PLATFORM" == "S2" ]; then
	cat "${MANIFEST}" | grep 'href=' | grep -E "/MTD_MSIL2A.xml|MTD_MSIL1C.xml|/MTD_TL.xml|annotation/s1a.*xml" | sed 's/.*href="//' | sed 's/".*//' |
	while read file; do
		1>&2 echo Downloading $file
		URL="${PREFIX}/Nodes(%27$(echo $file | sed "s|^\.*\/*||" | sed "s|\/|%27)/Nodes(%27|g")%27)/%24value"
	#	echo $URL
		mkdir -p "${TITLE}/$(dirname ${file})"
		curl -n -o "${TITLE}/${file}" "${URL}"
	done
fi

# create empty directiries stac-tools look into (only S1)
if [ "$PLATFORM" == "S1" ]; then
	mkdir -p "${TITLE}/annotation/calibration"
	mkdir -p "${TITLE}/measurement"
fi


find . 1>&2

######################################
#
# Generate JSON
#
######################################

if [ "$PLATFORM" == "S2" ]; then
	~/.local/bin/stac sentinel2 create-item "${TITLE}" ./
elif [ "$PLATFORM" == "S1" ]; then
	~/.local/bin/stac sentinel1 grd create-item "${TITLE}" ./
elif [ "$PLATFORM" == "S3" ]; then
	~/.local/bin/stac sentinel3 create-item "${TITLE}" ./
elif [ "$PLATFORM" == "S5" ]; then
	~/.local/bin/stac sentinel5p create-item "${TITLE}" ./
fi

######################################
#
# Doctor JSON
#
######################################

file=`ls *.json | head -n 1`
printf "\n" >> "$file" # Poor man's hack to make sure `read` gets all lines
cat "$file" | while IFS= read line; do
	if [[ "$line" =~ .*\"href\":.*\.(SAFE|nc)\".* ]]; then # TODO: Less fragile code
		path=`echo "$line" | sed 's/^[^"]*"href":[^"]*"//' | sed 's/",$//'`
		LEAD=`echo "$line" | sed 's/"href":.*/"href":/'`
		URL="${PRODUCTURL}/Nodes(%27$(echo $path | sed "s|^\.*\/*||" | sed "s|\/|%27)/Nodes(%27|g")%27)/%24value"
		echo "$LEAD \"${URL}\"," >> "new_${file}"

	else # No change
		echo "${line}" >> "new_${file}"
	fi
done


######################################
#
# Upload
#
######################################

curl -n -o output.json -X POST "${COLLECTION[${PLATFORM}]}/items" -H 'Content-Type: application/json' -H 'Accept: application/json' --upload-file "new_${file}"

######################################
#
# Cleanup
#
######################################


#TODO: Add reaction to {"ErrorMessage":"Not Found","ErrorCode":404}

grep '"status":"success"' output.json >/dev/null
if [ $? -eq 0 ]; then
	echo "${ID}" >> "${SUCCPREFIX}${RUNDATE}.csv"
else
	echo "${ID}" >> "${ERRPREFIX}${RUNDATE}.csv"
	DEBUG="1"
fi


cd "${ORIGDIR}"

if [ "$DEBUG" == "" ]; then
	rm -rf "${TMP}/register-stac.$$"
else
	1>&2 echo Artifacts in "${TMP}/register-stac.$$"
fi

