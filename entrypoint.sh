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

vault_sealstatus() {
	curl -s ${VAULT_ADDR}/v1/sys/seal-status | jq '.sealed'
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

		WAITING=1
		while [ $WAITING -eq 1 ]; do
			case "$(vault_sealstatus)" in
				true)
					echo "Vault is online and sealed. Unsealing Vault ..."
					WAITING=0
					;;
				false)
					echo "Vault is already unlocked."
					WAITING=0
					;;
				*)
					echo "Vault is not online yet -- waiting ..."
					sleep 1
					;;
			esac
		done

		if [ "$(vault_sealstatus)" == "true" ]; then
			RUNNING=1
			while [ $RUNNING -eq 1 ]; do
				RES=$(curl -s \
					--request POST \
					--data "{ \"key\": \"${UNSEAL_KEY}\" }" \
					${VAULT_ADDR}/v1/sys/unseal)
				if [ "$(echo "$RES" | grep sealed | grep false)" != "" ]; then
					RUNNING=0
				else
					echo "Failed to unlock vault. Retrying in 1 second."
					sleep 1
				fi
			done
		fi

		echo "Vault is unlocked. This container will stay active to keep the stack from quitting."
		sleep infinity
		;;

	*)
		echo "Please check usage"
		exit 1
		;;
esac

exit 0