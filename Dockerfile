FROM ubuntu AS builder

ADD https://vault.bitwarden.com/download/?app=cli&platform=linux /tmp/bw.zip

RUN apt-get update && apt-get -y install unzip && \
    unzip -d /usr/local/bin /tmp/bw.zip && \
    chmod +x /usr/local/bin/*

FROM ubuntu

RUN apt-get update && \
    apt-get -y install jq curl && \
    rm -rf /var/lib/apt/lists

COPY --from=builder /usr/local/bin/bw /usr/local/bin/

ADD *.sh /

ENTRYPOINT [ "/entrypoint.sh" ]
