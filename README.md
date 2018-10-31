# ElixirSocks5

[![Build Status](https://travis-ci.org/mrdotb/elixir_sock5.svg?branch=master)](https://travis-ci.org/mrdotb/elixir_sock5)

Creates a simple SOCKS5 server fallowing the rfc spec.

The following RFCs may be useful as background:

https://www.ietf.org/rfc/rfc1928.txt - [NO_AUTH SOCKS5](https://raw.githubusercontent.com/mrdotb/elixir_sock5/master/rfc1928.txt)

https://www.ietf.org/rfc/rfc1929.txt - [USERNAME/PASSWORD SOCKS5](https://raw.githubusercontent.com/mrdotb/elixir_sock5/master/rfc1929.txt)

```bash
curl -v https://google.com --socks5 127.0.0.1:1080 --proxy-user username:password

# use socks dns
curl -v https://google.com --proxy 'socks5h://localhost' --proxy-user username:password

```

