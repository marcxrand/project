defmodule Mix.Tasks.Project do
  @shortdoc "List all Project tasks"

  @moduledoc """
  Lists all available Project tasks.

  ## Usage

      mix project --list

  ## Available Commands

  - `mix project.add <task>` - Add a package to your project
  - `mix project.remove <task>` - Remove a package from your project
  - `mix project.start` - Run all Project generators
  """

  use Mix.Task

  alias Mix.Tasks.Project.Helpers

  @impl Mix.Task
  def run(argv) do
    if "--list" in argv or "-l" in argv or argv == [] do
      list_tasks()
    else
      Mix.shell().error("Unknown arguments: #{Enum.join(argv, " ")}\n")
      Mix.shell().info("Run `mix project --list` to see available tasks.")
    end
  end

  defp list_tasks do
    Mix.shell().info("Available Project commands:\n")

    Mix.shell().info("  mix project.add <task>     - Add a package")
    Mix.shell().info("  mix project.remove <task>  - Remove a package")
    Mix.shell().info("  mix project.start          - Run all generators\n")

    add_tasks = Helpers.available_task_names(Mix.Tasks.Project.Add)
    remove_tasks = Helpers.available_task_names(Mix.Tasks.Project.Remove)

    if add_tasks != [] do
      Mix.shell().info("Add tasks:")

      Enum.each(add_tasks, fn name ->
        Mix.shell().info("  - #{name}")
      end)

      Mix.shell().info("")
    end

    if remove_tasks != [] do
      Mix.shell().info("Remove tasks:")

      Enum.each(remove_tasks, fn name ->
        Mix.shell().info("  - #{name}")
      end)
    end
  end
end
