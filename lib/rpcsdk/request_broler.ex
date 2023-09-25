defmodule Rpcsdk.RequestBroker do
  @callback get_key(id :: term) :: key :: term
  @callback initialize() :: state :: term

  defmacro __using__(opts) do
    supervisor = Keyword.get(opts, :supervisor)
    registry = Keyword.get(opts, :registry)
    initial_state = Keyword.get(opts, :initial_state, [])

    quote do
      use GenServer
      @behaviour unquote(__MODULE__)

      def initialize(), do: unquote(initial_state)
      
      defoverridable initialize: 0

      # Helper APIs
      def start_link(args) do
        state = initialize()
        opts = args |> Keyword.take([:name])
        GenServer.start_link(__MODULE__, state, opts)
      end

      @impl GenServer
      def init(state), do: {:ok, state}

      def get_child(nil), do: nil
      def get_child(key) do
        case Registry.lookup(unquote(registry), name(key)) do
          [{pid, _}] ->
            pid

          _ ->
            spec = __MODULE__.child_spec([name: process(key)])

            DynamicSupervisor.start_child(unquote(supervisor), spec)
            |> case do
                 {:ok, x} ->
                   x

                 {:error, {:already_started, x}} ->
                   x
               end
        end
      end

      def terminate_child(key) do
        with [{pid, _}] <- Registry.lookup(unquote(registry), name(key)) do
          DynamicSupervisor.terminate_child(unquote(supervisor), pid)
        end
      end

      defp call_stub(name, id, args \\ [], timeout \\ 5000) do
        request = Enum.reduce(args, {name, id}, &(Tuple.append(&2, &1)))

        try do
          id
          |> get_key()
          |> get_child()
          |> GenServer.call(request, timeout)
        catch
          :exit, _ ->
            {:error, :not_found}
        end
      end

      defp cast_stub(name, id, args \\ []) do
        request = Enum.reduce(args, {name, id}, &(Tuple.append(&2, &1)))

        try do
          id
          |> get_key()
          |> get_child()
          |> GenServer.cast(request)
        catch
          :exit, _ ->
            {:error, :not_found}
        end
      end

      defp process(key), do: {:via, Registry, {unquote(registry), name(key)}}
      defp name(key), do: "request_broker_#{key}"
    end
  end
end
