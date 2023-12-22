FROM alpine
ADD cr.sh /bin/
RUN chmod +x /bin/cr.sh
RUN apk -Uuv add curl ca-certificates
ENTRYPOINT /bin/cr.sh