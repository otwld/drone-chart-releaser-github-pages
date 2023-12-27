FROM alpine
ADD cr.sh /bin/
RUN chmod +x /bin/cr.sh
RUN apk -Uuv add curl ca-certificates git
ENTRYPOINT /bin/cr.sh