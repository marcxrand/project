defmodule Mix.Tasks.Project.Add.ObanWeb do
  @shortdoc "Adds Oban Web UI"
  @moduledoc "Adds `oban_web` for monitoring background jobs."
  use Igniter.Mix.Task

  alias Mix.Tasks.Project.Helpers

  @impl Igniter.Mix.Task
  def igniter(igniter) do
    igniter
    |> add_dep()
    |> add_app_logger()
    |> edit_formatter()
    |> edit_router()
    |> Igniter.add_task("project.gen.oban_web_format")
  end

  defp add_dep(igniter) do
    {package, version} = Igniter.Project.Deps.determine_dep_type_and_version!("oban_web")
    Igniter.Project.Deps.add_dep(igniter, {package, version})
  end

  defp add_app_logger(igniter) do
    app_module = Helpers.app_module(igniter)
    app_supervisor = Igniter.Project.Application.app_module(igniter)
    pattern = "opts = [strategy: :one_for_one, name: #{app_module}.Supervisor]"

    code = """
    Oban.Web.Telemetry.attach_default_logger()
    """

    Igniter.Project.Module.find_and_update_module!(igniter, app_supervisor, fn zipper ->
      case Sourceror.Zipper.search_pattern(zipper, pattern) do
        nil -> Igniter.Code.Common.add_code(zipper, code, placement: :after)
        found -> {:ok, Igniter.Code.Common.add_code(found, code, placement: :before)}
      end
    end)
  end

  defp edit_formatter(igniter) do
    Igniter.Project.Formatter.import_dep(igniter, :oban_web)
  end

  defp edit_router(igniter) do
    {igniter, router} = Igniter.Libs.Phoenix.select_router(igniter)

    igniter
    |> add_router_import(router)
    |> Igniter.Libs.Phoenix.add_scope(
      "/admin",
      """
      pipe_through :browser

      oban_dashboard "/oban"
      """, router: router)
  end

  defp add_router_import(igniter, router) do
    code = "import Oban.Web.Router"

    Igniter.Project.Module.find_and_update_module!(igniter, router, fn zipper ->
      case Igniter.Libs.Phoenix.move_to_router_use(igniter, zipper) do
        {:ok, zipper} -> {:ok, Igniter.Code.Common.add_code(zipper, code)}
        :error -> Igniter.Code.Common.add_code(zipper, code, placement: :after)
      end
    end)
  end
end
