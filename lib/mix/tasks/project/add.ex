defmodule Mix.Tasks.Project.Add do
  @shortdoc "Run a Project task by name"

  @moduledoc """
  Adds one or more packages to your project.

  ## Usage

      mix project.add <task_names>

  ## Examples

      mix project.add bun
      mix project.add bun,oban,tidewave

  This will run `Mix.Tasks.Project.Add.Bun`, etc.

  ## Available flags

  Run `mix project.add --list` to see all available tasks.
  """

  use Igniter.Mix.Task

  @impl Mix.Task
  def run(argv) do
    if "--list" in argv or "-l" in argv do
      list_tasks()
    else
      super(argv)
    end
  end

  @impl Igniter.Mix.Task
  def info(_argv, _composing_task) do
    %Igniter.Mix.Task.Info{
      group: :project,
      example: "mix project.add bun",
      positional: [{:task_name, optional: true}]
    }
  end

  alias Mix.Tasks.Project.Helpers

  @impl Igniter.Mix.Task
  def igniter(igniter) do
    case igniter.args.positional[:task_name] do
      nil ->
        Mix.shell().error("Usage: mix project.add <task_name>\n")
        Mix.shell().info("Run `mix project.add --list` to see available tasks.\n")
        igniter

      task_names ->
        Helpers.run_tasks(igniter, __MODULE__, task_names)
    end
  end

  defp list_tasks do
    __MODULE__
    |> Helpers.available_task_names()
    |> Helpers.print_available_tasks("add")
  end
end
