# ShadowsocksR Docker Tunnel

Wraps your program with ShadowsocksR network tunnel fully contained in Docker. Also exposes SOCKS5 server to host machine. This allows you to have multiple ShadowsocksR connections in different containers serving different programs running inside them through global proxy, or on host machine through SOCKS5 proxy.

Supports latest Docker for both Windows, Linux, and MacOS.

### Related Projects

* [openvpn-tunnel](https://hub.docker.com/r/curve25519xsalsa20poly1305/openvpn-tunnel/) ([GitHub](https://github.com/curve25519xsalsa20poly1305/docker-openvpn-tunnel)) - Wraps your program with OpenVPN network tunnel fully contained in Docker.
* [openvpn-socks5](https://hub.docker.com/r/curve25519xsalsa20poly1305/openvpn-socks5/) ([GitHub](https://github.com/curve25519xsalsa20poly1305/docker-openvpn-socks5)) - Convers OpenVPN connection to SOCKS5 server in Docker.
* [shadowsocksr-tunnel](https://hub.docker.com/r/curve25519xsalsa20poly1305/shadowsocksr-tunnel/) ([GitHub](https://github.com/curve25519xsalsa20poly1305/docker-shadowsocksr-tunnel)) - This project.

## What it does?

1. It starts ShadowsocksR client mode `ss-redir` at default port of `1024`.
2. It starts a SOCKS5 server at `$SOCKS5_PORT`, with optional authentication of `$SOCKS5_USER` and `$SOCKS5_PASS`.
3. It setups iptables rules to redirect all internet traffics initiated inside the container through the ShadowsocksR connection.
4. It optionally runs the user specified CMD line from `docker run` positional arguments ([see Docker doc](https://docs.docker.com/engine/reference/run/#cmd-default-command-or-options)). The program will use the ShadowsocksR connection inside the container.
5. If user has provided CMD line, and `DAEMON_MODE` environment variable is not set to `true`, then after running the CMD line, it will shutdown the ShadowsocksR client and SOCKS5 server, then terminate the container.

## How to use?

ShadowsocksR connection options are specified through these container environment variables:

* `SERVER_ADDR` (Default: `"0.0.0.0"`) - remote server address, can either be a domain name or IP address
* `SERVER_PORT` (Default: `"1080"`) - remote server port
* `SERVER_PASS` (Default: `""`) - remote server password
* `METHOD` (Default: `"aes-256-ctr"`) - encryption method
* `PROTO` (Default: `"auth_aes128_md5"`) - protocol
* `PROTO_PARAM` (Default: `""`) - protocol prarmeter
* `OBFS` (Default: `"plain"`) - obfuscation
* `OBFS_PARAM` (Default: `""`) - obfuscation parameter
* `TIMEOUT` (Default: `"300"`) - connection timeout
* `REDIR_PORT` (Default: `"1024"`) - `ss-redir` local listening port, must be different from `SOCKS5_PORT`

SOCKS5 server options are specified through these container environment variables:

* `SOCKS5_PORT` (Default: `"1080"`) - SOCKS5 server listening port
* `SOCKS5_USER` (Default: `""`) - SOCKS5 server authentication username
* `SOCKS5_PASS` (Default: `""`) - SOCKS5 server authentication password

Other container environment variables:

* `DAEMON_MODE` (Default: `"false"`) - force enter daemon mode when CMD line is specified
* `SOCKS5_UP` (Default: `""`) - optional command to be executed when SOCKS5 server becomes stable
* `SHADOWSOCKSR_UP` (Default: `""`) - optional command to be executed when ShadowsocksR connection becomes stable

### Simple Example

The following example will run `curl ifconfig.co/json` through ShadowsocksR server `1.2.3.4` with other default settings.

```bash
docker run -it --rm --device=/dev/net/tun --cap-add=NET_ADMIN \
    -e SERVER_ADDR="1.2.3.4" \
    curve25519xsalsa20poly1305/shadowsocksr-tunnel \
    curl ifconfig.co/json
```

### Daemon Mode

You can leave the ShadowsocksR connection running in background, exposing its SOCKS5 server port to host port, and later use `docker exec` to run your program inside the running container without ever closing and repoening your ShadowsocksR connection multiple times. Just leave out the CMD line when you start the container with `docker run`, it will automatically enter daemon mode.

```bash
NAME="myssr"
PORT="7777"
docker run --name "${NAME}" -dit --rm --device=/dev/net/tun --cap-add=NET_ADMIN \
    -e SERVER_ADDR="1.2.3.4" \
    -p "${PORT}":1080 \
    curve25519xsalsa20poly1305/shadowsocksr-tunnel \
    curl ifconfig.co/json
```

Then you run commads using `docker exec`:

```bash
NAME="myssr"
docker exec -it "${NAME}" curl ifconfig.co/json
```

Or use the SOCKS5 server available on host machine:

```bash
curl ifconfig.co/json -x socks5h://127.0.0.1:7777
```

To stop the daemon, run this:

```bash
NAME="myssr"
docker stop "${NAME}"
```

### Extends Image

This image only includes `curl` and `wget` for most basic HTTP request usage. If the program you want to run is not available in this image, you can easily extend this image to include anything you need.

Here is a very simple example `Dockerfile` that will install [aria2](http://aria2.github.io/) in its derived image.

```Dockerfile
FROM curve25519xsalsa20poly1305/shadowsocksr-tunnel
RUN apk add --no-cache aria2
```

Build this image with:

```bash
# Unix & Windows
docker build -t shadowsocksr-aria2 .
```

Finally run it with

```bash
docker run -it --rm --device=/dev/net/tun --cap-add=NET_ADMIN \
    -e SERVER_ADDR="1.2.3.4" \
    -v "${PWD}":/downloads:rw \
    -w /downloads \
    shadowsocksr-aria2 \
    arai2c http://example.com/index.html
```

It will download the file using `aria2c` to your host's current directory.

## Contributing

Please feel free to contribute to this project. But before you do so, just make
sure you understand the following:

1\. Make sure you have access to the official repository of this project where
the maintainer is actively pushing changes. So that all effective changes can go
into the official release pipeline.

2\. Make sure your editor has [EditorConfig](https://editorconfig.org/) plugin
installed and enabled. It's used to unify code formatting style.

3\. Use [Conventional Commits 1.0.0-beta.2](https://conventionalcommits.org/) to
format Git commit messages.

4\. Use [Gitflow](https://www.atlassian.com/git/tutorials/comparing-workflows/gitflow-workflow)
as Git workflow guideline.

5\. Use [Semantic Versioning 2.0.0](https://semver.org/) to tag release
versions.

## License

Copyright © 2019 curve25519xsalsa20poly1305 &lt;<curve25519xsalsa20poly1305@gmail.com>&gt;

This work is free. You can redistribute it and/or modify it under the
terms of the Do What The Fuck You Want To Public License, Version 2,
as published by Sam Hocevar. See the COPYING file for more details.
