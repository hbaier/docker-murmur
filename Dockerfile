FROM alpine:3.12
LABEL maintainer="Harald Baier <hbaier@users.noreply.github.com>"

ENV MURMUR_HOME=/opt/murmur \
    MURMUR_INI_ALLOWPING=true \
    MURMUR_INI_BANDWIDTH=72000 \
    MURMUR_INI_MESSAGEBURST=5 \
    MURMUR_INI_MESSAGELIMIT=1 \
    MURMUR_INI_SERVERPASSWORD="" \
    MURMUR_INI_SSLDHPARAMS=@ffdhe2048 \
    MURMUR_INI_SSLPASSPHRASE="" \
    MURMUR_INI_USERS=100 \
    MURMUR_INI_WELCOMETEXT="<br />Welcome to this server running <b>Murmur</b>.<br />Enjoy your stay!<br />" \
    MURMUR_SUPW=changeme

RUN apk --no-cache add \
    bash \
    murmur \
    su-exec \
 && echo '#!/bin/sh' > /usr/bin/lsb_release \
 && echo '. /etc/os-release' >> /usr/bin/lsb_release \
 && echo 'echo $PRETTY_NAME' >> /usr/bin/lsb_release \
 && chmod 755 /usr/bin/lsb_release \
 && mv /etc/murmur.ini /etc/murmur.ini.original

COPY ./docker-entrypoint.sh /usr/local/bin
COPY ./murmur-helper.sh /usr/local/bin
RUN chmod 755 /usr/local/bin/docker-entrypoint.sh \
 && chmod 755 /usr/local/bin/murmur-helper.sh

EXPOSE 64738/tcp 64738/udp
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
