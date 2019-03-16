FROM golang:latest as builder
WORKDIR /go/src/socks5
COPY socks5.go .
RUN go get && CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -ldflags '-s' -o ./socks5


FROM alpine:latest

COPY socks5-up.sh /usr/local/bin/
COPY entrypoint.sh /usr/local/bin/
COPY shadowsocksr-up.sh /usr/local/bin/
COPY shadowsocksr.patch /shadowsocksr-libev-master/
COPY --from=builder /go/src/socks5/socks5 /usr/local/bin/

RUN echo "http://dl-4.alpinelinux.org/alpine/edge/testing" >> /etc/apk/repositories \
    && apk upgrade \
    && apk add --no-cache bash curl wget iptables libressl-dev pcre-dev \
    && apk add --no-cache --virtual .build-deps \
        build-base autoconf libtool linux-headers pcre-dev \
        libressl-dev libev-dev udns-dev libsodium-dev zlib-dev \
    && curl -sSL "https://github.com/shadowsocksr-backup/shadowsocksr-libev/archive/master.tar.gz" | tar xz \
    && cd shadowsocksr-libev-master \
    && patch -p1 < shadowsocksr.patch \
    && ./configure --prefix=/usr --disable-documentation \
    && make install \
    && cd .. \
    && rm -rf shadowsocksr-libev-master \
    && apk del .build-deps \
    && chmod +x \
        /usr/local/bin/socks5-up.sh \
        /usr/local/bin/entrypoint.sh \
        /usr/local/bin/shadowsocksr-up.sh \
    && mkdir -p /etc/shadowsocksr

ENV     SERVER_ADDR     "0.0.0.0"
ENV     SERVER_PORT     "1080"
ENV     SERVER_PASS     ""
ENV     METHOD          "aes-256-ctr"
ENV     PROTO           "auth_aes128_md5"
ENV     PROTO_PARAM     ""
ENV     OBFS            "plain"
ENV     OBFS_PARAM      ""
ENV     TIMEOUT         "300"
ENV     SOCKS5_PORT     "1080"
ENV     SOCKS5_USER     ""
ENV     SOCKS5_PASS     ""
ENV     REDIR_PORT      "1024"
ENV     DAEMON_MODE     "false"
ENV     SOCKS5_UP       ""
ENV     SHADOWSOCKSR_UP ""

ENTRYPOINT [ "entrypoint.sh" ]
