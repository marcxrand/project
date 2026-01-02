defmodule Mix.Tasks.Project.Remove do
  @shortdoc "Run a Project removal task by name"

  @moduledoc """
  Runs a specific Project removal task from the remove folder.

  ## Usage

      mix project.remove <task_names>

  ## Examples

      mix project.remove daisyui
      mix project.remove daisyui,topbar

  This will run `Mix.Tasks.Project.Remove.DaisyUI`, etc.

  ## Available tasks

  Run `mix project.remove --list` to see all available tasks.
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
      example: "mix project.remove bun",
      positional: [{:task_name, optional: true}]
    }
  end

  alias Mix.Tasks.Project.Helpers

  @impl Igniter.Mix.Task
  def igniter(igniter) do
    case igniter.args.positional[:task_name] do
      nil ->
        Mix.shell().error("Usage: mix project.remove <task_name>\n")
        Mix.shell().info("Run `mix project.remove --list` to see available tasks.\n")
        igniter

      task_names ->
        Helpers.run_tasks(igniter, __MODULE__, task_names)
    end
  end

  defp list_tasks do
    __MODULE__
    |> Helpers.available_task_names()
    |> Helpers.print_available_tasks("remove")
  end
end
