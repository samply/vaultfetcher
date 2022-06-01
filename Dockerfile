FROM alpine AS builder

ARG BW_VERSION=1.22.1

RUN apk --no-cache add wget unzip && \
    wget https://github.com/bitwarden/cli/releases/download/v$BW_VERSION/bw-linux-$BW_VERSION.zip -nv -O /tmp/bw.zip && \
    cd /tmp && \
    unzip bw.zip && \
    chmod +x bw

FROM ubuntu

ARG BW_SERVER=https://pass.verbis.dkfz.de
ENV BW_SERVER=${BW_SERVER}

#RUN apk --no-cache add bash libc6-compat gcompat

COPY --from=builder /tmp/bw /usr/bin/

RUN bw config server $BW_SERVER

ADD *.sh /

ENTRYPOINT [ "/entrypoint.sh" ]
