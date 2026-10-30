FROM debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive TZ=Asia/Jakarta

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      cups cups-client cups-filters printer-driver-escpr printer-driver-gutenprint \
      socat usbutils tzdata ca-certificates \
 && rm -rf /var/lib/apt/lists/*

COPY cupsd.conf /etc/cups/cupsd.conf
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

EXPOSE 631 9100 9101
VOLUME ["/etc/cups", "/var/log/cups"]

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
