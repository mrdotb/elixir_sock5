defmodule ConnectTest do
  use ExUnit.Case
  alias ElixirSocks5.Connect

  test "valid connect ipv4" do
    packet = <<5, 1, 0, 1, 92, 222, 85, 135, 0, 80>>

    assert %Connect{ver: 5, cmd: 1, rsv: 0, atyp: 1, addr: {92, 222, 85, 135}, port: 80} =
             Connect.new(packet)
  end

  test "valid connect ipv6" do
    packet = <<5, 1, 0, 4, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 31, 64>>

    assert %Connect{ver: 5, cmd: 1, rsv: 0, atyp: 4, addr: {0, 0, 0, 0, 0, 0, 0, 1}, port: 8000} =
             Connect.new(packet)
  end

  test "invalid connect 1" do
    packet = <<5, 1, 0, 1, 92, 222, 85, 135, 0, 0, 80>>
    assert :error = Connect.new(packet)
  end

  test "invalid connect 2" do
    packet = <<5, 1, 0, 4, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 31, 64>>
    assert :error = Connect.new(packet)
  end
end
