defmodule Mix.Tasks.Project.Gen.RepoConfig do
  @shortdoc "Generates repository configuration"
  @moduledoc "Generates repository configuration."
  use Igniter.Mix.Task

  alias Mix.Tasks.Project.Helpers

  @impl Igniter.Mix.Task
  def igniter(igniter) do
    app_name = Igniter.Project.Application.app_name(igniter)
    repo = Helpers.repo(igniter)

    igniter
    |> Igniter.Project.Config.configure("config.exs", app_name, [:generators],
      timestamp_type: :utc_datetime_usec,
      binary_id: true
    )
    |> Igniter.Project.Config.configure("config.exs", app_name, [repo],
      migration_timestamps: [type: :utc_datetime_usec]
    )
  end
end
