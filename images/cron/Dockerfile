FROM alpine:3.21
RUN apk add --no-cache curl jq python3
COPY os-admin /usr/local/bin/os-admin
COPY preview.py /usr/local/bin/preview.py
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /usr/local/bin/os-admin /usr/local/bin/preview.py /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]
