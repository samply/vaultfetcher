FROM alpine

RUN apk --no-cache add jq curl bash rbw

ADD *.sh /

ENTRYPOINT [ "/entrypoint.sh" ]
