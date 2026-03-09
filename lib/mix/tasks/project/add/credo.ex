defmodule Mix.Tasks.Project.Add.Credo do
  @shortdoc "Adds Credo for code analysis"
  @moduledoc "Adds `credo` for code analysis."
  use Igniter.Mix.Task

  @impl Igniter.Mix.Task
  def igniter(igniter) do
    {package, version} = Igniter.Project.Deps.determine_dep_type_and_version!("credo")

    Igniter.Project.Deps.add_dep(igniter, {package, version, only: [:dev, :test], runtime: false})
  end
end
