defmodule Mix.Tasks.Project.Add.MixTestWatch do
  use Igniter.Mix.Task

  @impl Igniter.Mix.Task
  def igniter(igniter) do
    {package, version} = Igniter.Project.Deps.determine_dep_type_and_version!("mix_test_watch")

    igniter
    |> Igniter.Project.Deps.add_dep({package, version, only: [:dev, :test], runtime: false})
    |> Igniter.add_notice("Run `mix test.watch` to run tests on file changes")
  end
end
