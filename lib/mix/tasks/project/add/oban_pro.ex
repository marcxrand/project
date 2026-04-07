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
    |> Igniter.Project.Formatter.import_dep(:oban_pro)
  end

  defp ensure_oban(igniter) do
    if Igniter.Project.Deps.has_dep?(igniter, :oban) do
      igniter
    else
      Igniter.compose_task(igniter, Mix.Tasks.Project.Add.Oban)
    end
  end

  defp add_dep(igniter) do
    Igniter.Project.Deps.add_dep(igniter, {:oban_pro, "~> 1.7.0-rc", repo: "oban"})
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
             {Oban.Pro.Plugins.DynamicCron, [crontab: []]},
             Oban.Pro.Plugins.DynamicLifeline,
             Oban.Pro.Plugins.DynamicPrioritizer,
             Oban.Pro.Plugins.DynamicPruner,
             {Oban.Pro.Plugins.DynamicQueues,
              [queues: [default: 10, webhooks: 20], sync_mode: :automatic]}
           ],
           repo: unquote(repo)
         ]
       )}

    Igniter.Project.Config.configure(igniter, "config.exs", app_name, [Oban], opts)
  end

end
