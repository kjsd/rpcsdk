defmodule Rpcsdk.Queue do
  def child_spec(_), do: nil

  defmacro __using__(opts) do
    supervisor_m = Keyword.get(opts, :supervisor_m, DynamicSupervisor)
    registry_m = Keyword.get(opts, :registry_m, Registry)
    supervisor = Keyword.get(opts, :supervisor)
    registry = Keyword.get(opts, :registry)
    crawler = Keyword.get(opts, :crawler, __MODULE__)

    quote do
      use GenServer

      # Helper APIs
      def start_link(args) do
        opts = args |> Keyword.take([:name])
        GenServer.start_link(__MODULE__, [], opts)
      end

      def enqueue(nil, value), do: :ok
      def enqueue(key, value) do
        case unquote(registry_m).lookup(unquote(registry), queue_name(key)) do
          [{pid, _}] ->
            {:ok, pid}

          _ ->
            queue_spec = [name: queue_process(key)]
            |> __MODULE__.child_spec()

            unquote(supervisor_m).start_child(unquote(supervisor), queue_spec)
            |> case do
                 {:ok, _} = x ->
                   x

                 {:error, {:already_started, x}} ->
                   {:ok, x}
               end
               |> case do
                    {:ok, _} = x ->
                      if has_crawler?() do
                        crawler_spec = [name: crawler_process(key), key: key]
                        |> unquote(crawler).child_spec()

                        unquote(supervisor_m).start_child(unquote(supervisor), crawler_spec)
                      end
                      x
                  end
        end
        |> case do
             {:ok, pid} ->
               pid |> GenServer.cast({:enqueue, value})
             e ->
               e
           end
      end

      def dequeue(key) do
        try do
          queue_process(key)
          |> GenServer.call(:dequeue)
        catch
          :exit, _ -> nil
        end
      end
          
      def clear(key) do
        try do
          queue_process(key)
          |> GenServer.cast(:clear)
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
        with true <- has_crawler?(),
             [{pid, _}] <- unquote(registry_m).lookup(unquote(registry),
               crawler_name(key)) do
          unquote(supervisor_m).terminate_child(unquote(supervisor), pid)
        end

        with [{pid, _}] <- unquote(registry_m).lookup(unquote(registry),
                  queue_name(key)) do
          unquote(supervisor_m).terminate_child(unquote(supervisor), pid)
        end
      end

      def crawl(key) do
        with true <- has_crawler?(),
             [{pid, _}] <- unquote(registry_m).lookup(unquote(registry),
                  crawler_name(key)) do
          send(pid, :crawl)
        end
      end
      
      def has_crawler?(), do: unquote(crawler).child_spec([]) != nil
        
      # GenServer callbacks
      @impl GenServer
      def init(state \\ []), do: {:ok, state}

      @impl GenServer
      def handle_cast({:enqueue, value}, state), do: {:noreply, state ++ [value]}

      @impl GenServer
      def handle_call(:dequeue, _, [value | state]), do: {:reply, value, state}
      def handle_call(:dequeue, _, []), do: {:reply, nil, []}

      @impl GenServer
      def handle_cast(:clear, state), do: {:noreply, []}

      @impl GenServer
      def handle_call(:queue, _, state), do: {:reply, state, state}

      defp queue_process(key),
        do: {:via, unquote(registry_m), {unquote(registry), queue_name(key)}}
      defp crawler_process(key),
        do: {:via, unquote(registry_m), {unquote(registry), crawler_name(key)}}

      defp queue_name(key), do: "rpcsdk_queue_#{key}"
      defp crawler_name(key), do: "rpcsdk_crawler_#{key}"

    end
  end
end
