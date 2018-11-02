defmodule HanshakeTest do
  use ExUnit.Case
  alias ElixirSocks5.Handshake

  test "valid handshake 1" do
    packet = <<5, 2, (<<0, 1>>)>>
    assert %Handshake{ver: 5, nmethods: 2, methods: [0, 1]} = Handshake.new(packet)
  end

  test "valid handshake 2" do
    packet = <<5, 3, (<<0, 1, 2>>)>>
    assert %Handshake{ver: 5, nmethods: 3, methods: [0, 1, 2]} = Handshake.new(packet)
  end

  test "invalid handshake version" do
    packet = <<0, 3, (<<0, 1>>)>>
    assert :error = Handshake.new(packet)
  end

  test "invalid handshake nmethods" do
    packet = <<5, 3, (<<0, 1>>)>>
    assert :error = Handshake.new(packet)
  end
end
