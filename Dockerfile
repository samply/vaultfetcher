FROM debian AS builder

ADD https://vault.bitwarden.com/download/?app=cli&platform=linux /tmp/bw.zip


ADD https://releases.hashicorp.com/vault/1.17.0/vault_1.17.0_linux_amd64.zip /tmp/vault.zip

RUN apt-get update && apt-get -y install unzip && \
    unzip -d /usr/local/bin /tmp/bw.zip && \
	unzip -d /usr/local/bin /tmp/vault.zip && \
    chmod +x /usr/local/bin/*

FROM debian

COPY --from=builder /usr/local/bin/bw /usr/local/bin/
COPY --from=builder /usr/local/bin/vault /usr/local/bin/

ADD *.sh /

ENTRYPOINT [ "/entrypoint.sh" ]
