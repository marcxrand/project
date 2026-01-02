defmodule Mix.Tasks.Project.Add.Pgvector do
  use Igniter.Mix.Task

  alias Mix.Tasks.Project.Helpers

  @impl Igniter.Mix.Task
  def igniter(igniter) do
    igniter
    |> add_dep()
    |> add_postgrex_types()
    |> edit_config()
  end

  defp add_dep(igniter) do
    {package, version} = Igniter.Project.Deps.determine_dep_type_and_version!("pgvector")
    Igniter.Project.Deps.add_dep(igniter, {package, version})
  end

  defp add_postgrex_types(igniter) do
    app_name = Igniter.Project.Application.app_name(igniter)
    app_module = Helpers.app_module(igniter)
    types_module = Module.concat([app_module, "PostgrexTypes"])

    content = """
    Postgrex.Types.define(
      #{inspect(types_module)},
      Pgvector.extensions() ++ Ecto.Adapters.Postgres.extensions(),
      []
    )
    """

    Igniter.create_new_file(igniter, "lib/#{app_name}/postgrex_types.ex", content)
  end

  defp edit_config(igniter) do
    app_name = Igniter.Project.Application.app_name(igniter)
    app_module = Helpers.app_module(igniter)
    repo = Helpers.repo(igniter)
    types_module = Module.concat([app_module, "PostgrexTypes"])

    Igniter.Project.Config.configure(igniter, "config.exs", app_name, [repo, :types], types_module)
  end
end
