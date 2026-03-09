defmodule Mix.Tasks.Project.Add.Quokka do
  @shortdoc "Adds Quokka for database migrations"
  @moduledoc "Adds `quokka` for simple data administration."
  use Igniter.Mix.Task

  alias Mix.Tasks.Project.Helpers

  @impl Igniter.Mix.Task
  def igniter(igniter) do
    {package, version} = Helpers.latest_hex_dep(:quokka)

    igniter
    |> Igniter.Project.Deps.add_dep({package, version, only: [:dev, :test], runtime: false})
    |> Igniter.add_notice("Add `Quokka` to the `plugins` list in `.formatter.exs`")
  end
end
