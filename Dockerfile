FROM alpine:3.10
LABEL org.opencontainers.image.authors="Nards IT <giuseppe@nards.it>"

RUN apk add --no-cache bash

RUN apk add --no-cache python py-pip py-setuptools git ca-certificates libmagic \
 && pip install --no-cache-dir python-dateutil python-magic \
 && git clone --depth=1 https://github.com/s3tools/s3cmd.git /opt/s3cmd \
 && rm -rf /opt/s3cmd/.git \
 && ln -s /opt/s3cmd/s3cmd /usr/bin/s3cmd \
 && apk del py-pip py-setuptools git

ADD ./config/.s3cfg /root/.s3cfg
ADD watch /watch

RUN ["chmod", "+x", "/watch"]

VOLUME /data

HEALTHCHECK --interval=2s --retries=1800 \
	CMD stat /var/healthy.txt || exit 1

ENV S3_SYNC_FLAGS "--delete-removed"
ENV S3CMD_FINAL_STRATEGY "PUT"

SHELL ["/bin/bash", "-c"]
ENTRYPOINT [ "/watch" ]
CMD ["/data"]