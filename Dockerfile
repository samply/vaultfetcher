FROM node AS builder

#TODO: Use fixed version once this is supported by https://github.com/bitwarden/clients

RUN	npm install -g pkg

RUN	git clone --single-branch --recurse-submodules https://github.com/bitwarden/clients

RUN	cd clients/apps/cli && \
	npm ci && \
	npm run build:prod && npm run clean && \
	pkg . --targets linux --output /bw && \
	chmod +x /bw

FROM ubuntu

ARG BW_SERVER=https://pass.verbis.dkfz.de
ENV BW_SERVER=${BW_SERVER}

COPY --from=builder /bw /usr/bin/

RUN bw config server $BW_SERVER

ADD *.sh /

ENTRYPOINT [ "/entrypoint.sh" ]
