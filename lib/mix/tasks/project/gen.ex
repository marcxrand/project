defmodule Mix.Tasks.Project.Gen do
  @shortdoc "Run a Project generator by name"

  @moduledoc """
  Runs a specific Project generator from the gen folder.

  ## Usage

      mix project.gen <task_names>

  ## Examples

      mix project.gen setup
      mix project.gen gitignore,schema

  This will run `Mix.Tasks.Project.Gen.Setup`, etc.

  ## Available tasks

  Run `mix project.gen --list` to see all available tasks.
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
      example: "mix project.gen setup",
      positional: [{:task_name, optional: true}]
    }
  end

  alias Mix.Tasks.Project.Helpers

  @impl Igniter.Mix.Task
  def igniter(igniter) do
    case igniter.args.positional[:task_name] do
      nil ->
        Mix.shell().error("Usage: mix project.gen <task_name>\n")
        Mix.shell().info("Run `mix project.gen --list` to see available tasks.\n")
        igniter

      task_names ->
        Helpers.run_tasks(igniter, __MODULE__, task_names)
    end
  end

  defp list_tasks do
    __MODULE__
    |> Helpers.available_task_names()
    |> Helpers.print_available_tasks("gen")
  end
end
