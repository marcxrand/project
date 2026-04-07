defmodule Mix.Tasks.Project.Add.Oban do
  @shortdoc "Adds Oban for background jobs"
  @moduledoc "Adds `oban` for background job processing."
  use Igniter.Mix.Task

  alias Mix.Tasks.Project.Helpers

  @impl Igniter.Mix.Task
  def igniter(igniter) do
    igniter
    |> add_dep()
    |> add_app_child()
    |> add_app_logger()
    |> add_migration()
    |> edit_config()
    |> edit_config_test()
    |> edit_formatter()
  end

  defp add_dep(igniter) do
    {package, version} = Helpers.latest_hex_dep(:oban)
    Igniter.Project.Deps.add_dep(igniter, {package, version})
  end

  defp add_app_child(igniter) do
    app_name = Igniter.Project.Application.app_name(igniter)
    repo = Helpers.repo(igniter)
    child = {Oban, {:code, quote(do: Application.fetch_env!(unquote(app_name), Oban))}}

    Igniter.Project.Application.add_new_child(igniter, child, after: [repo])
  end

  defp add_app_logger(igniter) do
    app_module = Helpers.app_module(igniter)
    app_supervisor = Igniter.Project.Application.app_module(igniter)
    pattern = "opts = [strategy: :one_for_one, name: #{app_module}.Supervisor]"

    code = """
    Oban.Telemetry.attach_default_logger()
    """

    Igniter.Project.Module.find_and_update_module!(igniter, app_supervisor, fn zipper ->
      case Sourceror.Zipper.search_pattern(zipper, pattern) do
        nil -> Igniter.Code.Common.add_code(zipper, code, placement: :after)
        found -> {:ok, Igniter.Code.Common.add_code(found, code, placement: :before)}
      end
    end)
  end

  defp add_migration(igniter) do
    repo = Helpers.repo(igniter)

    migration_body = """
    def up do
      Oban.Migration.up(version: 12)
    end

    # We specify `version: 1` in `down`, ensuring that we'll roll all the way back down if
    # necessary, regardless of which version we've migrated `up` to.
    def down do
      Oban.Migration.down(version: 1)
    end
    """

    Mix.Tasks.Project.Helpers.gen_migration(igniter, repo, "add_oban", body: migration_body)
  end

  defp edit_config(igniter) do
    app_name = Igniter.Project.Application.app_name(igniter)
    repo = Helpers.repo(igniter)

    opts =
      {:code,
       quote(
         do: [
           engine: Oban.Engines.Basic,
           queues: [default: 10],
           repo: unquote(repo)
         ]
       )}

    Igniter.Project.Config.configure(igniter, "config.exs", app_name, [Oban], opts)
  end

  defp edit_config_test(igniter) do
    app_name = Igniter.Project.Application.app_name(igniter)

    Igniter.update_file(igniter, "config/test.exs", fn source ->
      content = Rewrite.Source.get(source, :content)

      if String.contains?(content, "Oban, testing:") do
        source
      else
        config_line =
          "\n# Prevent Oban from running jobs and plugins during test runs\nconfig :#{app_name}, Oban, testing: :manual\n"

        Rewrite.Source.update(source, :content, content <> config_line)
      end
    end)
  end

  defp edit_formatter(igniter) do
    Igniter.Project.Formatter.import_dep(igniter, :oban)
  end
end
