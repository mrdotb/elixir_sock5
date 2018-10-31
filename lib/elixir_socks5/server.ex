defmodule ElixirSocks5.Server do
  require Logger
  alias ElixirSocks5.Handshake
  alias ElixirSocks5.Authentication
  alias ElixirSocks5.Connect
  alias ElixirSocks5.Forwarder

  @timeout 1000

  @rfc_1928_commands_connect 0x01
  @rfc_1928_commands_bind 0x02
  @rfc_1928_commands_udp_associate 0x03

  @rfc_1928_methods %{
    no_authentication_required: 0x00,
    gssapi: 0x01,
    basic_authentication: 0x02,
    no_acceptable_methods: 0xFF
  }

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

  @rfc_1928_version 0x05

  def accept do
    port = Application.get_env(:elixir_socks5, :port)
    opts = [:binary, {:packet, :raw}, {:active, false}]
    {:ok, socket} = :gen_tcp.listen(port, opts)

    Logger.info("Accepting connections on port #{port}")
    loop_acceptor(socket)
  end

  defp loop_acceptor(socket) do
    {:ok, client} = :gen_tcp.accept(socket)

    Task.Supervisor.start_child(ElixirSocks5.TaskSupervisor, fn ->
      Logger.info("New connection from #{inspect(:inet.peername(client))}")
      socks_handshake(client)
    end)

    loop_acceptor(socket)
  end

  defp socks_handshake(client) do
    {:ok, packet} = :gen_tcp.recv(client, 0, @timeout)
    handshake = Handshake.new(packet)
    Logger.debug(handshake)
    socks_handshake(client, handshake)
  end

  defp socks_handshake(client, :error) do
    end_conn(client, @rfc_1928_replies[:GENERAL_FAILURE])
  end

  defp socks_handshake(client, _handshake = %Handshake{}) do
    case Application.get_env(:elixir_socks5, :authentication) do
      true ->
        :ok =
          :gen_tcp.send(client, <<@rfc_1928_version, @rfc_1928_methods[:basic_authentication]>>)

        socks_authentication(client)

      false ->
        :ok =
          :gen_tcp.send(
            client,
            <<@rfc_1928_version, @rfc_1928_methods[:no_authentication_required]>>
          )

        socks_connect(client)
    end
  end

  defp socks_authentication(client) do
    {:ok, packet} = :gen_tcp.recv(client, 0, @timeout)
    authentication = Authentication.new(packet)
    Logger.debug(authentication)
    socks_authentication(client, authentication)
  end

  defp socks_authentication(client, :error) do
    end_conn(client, @rfc_1928_replies[:general_failure])
  end

  defp socks_authentication(client, %Authentication{uname: uname, passwd: passwd}) do
    username = Application.get_env(:elixir_socks5, :username)
    password = Application.get_env(:elixir_socks5, :password)

    case username == uname && password == passwd do
      true ->
        :ok = :gen_tcp.send(client, <<@rfc_1928_version, @rfc_1928_replies[:succeeded]>>)
        socks_connect(client)

      false ->
        socks_authentication(client, :error)
    end
  end

  defp socks_connect(client) do
    {:ok, packet} = :gen_tcp.recv(client, 0, @timeout)
    connect = Connect.new(packet)
    Logger.debug(connect)
    socks_connect(client, connect, packet)
  end

  defp socks_connect(client, :error, _packet) do
    end_conn(client, @rfc_1928_replies[:general_failure])
  end

  defp socks_connect(
         client,
         %Connect{cmd: @rfc_1928_commands_connect, addr: addr, port: port},
         <<_drop::size(16), packet_rest::binary>>
       ) do
    Forwarder.start_link({client, addr, port, packet_rest})
  end

  def end_conn(client, response) do
    Logger.debug("Closing: #{inspect(:inet.peername(client))}")
    :ok = :gen_tcp.send(client, <<@rfc_1928_version>> <> response)
    :ok = :gen_tcp.close(client)
  end
end
