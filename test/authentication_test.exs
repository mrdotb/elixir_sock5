defmodule AuthenticationTest do
  use ExUnit.Case
  alias ElixirSocks5.Authentication

  test "valid auth 1" do
    packet =
      <<1, 8, 117, 115, 101, 114, 110, 97, 109, 101, 8, 112, 97, 115, 115, 119, 111, 114, 100>>

    assert %Authentication{ver: 1, ulen: 8, uname: "username", plen: 8, passwd: "password"} =
             Authentication.new(packet)
  end

  test "valid auth 2" do
    packet = <<1, 3, 102, 111, 111, 3, 98, 97, 114>>

    assert %Authentication{ver: 1, ulen: 3, uname: "foo", plen: 3, passwd: "bar"} =
             Authentication.new(packet)
  end

  test "invalid auth version" do
    packet = <<0, 0>>
    assert :error = Authentication.new(packet)
  end

  test "invalid ulen" do
    packet = <<1, 5, 102, 111, 111, 3, 98, 97, 114>>
    assert :error = Authentication.new(packet)
  end

  test "invalid plen" do
    packet = <<1, 5, 102, 111, 111, 0, 98, 97, 114>>
    assert :error = Authentication.new(packet)
  end
end
