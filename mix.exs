defmodule Rpcsdk.MixProject do
  use Mix.Project

  @description"""
  This package contains the templates of dynamic multi GenServer (aka. RequestBroker) and
  similaly dynamic multi queue and its crawler which has configurerable schedule to dequeue
  handler. We can help to implement such as RPC messaging subsystem.
  """
  
  def project do
    [
      app: :rpcsdk,
      version: "0.4.1",
      elixir: "~> 1.14",
      description: @description,
      package: package(),
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def package do
    [
      maintainers: ["kjsd"],
      licenses: ["BSD-2-Clause license"],
      links: %{ "Github": "https://github.com/kjsd/rpcsdk" }
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ex_doc, ">= 0.0.0", only: :dev}
      # {:dep_from_hexpm, "~> 0.3.0"},
      # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"}
    ]
  end
end
