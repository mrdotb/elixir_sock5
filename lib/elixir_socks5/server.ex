defmodule ElixirSocks5.Server do
  require Logger
  alias ElixirSocks5.Handshake
  alias ElixirSocks5.Authentication
  alias ElixirSocks5.Connect
  alias ElixirSocks5.Forwarder

  @timeout 1000

  @rfc_1928_ATYP %{
    IPV4: 0x01,
    DOMAINNAME: 0x03,
    IPV6: 0x04
  }

  @rfc_1928_COMMANDS_CONNECT 0x01
  @rfc_1928_COMMANDS_BIND 0x02
  @rfc_1928_COMMANDS_UDP_ASSOCIATE 0x03

  @rfc_1928_METHODS %{
    NO_AUTHENTICATION_REQUIRED: 0x00,
    GSSAPI: 0x01,
    BASIC_AUTHENTICATION: 0x02,
    NO_ACCEPTABLE_METHODS: 0xFF
  }

  @rfc_1928_REPLIES %{
    SUCCEEDED: 0x00,
    GENERAL_FAILURE: 0x01,
    CONNECTION_NOT_ALLOWED: 0x02,
    NETWORK_UNREACHABLE: 0x03,
    HOST_UNREACHABLE: 0x04,
    CONNECTION_REFUSED: 0x05,
    TTL_EXPIRED: 0x06,
    COMMAND_NOT_SUPPORTED: 0x07,
    ADDRESS_TYPE_NOT_SUPPORTED: 0x08
  }

  @rfc_1928_VERSION 0x05

  @rfc_1928_REPLIES_SUCCEEDED 0x00

  @rfc_1929_REPLIES %{
    SUCCEEDED: 0x00,
    GENERAL_FAILURE: 0xFF
  }

  @rfc_1929_VERSION 0x01

  def accept(port \\ 1080) do
    opts = [:binary, {:packet, :raw}, {:active, false}, {:reuseaddr, true}]
    {:ok, socket} = :gen_tcp.listen(port, opts)

    Logger.info("Accepting connections on port #{port}")
    loop_acceptor(socket)
  end

  defp loop_acceptor(socket) do
    {:ok, client} = :gen_tcp.accept(socket)

    Task.Supervisor.start_child(ElixirSocks5.TaskSupervisor, fn ->
      Logger.info("New connection from #{inspect(:inet.peername(client))}")
      socks(:handshake, client)
    end)

    loop_acceptor(socket)
  end

  defp socks(:handshake, client) do
    {:ok, packet} = :gen_tcp.recv(client, 0, @timeout)
    handshake = Handshake.new(packet)
    Logger.debug(handshake)
    socks(:handshake, client, handshake)
  end

  defp socks(:handshake, client, :error) do
    end_conn(client, @rfc_1928_REPLIES[:GENERAL_FAILURE])
  end

  defp socks(:handshake, client, _handshake = %Handshake{}) do
    case Application.get_env(:elixir_socks5, :authentication) do
      true ->
        :ok =
          :gen_tcp.send(client, <<@rfc_1928_VERSION, @rfc_1928_METHODS[:BASIC_AUTHENTICATION]>>)

        socks(:authentication, client)

      false ->
        :ok =
          :gen_tcp.send(
            client,
            <<@rfc_1928_VERSION, @rfc_1928_METHODS[:NO_AUTHENTICATION_REQUIRED]>>
          )

        socks(:connect, client)
    end
  end

  defp socks(:authentication, client) do
    {:ok, packet} = :gen_tcp.recv(client, 0, @timeout)
    authentication = Authentication.new(packet)
    Logger.debug(authentication)
    socks(:authentication, client, authentication)
  end

  defp socks(:authentication, client, :error) do
    end_conn(client, @rfc_1928_REPLIES[:GENERAL_FAILURE])
  end

  defp socks(:authentication, client, %Authentication{uname: uname, passwd: passwd}) do
    username = Application.get_env(:elixir_socks5, :username)
    password = Application.get_env(:elixir_socks5, :password)

    case username == uname && password == passwd do
      true ->
        :ok = :gen_tcp.send(client, <<@rfc_1928_VERSION, @rfc_1928_REPLIES[:SUCCEEDED]>>)
        socks(:connect, client)

      false ->
        socks(:authentication, client, :error)
    end
  end

  defp socks(:connect, client) do
    {:ok, packet} = :gen_tcp.recv(client, 0, @timeout)
    connect = Connect.new(packet)
    Logger.debug(connect)
    socks(:connect, client, connect, packet)
  end

  defp socks(:connect, client, :error, _packet) do
    end_conn(client, @rfc_1928_REPLIES[:GENERAL_FAILURE])
  end

  defp socks(
         :connect,
         client,
         %Connect{cmd: @rfc_1928_COMMANDS_CONNECT, addr: addr, port: port},
         <<_drop::size(16), packet_rest::binary>>
       ) do
    Forwarder.start_link({client, addr, port, packet_rest})
  end

  def end_conn(client, response) do
    Logger.debug("Closing: #{inspect(:inet.peername(client))}")
    :ok = :gen_tcp.send(client, <<@rfc_1928_VERSION>> <> response)
    :ok = :gen_tcp.close(client)
  end
end
