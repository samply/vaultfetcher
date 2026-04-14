#!/bin/bash -e

MAND_VARS="BW_MASTERPASS BW_EMAIL BW_SERVER"

export VAULT_ADDR=http://vault:8200

source ./checkMandVars.sh

export PIN=$(mktemp)

bw_login() {
	cat <<EOF > ${PIN}
#!/bin/sh

echo "D ${BW_MASTERPASS}"
EOF
	chmod +x $PIN
	rbw config set base_url ${BW_SERVER}
	rbw config set email ${BW_EMAIL}
	rbw config set pinentry ${PIN}
}

bw_logout(){
	rbw stop-agent
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
			read PASS < <(rbw get password $1)
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
			bw_login
			echo "Getting unseal key ..."
			WAITING=1
			while [ $WAITING -eq 1 ]; do
				if [ $? -eq 0 ]; then
					read UNSEAL_KEY < <(rbw get "Vault Unseal Key")
					WAITING=0
				else
				  echo "Waiting for vaultwarden to be reachable ..."
				  sleep 3
				fi
			done
			echo "Got unseal key."
			bw_logout
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

		if [ "${QUIT:-0}" == "1" ]; then
			echo "Vault is unlocked. Exiting as QUIT=1."
		else
			echo "Vault is unlocked. This container will stay active to keep the stack from quitting."
			exec sleep infinity
		fi
		;;

	*)
		echo "Please check usage"
		exit 1
		;;
esac

exit 0
