defmodule ElixirSocks5.Forwarder do
  require Logger
  use GenServer

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

  ## Client
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  ## Server
  def init({client, addr, port, packet_rest}) do
    opts = [:binary, {:packet, :raw}, {:active, true}]

    case :gen_tcp.connect(addr, port, opts, @timeout) do
      {:ok, socket} ->
        :ok =
          :gen_tcp.send(client, <<@rfc_1928_version, @rfc_1928_replies[:succeeded]>> <> packet_rest)

          loop_pipe(client, socket)

      {:error, :econnrefused} ->
        end_conn(client, <<@rfc_1928_replies[:connection_refused]>> <> packet_rest)

      {:error, :eaddrnotavail} ->
        end_conn(client, <<@rfc_1928_replies[:network_unreachable]>> <> packet_rest)

      {:error, _error} ->
        end_conn(client, <<@rfc_1928_replies[:general_failure]>> <> packet_rest)
    end

    {:ok, %{client: client}}
  end

  def loop_pipe(client, socket) do
    Logger.debug("loop_pipe")
    spawn fn ->
      case :gen_tcp.recv(client, 0) do
        {:ok, packet} ->
          :ok = :gen_tcp.send(socket, packet)
          loop_pipe(client, socket)

        other -> IO.inspect(other)
      end
    end
  end

  def handle_info({:tcp, socket, packet}, state = %{client: client}) do
    Logger.debug("packet: #{inspect(packet)}")
    :ok = :gen_tcp.send(client, packet)

    {:noreply, state}
  end

  def handle_info({:tcp_closed, socket}, state = %{client: client}) do
    :ok = :gen_tcp.close(client)
    Logger.debug("Connection closed")
    {:noreply, state}
  end

  def handle_info({:tcp_error, socket, reason}, state) do
    Logger.debug("Connection closed due to #{inspect(reason)}")
    {:noreply, state}
  end

  def handle_info(all, state) do
    Logger.debug("all #{inspect(all)}")
    {:noreply, state}
  end

  ## Utility
  defp end_conn(client, response) do
    Logger.debug("Closing: #{inspect(:inet.peername(client))}")
    :ok = :gen_tcp.send(client, <<@rfc_1928_version>> <> response)
    :ok = :gen_tcp.close(client)
    # GenServer.stop(self(), :normal)
  end
end
