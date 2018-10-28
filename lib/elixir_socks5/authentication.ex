defmodule ElixirSocks5.Authentication do
  """
  +----+------+----------+------+----------+
  |VER | ULEN |  UNAME   | PLEN |  PASSWD  |
  +----+------+----------+------+----------+
  | 1  |  1   | 1 to 255 |  1   | 1 to 255 |
  +----+------+----------+------+----------+
  """

  @rfc_1929_version 0x01

  defstruct [
    :ver,
    :ulen,
    :uname,
    :plen,
    :passwd
  ]

  def new(packet) when is_binary(packet) do
    case packet do
      <<@rfc_1929_version, ulen::size(8), uname::binary-size(ulen), plen::size(8),
        passwd::binary-size(plen)>> ->
        %__MODULE__{ver: @rfc_1929_version, ulen: ulen, uname: uname, plen: plen, passwd: passwd}

      _ ->
        :error
    end
  end
end

defimpl String.Chars, for: ElixirSocks5.Authentication do
  alias ElixirSocks5.Authentication

  def to_string(%Authentication{ver: ver, ulen: ulen, uname: uname, plen: plen, passwd: passwd}) do
    "%Authentication{ver: #{ver}, ulen: #{ulen}, uname: \"#{uname}\", plen: #{plen}, passwd: \"#{
      passwd
    }\"}"
  end
end
