defmodule Mix.Tasks.Project.Add.ExSync do
  @shortdoc "Adds ExSync for auto-recompilation"
  @moduledoc "Adds `ex_sync` to reload modules on file changes."
  use Igniter.Mix.Task

  alias Mix.Tasks.Project.Helpers

  @impl Igniter.Mix.Task
  def igniter(igniter) do
    igniter
    |> add_dep()
    |> edit_config()
  end

  defp add_dep(igniter) do
    {package, version} = Helpers.latest_hex_dep(:exsync)
    Igniter.Project.Deps.add_dep(igniter, {package, version, only: :dev})
  end

  defp edit_config(igniter) do
    Igniter.Project.Config.configure(igniter, "dev.exs", :exsync, [:src_monitor], true)
  end
end
