defmodule Mix.Tasks.Project.Remove.RepoCredentials do
  @shortdoc "Removes repo credentials from config"
  @moduledoc "Removes repository credentials from configuration."
  use Igniter.Mix.Task

  alias Mix.Tasks.Project.Helpers

  @impl Igniter.Mix.Task
  def igniter(igniter) do
    app_name = Igniter.Project.Application.app_name(igniter)
    repo = Helpers.repo(igniter)

    igniter
    |> Helpers.remove_config_key("dev.exs", app_name, repo, :username)
    |> Helpers.remove_config_key("dev.exs", app_name, repo, :password)
    |> Helpers.remove_config_key("test.exs", app_name, repo, :username)
    |> Helpers.remove_config_key("test.exs", app_name, repo, :password)
  end
end
