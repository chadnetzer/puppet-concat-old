#!/bin/bash

# Script to concat files to a config file.
#
# Given a directory like this:
# /path/to/conf.d
# |-- fragments
# |   |-- 00_named.conf
# |   |-- 10_domain.net
# |   `-- zz_footer
#
# The script supports a test option that will build the concat file to a temp
# location and use /usr/bin/cmp to verify if it should be run or not.  This
# would result in the concat happening twice on each run but gives you the
# option to have an unless option in your execs to inhibit rebuilds.
#
# Without the test option and the unless combo your services that depend on the
# final file would end up restarting on each run, or in other manifest models
# some changes might get missed.
#
# OPTIONS:
#  -o   The file to create from the sources
#  -d   The directory where the fragments are kept
#  -t   Test to find out if a build is needed, basically concats the files to a
#       temp location and compare with what's in the final location, return
#       codes are designed for use with unless on an exec resource
#  -w   Add a shell style comment at the top of the created file to warn users
#       that it is generated by puppet
#  -f   Enables the creation of empty output files when no fragments are found
#  -n   Sort the output numerically rather than the default alpha sort
#
# the command:
#
#   concatfragments.sh -o /path/to/conffile.cfg -d /path/to/conf.d
#
# creates /path/to/conf.d/fragments.concat and copies the resulting
# file to /path/to/conffile.cfg.  The files will be sorted alphabetically
# pass the -n switch to sort numerically.
#
# The script does error checking on the various dirs and files to make
# sure things don't fail.

PATH=/sbin:/usr/sbin:/bin:/usr/bin

OUTFILE=""
WORKDIR=""
TEST=""
FORCE=""
WARN=""
SORTARG=""

while getopts "o:s:d:tnwf" options; do
	case $options in
		o ) OUTFILE="$OPTARG";;
		d ) WORKDIR="$OPTARG";;
		n ) SORTARG="-n";;
		w ) WARN="true";;
		f ) FORCE="true";;
		t ) TEST="true";;
		* ) echo "Specify output file with -o and fragments directory with -d"
		    exit 1;;
	esac
done

# do we have -o?
if [ -z "${OUTFILE}" ]; then
	echo "Please specify an output file with -o"
	exit 1
fi

# do we have -d?
if [ -z "${WORKDIR}" ]; then
	echo "Please fragments directory with -d"
	exit 1
fi

# can we write to -o?
if [ -a "${OUTFILE}" ]; then
	if [ ! -w "${OUTFILE}" ]; then
		echo "Cannot write to ${OUTFILE}"
		exit 1
	fi
else
	OUTFILE_DIR=`dirname "$OUTFILE"`
	if [ ! -w "${OUTFILE_DIR}" ]; then
		echo "Cannot write to ${OUTFILE_DIR} to create ${OUTFILE}"
		exit 1
	fi
fi

# do we have a fragments subdir inside the work dir?
if [ ! -d "${WORKDIR}/fragments" ]  && [ ! -x "${WORKDIR}/fragments" ]; then
	echo "Cannot access the fragments directory"
	exit 1
fi

# are there actually any fragments?
FRAGLIST=$(ls -A "${WORKDIR}/fragments")
if [ ! "$FRAGLIST" ]; then
	if [ -z ${FORCE} ]; then
		echo "The fragments directory is empty, cowardly refusing to make empty config files"
		exit 1
	fi
fi

cd "${WORKDIR}"

if [ -z ${WARN} ]; then
	cat /dev/null > "fragments.concat"
else
	echo '# This file is managed by Puppet. DO NOT EDIT.' > "fragments.concat"
fi

# find all the files in the fragments directory, sort them lexicographically
# (or optionally numerically) and concat to fragments.concat in the working dir
find fragments/ -type f -follow -print0 | sort -z ${SORTARG} | xargs -0 cat >>"fragments.concat"

if [ -z ${TEST} ]; then
	# This is a real run, copy the file to outfile
	cp fragments.concat "${OUTFILE}"
	RETVAL=$?
else
	# Just compare the result to outfile to help the exec decide
	cmp "${OUTFILE}" fragments.concat
	RETVAL=$?
fi

exit $RETVAL
