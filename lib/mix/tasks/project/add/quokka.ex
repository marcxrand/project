defmodule Mix.Tasks.Project.Add.Quokka do
  @shortdoc "Adds Quokka for database migrations"
  @moduledoc "Adds `quokka` for simple data administration."
  use Igniter.Mix.Task

  @impl Igniter.Mix.Task
  def igniter(igniter) do
    {package, version} = Igniter.Project.Deps.determine_dep_type_and_version!("quokka")

    igniter
    |> Igniter.Project.Deps.add_dep({package, version, only: [:dev, :test], runtime: false})
    |> Igniter.add_notice("Add `Quokka` to plugins in `.formatter.exs`")
  end
end
