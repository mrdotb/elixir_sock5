defmodule ElixirSock5.Supervisor do
  use Supervisor

  @doc """
  It start the main supervisor
  """
  def start_link do
    Supervisor.start_link(__MODULE__, [], name: __MODULE__)
  end

  @doc false
  def init(_) do
    acceptor = {ElixirSock5.Acceptor, []}

    children = [acceptor]
    Supervisor.init(children, strategy: :one_for_one)
  end
end
