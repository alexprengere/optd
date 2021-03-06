#!/bin/bash
#
# Four parameters are optional for this script:
# - the first file of geographical coordinates (data dump from Geonames)
# - the second file of geographical coordinates (ORI-maintained POR)
# - the airport (ORI-maintained) popularity details
# - the minimal distance (in km) triggering a difference
#

##
# Temporary path
TMP_DIR="/tmp/por"

##
# Path of the executable: set it to empty when this is the current directory.
EXEC_PATH=`dirname $0`
CURRENT_DIR=`pwd`
if [ ${CURRENT_DIR} -ef ${EXEC_PATH} ]
then
	EXEC_PATH="."
	TMP_DIR="."
fi
EXEC_PATH="${EXEC_PATH}/"
TMP_DIR="${TMP_DIR}/"

if [ ! -d ${TMP_DIR} -o ! -w ${TMP_DIR} ]
then
	\mkdir -p ${TMP_DIR}
fi

##
# Log level
LOG_LEVEL=3

##
# ORI path
OPTD_DIR_DIR=${EXEC_PATH}../
ORI_DIR=${OPTD_DIR_DIR}ORI/

##
# Geo data files
GEO_FILE_1_RAW_FILENAME=dump_from_geonames.csv
GEO_FILE_1_FILENAME=wpk_${GEO_FILE_1_RAW_FILENAME}
GEO_FILE_1_SORTED=sorted_${GEO_FILE_1_FILENAME}
GEO_FILE_1_SORTED_CUT=cut_${GEO_FILE_1_SORTED}
GEO_FILE_2_FILENAME=best_coordinates_known_so_far.csv
AIRPORT_PG_FILENAME=ref_airport_pageranked.csv
AIRPORT_PG_SORTED=sorted_${AIRPORT_PG_FILENAME}
AIRPORT_PG_SORTED_CUT=cut_sorted_${AIRPORT_PG_FILENAME}
AIRPORT_POP_FILENAME=ref_airport_popularity.csv
AIRPORT_POP_SORTED=sorted_${AIRPORT_POP_FILENAME}
AIRPORT_POP_SORTED_CUT=cut_sorted_${AIRPORT_POP_FILENAME}
##
# Comparison files
POR_MAIN_DIFF_FILENAME=por_main_diff.csv
# Combined data files of both the other sources
GEO_COMBINED_FILE_FILENAME=new_airports.csv
# Minimal distance triggering a difference (in km)
COMP_MIN_DIST=10

##
# Geo data files
GEO_FILE_1_RAW=${TMP_DIR}${GEO_FILE_1_RAW_FILENAME}
GEO_FILE_1=${TMP_DIR}${GEO_FILE_1_FILENAME}
GEO_FILE_2=${ORI_DIR}${GEO_FILE_2_FILENAME}
AIRPORT_PG=${ORI_DIR}${AIRPORT_PG_FILENAME}
AIRPORT_POP=${ORI_DIR}${AIRPORT_POP_FILENAME}
##
# Comparison files
POR_MAIN_DIFF=${TMP_DIR}${POR_MAIN_DIFF_FILENAME}
# Combined data files of both the other sources
GEO_COMBINED_FILE=${TMP_DIR}${GEO_COMBINED_FILE_FILENAME}
# Missing POR
GEO_FILE_1_MISSING=${GEO_FILE_1}.missing
GEO_FILE_2_MISSING=${GEO_FILE_2}.missing

#
if [ "$1" = "-h" -o "$1" = "--help" ];
then
	echo
	echo "Usage: $0 [<Geo data file #1> [<Geo data file #2> [<PageRanked airport file>] [<minimum distance>]]]]"
	echo "  - Default name for the geo data file #1: '${GEO_FILE_1_RAW}'"
	echo "  - Default name for the geo data file #2: '${GEO_FILE_2}'"
	echo "  - Default name for the PageRanked airport file: '${AIRPORT_PG}'"
	echo "  - Default minimum distance (in km) triggering a difference: '${COMP_MIN_DIST}'"
	echo
	exit
fi

#
if [ "$1" = "--clean" ];
then
	if [ "${TMP_DIR}" = "/tmp/por/" ]
	then
		\rm -rf ${TMP_DIR}
	else
		\rm -f ${GEO_FILE_1_MISSING} ${GEO_FILE_2_MISSING} \
			${GEO_FILE_1} ${GEO_FILE_1_SORTED} ${GEO_FILE_1_SORTED_CUT} \
			${AIRPORT_PG_SORTED} ${AIRPORT_PG_SORTED_CUT} \
			${GEO_COMBINED_FILE} ${POR_MAIN_DIFF}
	fi
	exit
fi

##
# Local helper scripts
PREPARE_EXEC="bash ${EXEC_PATH}prepare_geonames_dump_file.sh"
PREPARE_POP_EXEC="bash ${EXEC_PATH}prepare_popularity.sh"
PREPARE_PG_EXEC="bash ${EXEC_PATH}prepare_pagerank.sh"
COMPARE_EXEC="bash ${EXEC_PATH}compare_geo_files.sh"

##
# First data file with geographical coordinates
if [ "$1" != "" ];
then
	GEO_FILE_1_RAW=$1
	GEO_FILE_1_RAW_FILENAME=`basename ${GEO_FILE_1_RAW}`
	GEO_FILE_1_FILENAME=wpk_${GEO_FILE_1_RAW_FILENAME}
	GEO_FILE_1_SORTED=sorted_${GEO_FILE_1_FILENAME}
	GEO_FILE_1_SORTED_CUT=cut_${GEO_FILE_1_SORTED}
	if [ "${GEO_FILE_1_RAW}" = "${GEO_FILE_1_RAW_FILENAME}" ]
	then
		GEO_FILE_1_RAW="${TMP_DIR}${GEO_FILE_1_RAW_FILENAME}"
	fi
fi
GEO_FILE_1=${TMP_DIR}${GEO_FILE_1_FILENAME}
GEO_FILE_1_SORTED=${TMP_DIR}${GEO_FILE_1_SORTED}
GEO_FILE_1_SORTED_CUT=${TMP_DIR}${GEO_FILE_1_SORTED_CUT}

if [ ! -f "${GEO_FILE_1_RAW}" ]
then
	echo
	echo "[$0:$LINENO] The '${GEO_FILE_1_RAW}' file does not exist."
	if [ "$1" = "" ];
	then
		${PREPARE_EXEC} --geonames
		echo "The default name of the Geonames data dump copy is '${GEO_FILE_1_RAW}'."
		echo
	fi
	exit -1
fi

##
# Prepare the Geonames dump file, exported from Geonames.
# Basically, a primary key is added and the coordinates are extracted,
# in order to keep a data file with only four fields/columns:
#  * The primary key (IATA code - location type)
#  * The airport/city code
#  * The geographical coordinates.
${PREPARE_EXEC} ${OPTD_DIR_DIR} ${LOG_LEVEL}

# Second data file with geographical coordinates
if [ "$2" != "" ];
then
	GEO_FILE_2="$2"
fi

if [ ! -f "${GEO_FILE_2}" ]
then
	echo
	echo "[$0:$LINENO] The '${GEO_FILE_2}' file does not exist."
	if [ "$2" = "" ];
	then
		echo
		echo "Hint:"
		echo "\cp -f ${EXEC_PATH}../ORI/${GEO_FILE_2_FILENAME} ${TMP_DIR}"
		echo
	fi
	exit -1
fi

##
# Data file with airport popularity
if [ "$3" != "" ];
then
	AIRPORT_PG=$3
	AIRPORT_PG_FILENAME=`basename ${AIRPORT_PG}`
	AIRPORT_PG_SORTED=sorted_${AIRPORT_PG_FILENAME}
	AIRPORT_PG_SORTED_CUT=cut_${AIRPORT_PG_SORTED}
	if [ "${AIRPORT_PG}" = "${AIRPORT_PG_FILENAME}" ]
	then
		AIRPORT_PG="${TMP_DIR}${AIRPORT_PG_FILENAME}"
	fi
fi
AIRPORT_PG_SORTED=${TMP_DIR}${AIRPORT_PG_SORTED}
AIRPORT_PG_SORTED_CUT=${TMP_DIR}${AIRPORT_PG_SORTED_CUT}

if [ ! -f "${AIRPORT_PG}" ]
then
	echo
	echo "[$0:$LINENO] The '${AIRPORT_PG}' file does not exist."
	if [ "$3" = "" ];
	then
		${PREPARE_PG_EXEC} --popularity
		echo "The default name of the airport popularity copy is '${AIRPORT_PG}'."
		echo
	fi
	exit -1
fi

##
# Prepare the ORI-maintained airport popularity dump file. Basically, the file
# is sorted by IATA code. Then, only two columns/fields are kept in that
# version of the file: the airport/city IATA code and the airport popularity.
${PREPARE_PG_EXEC} ${AIRPORT_PG}

##
# Minimal distance (in km) triggering a difference
if [ "$4" != "" ]
then
	COMP_MIN_DIST=$4
fi

##
# The two files contain only four fields (the primary key, the IATA code and
# both coordinates).
#
# Note that the ${PREPARE_EXEC} (e.g., prepare_geonames_dump_file.sh) script
# prepares such a file for Geonames (named ${GEO_FILE_1_SORTED_CUT}, e.g.,
# cut_sorted_wpk_dump_from_geonames.csv) from the data dump (named ${GEO_FILE_1},
# e.g., wpk_dump_from_geonames.csv).
#
# The 'join' command aggregates:
#  * The four fields of the (stripped) Geonames dump file. That is the file #1
#    for the join command.
#  * The IATA codes of both the POR and of its served city, as well as the two
#    coordinates of the file of best coordinates (the primary key being stripped
#    by the join command). That is the file #2 for the join command.
#
# The 'join' command takes all the rows from the file #1 (Geonames dump file);
# when there is no corresponding entry in the file of best coordinates, only
# the four (extracted) fields of the Geonames dump file are kept.
# Hence, lines may have:
#  * 8 fields: the primary key, IATA code and both coordinates of the Geonames
#    dump file, followed by the IATA codes of the POR and its served city,
#    as well as the best coordinates.
#  * 4 fields: the primary key, IATA code and both coordinates of the Geonames
#    dump file.
#
JOINED_COORD_1=${GEO_COMBINED_FILE}.tmp.1
join -t'^' -a 1 -1 1 -2 1 -e NULL ${GEO_FILE_1_SORTED_CUT} ${GEO_FILE_2} > ${JOINED_COORD_1}

##
# Sanity check: calculate the minimal number of fields on the resulting file
MIN_FIELD_NB=`awk -F'^' 'BEGIN{n=10} {if (NF<n) {n=NF}} END{print n}' ${JOINED_COORD_1} | uniq | sort | uniq`

if [ "${MIN_FIELD_NB}" != "8" -a "${MIN_FIELD_NB}" != "4" ]
then
	echo
	echo "Update step"
	echo "-----------"
	echo "Minimum number of fields in the new coordinate file should be 4 or 8. It is ${MIN_FIELD_NB}"
	echo "Problem!"
	echo "Check file ${JOINED_COORD_1}, which is a join of the coordinates from ${GEO_FILE_1_SORTED_CUT} and ${GEO_FILE_2}"
	echo
  exit
fi

##
# Operate the same way as above, except that, this time, the points of reference
# with the best known coordinates have the precedence over those of Geonames.
# Note that, however, when they exist, the Geonames coordinates themselves
# (not the point of reference) have the precedence over the "best known" ones.
#
JOINED_COORD_2=${GEO_COMBINED_FILE}.tmp.2
join -t'^' -a 2 -1 1 -2 1 -e NULL ${GEO_FILE_1_SORTED_CUT} ${GEO_FILE_2} > ${JOINED_COORD_2}

##
# Keep only the first 4 fields:
#  * The primary key, IATA code and both the coordinates of the Geonames dump file,
#    when they exist.
#  * The primary key, IATA code and the best coordinates, when no entry exists
#    in the geonames dump file.
#
#EXTRACTOR=${EXEC_PATH}extract_coord.awk
cut -d'^' -f 1-4 ${JOINED_COORD_1} > ${JOINED_COORD_1}.dup
\mv -f ${JOINED_COORD_1}.dup ${JOINED_COORD_1}
cut -d'^' -f 1-4 ${JOINED_COORD_2} > ${JOINED_COORD_2}.dup
#awk -F'^' -f ${EXTRACTOR} ${JOINED_COORD_2} > ${JOINED_COORD_2}.dup
\mv -f ${JOINED_COORD_2}.dup ${JOINED_COORD_2}

##
# Suppress empty coordinate fields, from the geonames dump file:
#sed -i -e 's/\^NULL/\^/g' ${JOINED_COORD}

##
# Re-aggregate all the fields, so that the format of the generated file be
# the same as the Geonames dump file.
JOINED_COORD_FULL=${JOINED_COORD_1}.tmp.full
join -t'^' -a 1 -1 1 -2 1 ${JOINED_COORD_1} ${GEO_FILE_1_SORTED} > ${JOINED_COORD_FULL}

##
# Filter and re-order a few fields, so that the format of the generated file be
# the same as the Geonames dump file.
# The awk in the following line is likely to be affected by a change
# in the fields of the Geonames dump file.
REDUCER_AWK=${TMP_DIR}reduce_airports_csv_from_geonames.awk
awk -F'^' -f ${REDUCER_AWK} ${JOINED_COORD_FULL} > ${GEO_COMBINED_FILE}

##
# Do some reporting
#
# Reminder:
#  * ${JOINED_COORD_1} (e.g., new_airports.csv.tmp.1) has got all the entries of
#    the Geonames dump file (./wpk_dump_from_geonames.csv)
#  * ${JOINED_COORD_2} (e.g., new_airports.csv.tmp.1) has got all the entries of
#    the ORI-maintained list of best known geographical coordinates
#    (best_coordinates_known_so_far.csv)
#
POR_NB_COMMON=`comm -12 ${JOINED_COORD_1} ${JOINED_COORD_2} | wc -l`
POR_NB_FILE1=`comm -23 ${JOINED_COORD_1} ${JOINED_COORD_2} | wc -l`
POR_NB_FILE2=`comm -13 ${JOINED_COORD_1} ${JOINED_COORD_2} | wc -l`
echo
echo "Reporting step"
echo "--------------"
echo "'${GEO_FILE_1}' and '${GEO_FILE_2}' have got ${POR_NB_COMMON} common lines."
echo "'${GEO_FILE_1}' has got ${POR_NB_FILE1} POR, missing from '${GEO_FILE_2}'"
echo "'${GEO_FILE_2}' has got ${POR_NB_FILE2} POR, missing from '${GEO_FILE_1}'"
echo

if [ ${POR_NB_FILE2} -gt 0 ]
then
	comm -13 ${JOINED_COORD_1} ${JOINED_COORD_2} > ${GEO_FILE_1_MISSING}
	POR_MISSING_GEONAMES_NB=`wc -l ${GEO_FILE_1_MISSING} | cut -d' ' -f1`
	echo
	echo "Suggestion step"
	echo "---------------"
	echo "${POR_MISSING_GEONAMES_NB} points of reference (POR) are missing from Geonames ('${GEO_FILE_1}')."
	echo "They can be displayed with: less ${GEO_FILE_1_MISSING}"
	echo
fi

if [ ${POR_NB_FILE1} -gt 0 ]
then
	comm -23 ${JOINED_COORD_1} ${JOINED_COORD_2} > ${GEO_FILE_2_MISSING}
	POR_MISSING_BEST_NB=`wc -l ${GEO_FILE_2_MISSING} | cut -d' ' -f1`
	echo
	echo "Suggestion step"
	echo "---------------"
	echo "${POR_MISSING_BEST_NB} points of reference (POR) are missing from the file of best coordinates ('${GEO_FILE_2}')."
	echo "To incorporate the missing POR into '${GEO_FILE_2}', just do:"
	echo "cat ${GEO_FILE_2} ${GEO_FILE_2_MISSING} | sort -t'^' -k1,1 > ${GEO_FILE_2}.tmp && \mv -f ${GEO_FILE_2}.tmp ${GEO_FILE_2} && \rm -f ${GEO_FILE_2_MISSING}"
	echo
fi

##
# Compare the Geonames coordinates to the best known ones (unil now).
# It generates a data file (${POR_MAIN_DIFF}, e.g., por_main_diff.csv)
# containing the greatest distances (in km), for each airport/city, between
# both sets of coordinates (Geonames and best known ones).
${COMPARE_EXEC} ${GEO_FILE_1_SORTED_CUT} ${GEO_FILE_2} ${AIRPORT_PG_SORTED_CUT} ${COMP_MIN_DIST}


##
# Clean
if [ "${TMP_DIR}" != "/tmp/por/" ]
then
	\rm -f ${JOINED_COORD} ${JOINED_COORD_FULL} ${JOINED_COORD_1} ${JOINED_COORD_2}
	\rm -f ${GEO_FILE_1_SORTED} ${GEO_FILE_1_SORTED_CUT}
fi


##
# Reporting
echo
echo "Update step"
echo "-----------"
echo "The new airports.csv data file is ${GEO_COMBINED_FILE}"
echo "Check that the format of the new file is the same as the old file before replacing!"
echo

echo
echo "If you want to do some cleaning:"
if [ "${TMP_DIR}" = "/tmp/por/" ]
then
	echo "\rm -rf ${TMP_DIR}"
else
	echo "\rm -f ${GEO_FILE_2} ${GEO_FILE_1_MISSING} ${AIRPORT_PG} \\"
	echo "${AIRPORT_PG_SORTED} ${AIRPORT_PG_SORTED_CUT} \\"
	echo "${GEO_COMBINED_FILE} ${POR_MAIN_DIFF}"
fi
echo
