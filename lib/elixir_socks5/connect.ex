defmodule ElixirSocks5.Connect do
  require Logger

  @rfc_1928_atyp_ipv4 0x01
  @rfc_1928_atyp_domainname 0x03
  @rfc_1928_atyp_ipv6 0x04
  """
  +----+-----+-------+------+----------+----------+
  |VER | CMD |  RSV  | ATYP | DST.ADDR | DST.PORT |
  +----+-----+-------+------+----------+----------+
  | 1  |  1  | X'00' |  1   | Variable |    2     |
  +----+-----+-------+------+----------+----------+
  """

  defstruct [
    :ver,
    :cmd,
    :rsv,
    :atyp,
    :addr,
    :port
  ]

  def new(packet) when is_binary(packet) do
    case packet do
      <<ver::size(8), cmd::size(8), rsv::size(8), atyp::size(8), dst::binary>> ->
        case get_dst(atyp, dst) do
          [addr, port] ->
            %__MODULE__{ver: ver, cmd: cmd, rsv: rsv, atyp: atyp, addr: addr, port: port}

          _ ->
            :error
        end

      _ ->
        :error
    end
  end

  defp get_dst(@rfc_1928_atyp_ipv4, dst) do
    case dst do
      <<a::size(8), b::size(8), c::size(8), d::size(8), port::size(16)>> ->
        ipv4 = {a, b, c, d}
        [ipv4, port]

      _ ->
        :error
    end
  end

  defp get_dst(@rfc_1928_atyp_domainname, dst) do
    / / TODO
  end

  defp get_dst(@rfc_1928_atyp_ipv6, dst) do
    case dst do
      <<a::size(16), b::size(16), c::size(16), d::size(16), e::size(16), f::size(16), g::size(16),
        h::size(16), port::size(16)>> ->
        ipv6 = {a, b, c, d, e, f, g, h}
        [ipv6, port]

      _ ->
        :error
    end
  end
end

defimpl String.Chars, for: ElixirSocks5.Connect do
  alias ElixirSocks5.Connect

  def to_string(%Connect{ver: ver, cmd: cmd, rsv: rsv, atyp: atyp, addr: addr, port: port}) do
    "%Connect{ver: #{ver}, cmd: #{cmd}, rsv: #{rsv}, atyp: #{atyp}, addr: #{inspect(addr)}, port: #{
      port
    }}"
  end
end
