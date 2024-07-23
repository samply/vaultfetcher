FROM rust AS builder

RUN echo '[profile.release]\n\
lto = true\n\
codegen-units = 1\n\
panic = "abort"\n\
strip = true' > $CARGO_HOME/config.toml

RUN cargo install rbw && \
    mv $CARGO_HOME/bin/rbw $CARGO_HOME/bin/rbw-agent /

FROM ubuntu

RUN apt-get update && \
    apt-get -y install jq curl && \
    rm -rf /var/lib/apt/lists

COPY --from=builder /rbw /rbw-agent /usr/local/bin/

ADD *.sh /

ENTRYPOINT [ "/entrypoint.sh" ]
