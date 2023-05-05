defmodule Rpcsdk.Queue do
  defmacro __using__(opts) do
    supervisor = Keyword.get(opts, :supervisor)
    registry = Keyword.get(opts, :registry)
    crawler = Keyword.get(opts, :crawler)

    quote do
      use GenServer

      # Helper APIs
      def start_link(args) do
        opts = args |> Keyword.take([:name])
        GenServer.start_link(__MODULE__, [], opts)
      end

      def enqueue(nil, value), do: :ok
      def enqueue(key, value) do
        case Registry.lookup(unquote(registry), queue_name(key)) do
          [{pid, _}] ->
            pid

          _ ->
            queue_spec = [name: queue_process(key)]
            |> __MODULE__.child_spec()

            pid = DynamicSupervisor.start_child(unquote(supervisor), queue_spec)
            |> case do
                 {:ok, x} ->
                   x

                 {:error, {:already_started, x}} ->
                   x
               end

            crawler_spec = [name: crawler_process(key), key: key]
            |> unquote(crawler).child_spec()

            DynamicSupervisor.start_child(unquote(supervisor), crawler_spec)

            pid
        end
        |> GenServer.cast({:enqueue, value})
      end

      def dequeue(key) do
        try do
          queue_process(key)
          |> GenServer.call(:dequeue)
        catch
          :exit, _ -> nil
        end
      end
          

      def queue(key) do
        try do
          queue_process(key)
          |> GenServer.call(:queue)
        catch
          :exit, _ -> []
        end
      end

      def terminate(key) do
        with [{pid, _}] <- Registry.lookup(unquote(registry), crawler_name(key)) do
          DynamicSupervisor.terminate_child(unquote(supervisor), pid)
        end

        with [{pid, _}] <- Registry.lookup(unquote(registry), queue_name(key)) do
          DynamicSupervisor.terminate_child(unquote(supervisor), pid)
        end
      end

      # GenServer callbacks
      @impl GenServer
      def init(state \\ []), do: {:ok, state}

      @impl GenServer
      def handle_cast({:enqueue, value}, state), do: {:noreply, state ++ [value]}

      @impl GenServer
      def handle_call(:dequeue, _, [value | state]), do: {:reply, value, state}
      def handle_call(:dequeue, _, []), do: {:reply, nil, []}

      @impl GenServer
      def handle_call(:queue, _, state), do: {:reply, state, state}

      defp queue_process(key),
        do: {:via, Registry, {unquote(registry), queue_name(key)}}
      defp crawler_process(key),
        do: {:via, Registry, {unquote(registry), crawler_name(key)}}

      defp queue_name(key), do: "rpcsdk_queue_#{key}"
      defp crawler_name(key), do: "rpcsdk_crawler_#{key}"
    end
  end
end
