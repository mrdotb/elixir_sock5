defmodule ElixirSocks5.Forwarder do
  require Logger

  @timeout 1000

  @rfc_1928_version 0x05

  @rfc_1928_replies %{
    succeeded: 0x00,
    general_failure: 0x01,
    connection_not_allowed: 0x02,
    network_unreachable: 0x03,
    host_unreachable: 0x04,
    connection_refused: 0x05,
    ttl_expired: 0x06,
    command_not_supported: 0x07,
    address_type_not_supported: 0x08
  }

  def start_link(opts) do
    init(opts)
  end

  def init({client, addr, port, packet_rest}) do
    opts = [:binary, {:packet, :raw}, {:active, false}]

    case :gen_tcp.connect(addr, port, opts, @timeout) do
      {:ok, socket} ->
        :ok =
          :gen_tcp.send(
            client,
            <<@rfc_1928_version, @rfc_1928_replies[:succeeded]>> <> packet_rest
          )

        spawn_link(fn ->
          pipe_socket(client, socket, "client -> socket")
        end)

        pipe_socket(socket, client, "socket -> client")

      {:error, :econnrefused} ->
        end_conn(client, <<@rfc_1928_replies[:connection_refused]>> <> packet_rest)

      {:error, :eaddrnotavail} ->
        end_conn(client, <<@rfc_1928_replies[:network_unreachable]>> <> packet_rest)

      {:error, _error} ->
        end_conn(client, <<@rfc_1928_replies[:general_failure]>> <> packet_rest)
    end
  end

  defp pipe_socket(a, b, string) do
    with {:ok, packet} <- :gen_tcp.recv(a, 0),
         :ok <- :gen_tcp.send(b, packet) do
      pipe_socket(a, b, string)
      Logger.debug("#{string} #{inspect(packet)}")
    else
      error ->
        Logger.debug("#{string} #{inspect(error)}")
    end
  end

  defp end_conn(client, response) do
    Logger.debug("Closing: #{inspect(:inet.peername(client))}")
    :ok = :gen_tcp.send(client, <<@rfc_1928_version>> <> response)
    :ok = :gen_tcp.close(client)
  end
end
