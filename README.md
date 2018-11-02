# ElixirSocks5

[![Build Status](https://travis-ci.org/mrdotb/elixir_sock5.svg?branch=master)](https://travis-ci.org/mrdotb/elixir_sock5)

An experimental SOCKS5 server in elixir.

The following RFCs may be useful as background:
+ https://www.ietf.org/rfc/rfc1928.txt
+ https://www.ietf.org/rfc/rfc1929.txt

## How to use ?
By default the socks5 server use the port 1080 and have basic authentication enabled.

```bash
# start the server
mix run --no-halt

curl -v https://google.com --socks5 127.0.0.1:1080 --proxy-user username:password

# use socks dns
curl -v https://google.com --proxy 'socks5h://localhost' --proxy-user username:password
```

## Authentication
- [x] No authentication
- [ ] GSSAPI
- [x] Username/password
- [ ] IANA (wtf is this ?)

## TODO
- [ ] more tests
- [ ] use a socket acceptator pool
- [ ] benchmark
