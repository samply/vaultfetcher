#!/bin/bash -e

if [ -z "$MAND_VARS" ]; then
	echo "Error: MAND_VARS not defined."
	exit 1
fi

MISSING_VARS=""

for VAR in $MAND_VARS; do
	if [ -z "${!VAR}" ]; then
		MISSING_VARS+="$VAR "
	fi
done

if [ -n "$MISSING_VARS" ]; then
	echo "Error: Mandatory variables not defined: $MISSING_VARS"
	exit 1
fi
