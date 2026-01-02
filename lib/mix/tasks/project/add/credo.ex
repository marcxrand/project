defmodule Mix.Tasks.Project.Add.Credo do
  use Igniter.Mix.Task

  @impl Igniter.Mix.Task
  def igniter(igniter) do
    {package, version} = Igniter.Project.Deps.determine_dep_type_and_version!("credo")

    igniter
    |> Igniter.Project.Deps.add_dep({package, version, only: [:dev, :test], runtime: false})
    |> Igniter.add_notice("Run `mix credo` to analyze your code")
  end
end
