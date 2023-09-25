defmodule Rpcsdk.Crawler do
  @callback handle_crawling(item :: term, key :: term,
    state :: {interval :: integer, args :: term})
  :: result :: term
  @callback handle_crawled(results :: [term], key :: term,
    state :: {interval :: integer, args :: term})
  :: next_state :: {next_interval :: integer, args :: term}
  @callback initialize() :: state :: term

  defmacro __using__(opts) do
    queue = Keyword.get(opts, :queue)
    max_request = Keyword.get(opts, :max_request, 100)
    interval_ms = Keyword.get(opts, :interval_ms, 100)
    initial_args = Keyword.get(opts, :initial_args, nil)
    sync = Keyword.get(opts, :sync, false)
    wait = Keyword.get(opts, :wait, false)

    quote do
      use GenServer
      @behaviour unquote(__MODULE__)

      def initialize(), do: unquote(initial_args)
      def handle_crawled(_, _, state), do: state
      
      defoverridable initialize: 0
      defoverridable handle_crawled: 3

      # Helper APIs
      def start_link(args) do
        state = initialize()
        opts = args |> Keyword.take([:name])
        key = Keyword.get(args, :key)

        GenServer.start_link(__MODULE__, [
              key: key, state: {unquote(interval_ms), state}], opts)
      end

      # GenServer callbacks
      @impl GenServer
      def init([key: _, state: {interval, _}] = args) do
        schedule(interval)
        {:ok, args}
      end

      @impl GenServer
      def handle_info(:crawl, [key: key, state: {interval, _} = state]) do
        items = Enum.reduce_while(1..unquote(max_request), [], fn _, acc ->
          case unquote(queue).dequeue(key) do
            nil ->
              {:halt, acc}
            x ->
              {:cont, [x | acc]}
          end
        end)
        |> Enum.reverse()

        results =
          case {unquote(sync), unquote(wait)} do
            {true, _} ->
              items
              |> Enum.map(fn x ->
                Task.async(fn -> handle_crawling(x, key, state) end)
                |> Task.await(:infinity)
              end)

            {false, true} ->
              items
              |> Task.async_stream(__MODULE__, :handle_crawling, [
                    key, state], ordered: false, timeout: :infinity)
              |> Enum.filter(&(match?({:ok, x}, &1)))
              |> Enum.map(fn {:ok, x} -> x end)
              
            _ ->
              items
              |> Enum.map(&(spawn(fn -> handle_crawling(&1, key, state) end)))
          end

        {next_interval, _} = next_state = handle_crawled(results, key, state)

        schedule(next_interval)
        {:noreply, [key: key, state: next_state]}
      end

      defp schedule(ms), do: Process.send_after(self(), :crawl, ms)
    end
  end
end
