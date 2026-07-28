FROM debian:12-slim

RUN apt-get update && \
    apt-get install -y \
        dante-server \
        gettext-base \
        iproute2 \
        passwd \
        libpam0g \
    && rm -rf /var/lib/apt/lists/*

COPY danted.conf.template /etc/danted.conf.template
COPY entrypoint.sh /entrypoint.sh

RUN chmod +x /entrypoint.sh

EXPOSE 1080

ENTRYPOINT ["/entrypoint.sh"]
