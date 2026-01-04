defmodule Mix.Tasks.Project.Add.ObanPro do
  @shortdoc "Adds Oban Pro extensions"
  @moduledoc "Adds `oban_pro` for advanced background job processing features."
  use Igniter.Mix.Task

  alias Mix.Tasks.Project.Helpers

  @impl Igniter.Mix.Task
  def igniter(igniter) do
    igniter
    |> ensure_oban()
    |> add_dep()
    |> add_migration()
    |> edit_config()
    |> edit_oban_migration()
    |> Igniter.add_task("ecto.reset")
  end

  defp ensure_oban(igniter) do
    case Igniter.Project.Deps.get_dep(igniter, :oban) do
      {:ok, _} -> igniter
      :error -> Igniter.compose_task(igniter, Mix.Tasks.Project.Add.Oban)
    end
  end

  defp add_dep(igniter) do
    Igniter.Project.Deps.add_dep(igniter, {:oban_pro, "~> 1.6", repo: "oban"})
  end

  defp add_migration(igniter) do
    repo = Helpers.repo(igniter)

    migration_body = """
    def up, do: Oban.Pro.Migration.up()
    def down, do: Oban.Pro.Migration.down()
    """

    Mix.Tasks.Project.Helpers.gen_migration(igniter, repo, "add_oban_pro", body: migration_body)
  end

  defp edit_config(igniter) do
    app_name = Igniter.Project.Application.app_name(igniter)
    repo = Helpers.repo(igniter)

    opts =
      {:code,
       quote(
         do: [
           engine: Oban.Pro.Engines.Smart,
           notifier: Oban.Notifiers.PG,
           plugins: [
             {Oban.Pro.Plugins.DynamicCron, crontab: []},
             Oban.Pro.Plugins.DynamicLifeline,
             Oban.Pro.Plugins.DynamicPartitioner,
             Oban.Pro.Plugins.DynamicPrioritizer,
             {Oban.Pro.Plugins.DynamicQueues, queues: [default: 10], sync_mode: :automatic}
           ],
           repo: unquote(repo)
         ]
       )}

    Igniter.Project.Config.configure(igniter, "config.exs", app_name, [Oban], opts)
  end

  defp edit_oban_migration(igniter) do
    app_module = Helpers.app_module(igniter)
    repo_name = Helpers.repo(igniter) |> Module.split() |> List.last() |> Macro.underscore()
    migrations_path = "priv/#{repo_name}/migrations"

    igniter
    |> Igniter.include_glob(Path.join(migrations_path, "*_add_oban.exs"))
    |> then(fn igniter ->
      igniter.rewrite
      |> Rewrite.sources()
      |> Enum.find(fn source -> String.ends_with?(source.path, "_add_oban.exs") end)
      |> case do
        nil ->
          igniter

        source ->
          module_name = oban_migration_module_name(app_module, source.path)

          new_content = """
          defmodule #{module_name} do
            use Ecto.Migration

            defdelegate up, to: Oban.Pro.Migrations.DynamicPartitioner
            defdelegate down, to: Oban.Pro.Migrations.DynamicPartitioner
          end
          """

          Igniter.update_file(igniter, source.path, fn source ->
            Rewrite.Source.update(source, :content, new_content)
          end)
      end
    end)
  end

  defp oban_migration_module_name(app_module, path) do
    migration_name =
      path
      |> Path.basename(".exs")
      |> String.replace(~r/^\d+_/, "")
      |> Macro.camelize()

    "#{app_module}.Repo.Migrations.#{migration_name}"
  end
end
