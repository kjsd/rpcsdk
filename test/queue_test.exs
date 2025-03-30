defmodule Rpcsdk.QueueTest do
  use ExUnit.Case
  doctest Rpcsdk.Queue

  setup_all do
    children = [
      {DynamicSupervisor, name: QueueTest.Supervisor,
       strategy: :one_for_one},
      {Registry, keys: :unique, name: QueueTest.Registry},
    ]

    Supervisor.start_link(children, strategy: :one_for_all)

    defmodule CrawlerImpl do
      use Rpcsdk.Crawler, queue: Rpcsdk.QueueTest.QueueImpl, interval_ms: 5000

      @impl Rpcsdk.Crawler
      def handle_crawling({:echo, msg}, _key, _state) do
        IO.inspect(msg)
      end
    end

    defmodule QueueImpl do
      use Rpcsdk.Queue,
        supervisor: QueueTest.Supervisor,
        registry: QueueTest.Registry,
        crawler: Rpcsdk.QueueTest.CrawlerImpl
    end
    |> elem(1)
    |> then(&({:ok, %{impl: &1}}))
  end
  
  test "enqueue", %{impl: impl} do
    assert :ok == impl.enqueue(1, {:echo, "hello Clawlar"})
    impl.crawl(1)
    Process.sleep(300)
  end

  test "dequeue", %{impl: impl} do
    assert nil == impl.dequeue(1) 

    impl.enqueue(1, {:echo, "hello"})
    assert {:echo, "hello"} == impl.dequeue(1) 
  end

  test "queue", %{impl: impl} do
    assert [] == impl.queue(1) 

    impl.enqueue(1, {:echo, "hello"})
    assert [{:echo, "hello"}] == impl.queue(1) 
    impl.crawl(1)
    Process.sleep(300)
  end

end
