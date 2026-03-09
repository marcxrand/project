defmodule Mix.Tasks.Project.Add.Credo do
  @shortdoc "Adds Credo for code analysis"
  @moduledoc "Adds `credo` for code analysis."
  use Igniter.Mix.Task

  alias Mix.Tasks.Project.Helpers

  @impl Igniter.Mix.Task
  def igniter(igniter) do
    {package, version} = Helpers.latest_hex_dep(:credo)

    Igniter.Project.Deps.add_dep(igniter, {package, version, only: [:dev, :test], runtime: false})
  end
end
