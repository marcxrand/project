defmodule Mix.Tasks.Project.Gen.GigalixirLibcluster do
  @shortdoc "Generates Gigalixir Libcluster configuration"
  @moduledoc "Generates Gigalixir Libcluster configuration."
  use Igniter.Mix.Task

  @impl Igniter.Mix.Task
  def igniter(igniter) do
    igniter
    |> edit_config_prod
  end

  defp edit_config_prod(igniter) do
    opts =
      {:code,
       quote(
         do: [
           gigalixir: [
             strategy: Cluster.Strategy.Kubernetes,
             config: [
               kubernetes_selector: System.get_env("LIBCLUSTER_KUBERNETES_SELECTOR"),
               kubernetes_node_basename: System.get_env("LIBCLUSTER_KUBERNETES_NODE_BASENAME")
             ]
           ]
         ]
       )}

    Igniter.Project.Config.configure(igniter, "prod.exs", :libcluster, [:topologies], opts)
  end
end
