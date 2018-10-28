defmodule ElixirSocks5.Forwarder do
  require Logger
  use GenServer

  @timeout 1000

  @rfc_1928_version 0x05
  @rfc_1928_replies_succeeded 0x00
  @rfc_connection_refused 0x05

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
          :gen_tcp.send(client, <<@rfc_1928_version, @rfc_1928_replies_succeeded>> <> packet_rest)

        {:ok, request} = :gen_tcp.recv(client, 0, @timeout)
        Logger.debug("request: #{request}")
        :ok = :gen_tcp.send(socket, request)

      {:error, :econnrefused} ->
        end_conn(client, <<@rfc_connection_refused>> <> packet_rest)

      all ->
        Logger.debug("all #{all}")
    end

    {:ok, %{client: client}}
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

  ## Utility
  defp end_conn(client, response) do
    Logger.debug("Closing: #{inspect(:inet.peername(client))}")
    :ok = :gen_tcp.send(client, <<@rfc_1928_version>> <> response)
    :ok = :gen_tcp.close(client)
    # GenServer.stop(self(), :normal)
  end
end
