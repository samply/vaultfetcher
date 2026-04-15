#!/bin/bash -e

MAND_VARS="BW_MASTERPASS BW_EMAIL BW_SERVER"

export VAULT_ADDR=http://vault:8200

source ./checkMandVars.sh

trap 'echo "SIGTERM received, exiting..."; kill -- -$$ 2>/dev/null; exit 143' TERM

export PIN=$(mktemp)

bw_setconfig() {
	cat <<EOF > ${PIN}
#!/bin/sh

echo "D ${BW_MASTERPASS}"
EOF
	chmod +x $PIN
	rbw config set base_url ${BW_SERVER}
	rbw config set email ${BW_EMAIL}
	rbw config set pinentry ${PIN}
}

bw_stopagent(){
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

		bw_setconfig
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

		bw_stopagent
		;;

	unsealVault)
		shift

		UNSEAL_RETRY=0
		while true; do
			UNSEAL_RETRY=$(( UNSEAL_RETRY + 1 ))
			echo "Attempt ${UNSEAL_RETRY}: Checking vault status ..."
			case "$(vault_sealstatus)" in
				true)
					echo "Attempt ${UNSEAL_RETRY}: Vault is online and sealed. Unsealing Vault ..."
					break
					;;
				false)
					echo "Attempt ${UNSEAL_RETRY}: Vault is already unlocked."
					break
					;;
				*)
					echo "Attempt ${UNSEAL_RETRY}: Vault is not online yet -- waiting ..."
					sleep 1
					;;
			esac
		done

		UNSEAL_RETRY=0
		if [ "$(vault_sealstatus)" == "true" ]; then
			bw_setconfig
			echo "Getting unseal key ..."
			until read UNSEAL_KEY < <(rbw get "Vault Unseal Key"); do
				UNSEAL_RETRY=$(( UNSEAL_RETRY + 1 ))
				echo "Attempt ${UNSEAL_RETRY}: Waiting for vaultwarden to be reachable ..."
				sleep 3
			done
			echo "Attempt ${UNSEAL_RETRY}: Got unseal key."
			bw_stopagent
			UNSEAL_RETRY=0
			while true; do
				UNSEAL_RETRY=$(( UNSEAL_RETRY + 1 ))
				echo "Attempt ${UNSEAL_RETRY}: Unsealing vault ..."
				RES=$(curl -s \
					--request POST \
					--data "{ \"key\": \"${UNSEAL_KEY}\" }" \
					${VAULT_ADDR}/v1/sys/unseal)
				if [ "$(echo "$RES" | grep sealed | grep false)" != "" ]; then
					echo "Attempt ${UNSEAL_RETRY}: Vault unsealed successfully."
					break
				else
					echo "Attempt ${UNSEAL_RETRY}: Failed to unlock vault. Retrying in 1 second."
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
