defmodule Mix.Tasks.Project.Add.Libcluster do
  @shortdoc "Adds libcluster for node clustering"
  @moduledoc "Adds `libcluster` for clustering elixir nodes."
  use Igniter.Mix.Task

  alias Mix.Tasks.Project.Helpers

  @impl Igniter.Mix.Task
  def igniter(igniter) do
    igniter
    |> add_dep()
    |> add_app_child()
    |> edit_config_dev()
  end

  defp add_dep(igniter) do
    {package, version} = Igniter.Project.Deps.determine_dep_type_and_version!("libcluster")
    Igniter.Project.Deps.add_dep(igniter, {package, version})
  end

  defp add_app_child(igniter) do
    app_module = Helpers.app_module(igniter)
    supervisor = Module.concat([app_module, "ClusterSupervisor"])
    repo = Helpers.repo(igniter)

    child =
      {Cluster.Supervisor,
       {:code,
        quote(
          do: [Application.get_env(:libcluster, :topologies) || [], [name: unquote(supervisor)]]
        )}}

    Igniter.Project.Application.add_new_child(igniter, child, after: [repo])
  end

  defp edit_config_dev(igniter) do
    opts = {:code, quote(do: [gossip: [strategy: Cluster.Strategy.Gossip]])}

    Igniter.Project.Config.configure(igniter, "dev.exs", :libcluster, [:topologies], opts)
  end
end
