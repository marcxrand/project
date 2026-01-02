defmodule Mix.Tasks.Project.Add.ExSync do
  use Igniter.Mix.Task

  @impl Igniter.Mix.Task
  def igniter(igniter) do
    igniter
    |> add_dep()
    |> edit_config()
  end

  defp add_dep(igniter) do
    {package, version} = Igniter.Project.Deps.determine_dep_type_and_version!("exsync")
    Igniter.Project.Deps.add_dep(igniter, {package, version, only: :dev})
  end

  defp edit_config(igniter) do
    Igniter.Project.Config.configure(igniter, "dev.exs", :exsync, [:src_monitor], true)
  end
end
