defmodule ElixirSocks5.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, _args) do
    # List all child processes to be supervised
    children = [
      {Task.Supervisor, name: ElixirSocks5.TaskSupervisor},
      Supervisor.child_spec({Task, fn -> ElixirSocks5.Server.accept() end}, restart: :permanent)
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: ElixirSocks5.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
