defmodule ElixirSock5.Acceptor do
  def child_spec(_opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, []},
      type: :worker,
      restart: :permanent,
      shutdown: 500
    }
  end

  def start_link do
    port = Application.get_env(:elixir_socks5, :port)

    :ranch.start_listener(make_ref(), :ranch_tcp, [{:port, port}], ElixirSock5.Protocol, [])
  end
end
