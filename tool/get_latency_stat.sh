# Copyright (c) 2017 Takayuki Imada <takayuki.imada@gmail.com>
#
# Permission to use, copy, modify, and distribute this software for any
# purpose with or without fee is hereby granted, provided that the above
# copyright notice and this permission notice appear in all copies.
#
# THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
# WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
# MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
# ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
# WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
# ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
# OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.

#! /bin/bash

FILENAME=${1}
FILEEXT="${FILENAME##*.}"

if [ ${FILEEXT} = "json" ];
then
	BASENAME="`basename ${FILENAME} .json`"
	NUM_ELEMENTS=`cat ${FILENAME} | jq "[.records[0].latency[]] | length"`

	# Calculate 50, 90 and 99 percentile values
	if [ $((${NUM_ELEMENTS}%2)) -eq 0 ];
	then
		P50_L=`cat ${FILENAME} | jq "[.records[0].latency[]] | sort | .[$((${NUM_ELEMENTS}/2))]"`
		P50_H=`cat ${FILENAME} | jq "[.records[0].latency[]] | sort | .[$((${NUM_ELEMENTS}/2+1))]"`
		P50_LATENCY=`echo "scale=0; (${P50_L} + ${P50_H}) / 2 / 1000" | bc`
	else
		P50_LATENCY=`cat ${FILENAME} | jq "[.records[0].latency[]] | sort | .[$((${NUM_ELEMENTS}/2))]"`
	fi
	P90_L=`cat ${FILENAME} | jq "[.records[0].latency[]] | sort | .[$((${NUM_ELEMENTS}*90/100))]"`
	P90_H=`cat ${FILENAME} | jq "[.records[0].latency[]] | sort | .[$((${NUM_ELEMENTS}*90/100+1))]"`
	P90_LATENCY=`echo "scale=0; (${P90_L} + ${P90_H}) / 2 / 1000" | bc`
	P99_L=`cat ${FILENAME} | jq "[.records[0].latency[]] | sort | .[$((${NUM_ELEMENTS}*99/100))]"`
	P99_H=`cat ${FILENAME} | jq "[.records[0].latency[]] | sort | .[$((${NUM_ELEMENTS}*99/100+1))]"`
	P99_LATENCY=`echo "scale=0; (${P99_L} + ${P99_H}) / 2 / 1000" | bc`

	# Get min, max, and average values
	MIN_LATENCY_N=`cat ${FILENAME} | jq "[.records[0].latency[]] | min"`
	MAX_LATENCY_N=`cat ${FILENAME} | jq "[.records[0].latency[]] | max"`
	SUM_LATENCY_N=`cat ${FILENAME} | jq "[.records[0].latency[]] | add"`
	MIN_LATENCY=`echo "scale=0; ${MIN_LATENCY_N} / 1000" | bc`
	MAX_LATENCY=`echo "scale=0; ${MAX_LATENCY_N} / 1000" | bc`
	SUM_LATENCY=`echo "scale=0; ${SUM_LATENCY_N} / 1000" | bc`
	MEAN_LATENCY=`echo "scale=2; ${SUM_LATENCY} / ${NUM_ELEMENTS}" | bc`

	# Get evaluation environments
	GUEST=`cat ${FILENAME} | jq ".guest"`
	PLATFORM=`cat ${FILENAME} | jq ".platform"`
	COMPILER=`cat ${FILENAME} | jq ".compiler"`

	# Generate a JSON file name
	JSONFILE="`echo ${BASENAME}_summary.json | sed -e s/pp/latency/g`"

elif [ ${FILEEXT} = "log" ];
then
	BASENAME="`basename ${FILENAME} .log`"

	# Get 50, 90 and 99 percentile values
	P50_LATENCY=`grep '^P50_LATENCY' ${FILENAME} | cut -d'=' -f 2`
	P90_LATENCY=`grep '^P90_LATENCY' ${FILENAME} | cut -d'=' -f 2`
	P99_LATENCY=`grep '^P99_LATENCY' ${FILENAME} | cut -d'=' -f 2`

	# Get min, max, and average values
	MIN_LATENCY=`grep '^MIN_LATENCY' ${FILENAME} | cut -d'=' -f 2`
	MAX_LATENCY=`grep '^MAX_LATENCY' ${FILENAME} | cut -d'=' -f 2`
	MEAN_LATENCY=`grep '^MEAN_LATENCY' ${FILENAME} | cut -d'=' -f 2`

	# Get evaluation environments
	GUEST="\"`grep '^GUEST' ${FILENAME} | cut -d'=' -f 2`\""
	PLATFORM="\"`grep '^PLATFORM' ${FILENAME} | cut -d'=' -f 2`\""
	COMPILER="\"`grep '^COMPILER' ${FILENAME} | cut -d'=' -f 2`\""

	# Generate a JSON file name
	JSONFILE="`echo ${BASENAME} | sed -e s/client/summary/g`.json"
fi

CSVFILE="${BASENAME}.csv"

# Generate a json file
echo -n "{ \"guest\": ${GUEST}, \"platform\": ${PLATFORM}, \"compiler\": ${COMPILER}, \"50percentile\": ${P50_LATENCY}, \"90percentile\": ${P90_LATENCY}, \"99percentile\": ${P99_LATENCY}, \"min_latency\": ${MIN_LATENCY}, \"max_latency\": ${MAX_LATENCY}, \"average_latency\": ${MEAN_LATENCY} }" > ${JSONFILE}

# Print the stats on your screen
echo "Guest:${GUEST}, Platform:${PLATFORM}, Compiler:${COMPILER}"
echo "P50_LATENCY,P90_LATENCY,P99_LATENCY,MIN_LATENCY,MAX_LATENCY,MEAN_LATENCY"
echo "${P50_LATENCY},${P90_LATENCY},${P99_LATENCY},${MIN_LATENCY},${MAX_LATENCY},${MEAN_LATENCY}"
