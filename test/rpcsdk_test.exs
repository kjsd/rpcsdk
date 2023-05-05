defmodule RpcsdkTest do
  use ExUnit.Case
  doctest Rpcsdk

  test "greets the world" do
    assert Rpcsdk.hello() == :world
  end
end
