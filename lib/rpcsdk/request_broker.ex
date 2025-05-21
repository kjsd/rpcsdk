defmodule Rpcsdk.RequestBroker do
  @callback get_key(id :: term) :: key :: term
  @callback initialize() :: state :: term

  defmacro __using__(opts) do
    supervisor_m = Keyword.get(opts, :supervisor_m, DynamicSupervisor)
    registry_m = Keyword.get(opts, :registry_m, Registry)
    supervisor = Keyword.get(opts, :supervisor)
    registry = Keyword.get(opts, :registry)
    initial_state = Keyword.get(opts, :initial_state, [])

    quote do
      use GenServer
      @behaviour unquote(__MODULE__)

      def initialize(), do: unquote(initial_state)
      def join(id), do: call_stub(:join, id, [], :infinity)
      
      defoverridable initialize: 0

      # Helper APIs
      def start_link(args) do
        state = initialize()
        opts = args |> Keyword.take([:name])
        GenServer.start_link(__MODULE__, state, opts)
      end

      @impl GenServer
      def init(state) do
        Process.flag(:trap_exit, true)
        {:ok, state}
      end

      @impl GenServer
      def handle_call({:join, _}, _, s), do: {:reply, :ok, s}

      def get_child(nil), do: nil
      def get_child(key) do
        case unquote(registry_m).lookup(unquote(registry), name(key)) do
          [{pid, _}] ->
            pid

          _ ->
            spec = __MODULE__.child_spec([name: process(key)])

            unquote(supervisor_m).start_child(unquote(supervisor), spec)
            |> case do
                 {:ok, x} ->
                   x

                 {:error, {:already_started, x}} ->
                   x
               end
        end
      end

      def terminate_child(key) do
        with [{pid, _}] <- unquote(registry_m).lookup(unquote(registry), name(key)) do
          unquote(supervisor_m).terminate_child(unquote(supervisor), pid)
        end
      end

      defp call_stub(name, id, args \\ [], timeout \\ 5000) do
        request = Enum.reduce(args, {name, id},
          &(Tuple.insert_at(&2, tuple_size(&2), &1)))

        try do
          id
          |> get_key()
          |> get_child()
          |> GenServer.call(request, timeout)
        catch
          :exit, e ->
            {:error, e}
        end
      end

      defp cast_stub(name, id, args \\ []) do
        request = Enum.reduce(args, {name, id},
          &(Tuple.insert_at(&2, tuple_size(&2), &1)))

        try do
          id
          |> get_key()
          |> get_child()
          |> GenServer.cast(request)
        catch
          :exit, e ->
            {:error, e}
        end
      end

      defp process(key), do: {:via, unquote(registry_m), {unquote(registry), name(key)}}
      defp name(key), do: "request_broker_#{key}"
    end
  end
end
