#!/bin/bash -e

MAND_VARS="BW_MASTERPASS BW_CLIENTID BW_CLIENTSECRET BW_SERVER"

source ./checkMandVars.sh

bw_login() {
	bw config server ${BW_SERVER}
	bw login --apikey --raw
	export BW_SESSION=$(bw unlock --passwordenv BW_MASTERPASS --raw)
}

bw_logout(){
	bw logout --raw
}

case "$1" in
	getPasswordsAsExport)
		shift
		if [ "$#" == "0" ]; then
			echo "$0 getPasswordsAsExport VAR1 VAR2 VAR3 ..."
			exit 1
		fi

		bw_login
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
		;;

	unsealVault)
		shift
		bw_login
		echo "Getting unseal key ..."
		UNSEAL_KEY="$(bw get password "Vault Unseal Key")"
		echo "Got unseal key."
		bw_logout

		export VAULT_ADDR=http://vault:8200

		while ! vault operator unseal "${UNSEAL_KEY}"; do
			echo "Failed to unlock vault. Retrying in 1 second."
			sleep 1
		done

		echo "Unlocked vault with error code $?. This container will stay active to keep the stack from quitting."
		sleep infinity
		;;

	*)
		echo "Please check usage"
		exit 1
		;;
esac

exit 0