#!/bin/bash

MAND_VARS="BW_MASTERPASS BW_CLIENTID BW_CLIENTSECRET"

source ./checkMandVars.sh

if [ "$#" == "0" ]; then
	echo "$0 VAR1 VAR2 VAR3 ..."
	exit 1
fi

bw_login() {
	bw login --apikey --raw
	export BW_SESSION=$(bw unlock --passwordenv BW_MASTERPASS --raw)
}

bw_logout(){
	bw logout --raw
}

bw_login

#RESULT=$(echo -e "#!/bin/sh\n\n")

RESULT="\n"

while (( "$#" )); do
	PASS="$(bw get password $1)"
	if [ -z "$PASS" ]; then
		echo "ERROR: Password $1 not found in vault. Exiting ..."
		exit 1
	fi
	RESULT+="export $1=\"$PASS\"\n"
	shift
done

echo -e "$RESULT"

bw_logout
