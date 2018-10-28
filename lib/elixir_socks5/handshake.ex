defmodule ElixirSocks5.Handshake do
  """
  +----+----------+----------+
  |VER | NMETHODS | METHODS  |
  +----+----------+----------+
  | 1  |    1     | 1 to 255 |
  +----+----------+----------+
  """

  @rfc_1928_version 0x05

  defstruct [
    :ver,
    :nmethods,
    :methods
  ]

  def new(packet) when is_binary(packet) do
    case packet do
      <<@rfc_1928_version, nmethods::size(8), methods::binary-size(nmethods)>> ->
        %__MODULE__{ver: @rfc_1928_version, nmethods: nmethods, methods: methods}

      _ ->
        :error
    end
  end
end

defimpl String.Chars, for: ElixirSocks5.Handshake do
  alias ElixirSocks5.Handshake

  def to_string(%Handshake{ver: ver, nmethods: nmethods, methods: methods}) do
    "%Handshake{ver: #{ver}, nmethods: #{nmethods}, methods: #{inspect(methods)}}"
  end
end
