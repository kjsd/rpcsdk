defmodule Rpcsdk.RequestBrokerTest do
  use ExUnit.Case
  doctest Rpcsdk.RequestBroker

  setup_all do
    children = [
      {DynamicSupervisor, name: RequestBrokerTest.Supervisor,
       strategy: :one_for_one},
      {Registry, keys: :unique, name: RequestBrokerTest.Registry},
    ]

    Supervisor.start_link(children, strategy: :one_for_all)

    defmodule Impl do
      use Rpcsdk.RequestBroker,
        supervisor: RequestBrokerTest.Supervisor,
        registry: RequestBrokerTest.Registry

      def echo_call(id, msg), do: call_stub(:echoa, id, [msg], :infinity)
      def echo_cast(id, msg), do: cast_stub(:echob, id, [msg])
      
      @impl Rpcsdk.RequestBroker
      def get_key(id), do: id

      @impl true
      def handle_call({:echoa, _, msg}, _, s) do
        {:reply, msg, s}
      end

      @impl true
      def handle_cast({:echob, id, msg}, s) do
        IO.inspect("#{id}: #{msg}")
        {:noreply, s}
      end
    end
    |> elem(1)
    |> then(&({:ok, %{impl: &1}}))
  end
  
  test "call_stub", %{impl: impl} do
    res = impl.echo_call(1, "hello")
    assert "hello" == res
  end

  test "cast_stub", %{impl: impl} do
    res = impl.echo_cast(1, "hello RB")
    assert :ok == res
    Process.sleep(300)
  end

  test "join", %{impl: impl} do
    res = impl.join(1)
    assert :ok == res
  end
end
