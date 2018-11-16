defmodule ElixirSock5.Protocol do
  @behaviour :ranch_protocol

  require Logger
  alias ElixirSocks5.{Handshake, Authentication, Connect, Forwarder}
  @timeout 1000

  @rfc_1928_version 0x05
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

  @rfc_1929_version 0x01
  @rfc_1929_replies %{
    succeeded: 0x00,
    general_failure: 0xFF
  }

  def start_link(ref, _socket, transport, opts) do
    pid = :proc_lib.spawn_link(__MODULE__, :init, [ref, transport, opts])
    {:ok, pid}
  end

  def init(ref, transport, _opts = []) do
    {:ok, socket} = :ranch.handshake(ref)
    socks_handshake({socket, transport})
  end

  defp socks_handshake({socket, transport} = st) do
    {:ok, packet} = transport.recv(socket, 0, @timeout)
    handshake = Handshake.new(packet)
    Logger.debug(handshake)
    socks_handshake(st, handshake)
  end

  defp socks_handshake(st, :error) do
    end_conn(st, <<@rfc_1928_replies[:general_failure]>>)
  end

  defp socks_handshake({socket, transport} = st, %Handshake{methods: methods}) do
    basic_authentication = Application.get_env(:elixir_socks5, :authentication)

    cond do
      basic_authentication && Enum.member?(methods, @rfc_1928_methods[:basic_authentication]) ->
        message = <<@rfc_1928_version, @rfc_1928_methods[:basic_authentication]>>
        :ok = transport.send(socket, message)
        socks_authentication(st)

      !basic_authentication &&
          Enum.member?(methods, @rfc_1928_methods[:no_authentication_required]) ->
        message = <<@rfc_1928_version, @rfc_1928_methods[:no_authentication_required]>>
        :ok = transport.send(socket, message)
        socks_connect(st)

      true ->
        message = <<@rfc_1928_version, @rfc_1928_methods[:no_acceptable_methods]>>
        :ok = transport.send(socket, message)
    end
  end

  defp socks_authentication({socket, transport} = st) do
    {:ok, packet} = transport.recv(socket, 0, @timeout)
    authentication = Authentication.new(packet)
    Logger.debug(authentication)
    socks_authentication(st, authentication)
  end

  defp socks_authentication(st, :error) do
    end_conn(st, <<@rfc_1929_replies[:general_failure]>>)
  end

  defp socks_authentication({socket, transport} = st, %Authentication{
         uname: uname,
         passwd: passwd
       }) do
    username = Application.get_env(:elixir_socks5, :username)
    password = Application.get_env(:elixir_socks5, :password)

    case username == uname && password == passwd do
      true ->
        :ok = transport.send(socket, <<@rfc_1929_version, @rfc_1929_replies[:succeeded]>>)
        socks_connect(st)

      false ->
        socks_authentication(st, :error)
    end
  end

  defp socks_connect({socket, transport} = st) do
    {:ok, packet} = transport.recv(socket, 0, @timeout)
    connect = Connect.new(packet)
    Logger.debug(connect)
    socks_connect(st, connect, packet)
  end

  defp socks_connect(st, :error, _packet) do
    end_conn(st, <<@rfc_1928_replies[:general_failure]>>)
  end

  defp socks_connect(
         {socket, transport} = st,
         %Connect{cmd: @rfc_1928_commands_connect, addr: addr, port: port},
         <<_drop::size(16), packet_rest::binary>>
       ) do
    opts = [:binary, {:packet, :raw}, {:active, false}]

    case :gen_tcp.connect(addr, port, opts, @timeout) do
      {:ok, ssocket} ->
        message = <<@rfc_1928_version, @rfc_1928_replies[:succeeded]>> <> packet_rest
        :ok = transport.send(socket, message)

        spawn_link(fn ->
          pipe_socket(st, ssocket)
        end)

        pipe_socket(ssocket, st)

      {:error, _error} ->
        end_conn(st, <<@rfc_1928_replies[:general_failure]>> <> packet_rest)
    end
  end

  defp pipe_socket({socket, transport} = st, ssocket) do
    with {:ok, packet} <- transport.recv(socket, 0, @timeout),
         :ok <- :gen_tcp.send(ssocket, packet) do
      pipe_socket(st, ssocket)
      Logger.debug("ranch_socket ~> ssocket #{inspect(packet)}")
    else
      error ->
        Logger.debug("ranch_socket ~> ssocket #{inspect(error)}")
        transport.close(socket)
        :gen_tcp.close(ssocket)
    end
  end

  defp pipe_socket(ssocket, {socket, transport} = st) do
    with {:ok, packet} <- :gen_tcp.recv(ssocket, 0, @timeout),
         :ok <- transport.send(socket, packet) do
      pipe_socket(ssocket, st)
      Logger.debug("ssocket ~> ranch_socket #{inspect(packet)}")
    else
      error ->
        Logger.debug("ssocket ~> ranch_socket #{inspect(error)}")
        transport.close(socket)
        :gen_tcp.close(ssocket)
    end
  end

  def end_conn({socket, transport}, response) do
    Logger.debug("Closing: #{inspect(:inet.peername(socket))}")
    :ok = transport.send(socket, <<@rfc_1928_version>> <> response)
    :ok = transport.close(socket)
  end
end
