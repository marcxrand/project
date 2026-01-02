defmodule Mix.Tasks.Project.Helpers do
  @moduledoc false

  def available_task_modules(parent_module) do
    {:ok, modules} = :application.get_key(:project, :modules)
    parent_parts = Module.split(parent_module)

    modules
    |> Enum.filter(fn module ->
      parts = Module.split(module)
      List.starts_with?(parts, parent_parts) and length(parts) == length(parent_parts) + 1
    end)
    |> Enum.sort()
  end

  def available_task_names(parent_module) do
    parent_module
    |> available_task_modules()
    |> Enum.map(&module_to_task_name/1)
  end

  def find_task_module(parent_module, task_name) do
    normalized = task_name |> to_string() |> String.downcase() |> String.replace("_", "")

    parent_module
    |> available_task_modules()
    |> Enum.find(fn module ->
      module_to_task_name(module) |> String.replace("_", "") == normalized
    end)
    |> case do
      nil -> :error
      module -> {:ok, module}
    end
  end

  def module_to_task_name(module) do
    module
    |> Module.split()
    |> List.last()
    |> Macro.underscore()
  end

  @doc "Returns the camelized app module name (e.g., 'MyApp')"
  def app_module(igniter) do
    Igniter.Project.Application.app_name(igniter) |> to_string() |> Macro.camelize()
  end

  @doc "Returns the app's Repo module (e.g., MyApp.Repo)"
  def repo(igniter) do
    Module.concat([app_module(igniter), "Repo"])
  end

  @doc "Returns the app's web module name (e.g., 'MyAppWeb')"
  def app_web_module(igniter) do
    app_module(igniter) <> "Web"
  end

  @doc "Updates file content with a transformation function"
  def update_file_content(igniter, path, transform_fn) do
    Igniter.update_file(igniter, path, fn source ->
      source
      |> Rewrite.Source.get(:content)
      |> transform_fn.()
      |> then(&Rewrite.Source.update(source, :content, &1))
    end)
  end

  @doc "Prints a list of available tasks"
  def print_available_tasks(tasks, task_type) do
    if tasks == [] do
      Mix.shell().info("No tasks available.")
    else
      Mix.shell().info("Available tasks:\n")
      Enum.each(tasks, &Mix.shell().info("  mix project.#{task_type} #{&1}"))
    end
  end

  @doc "Prints error message with available tasks"
  def print_unknown_task(task_name, available) do
    Mix.shell().error("Unknown task: #{task_name}\n")

    if available != [] do
      Mix.shell().info("Available tasks:")
      Enum.each(available, &Mix.shell().info("  - #{&1}"))
    end
  end

  @doc "Runs one or more comma-separated tasks"
  def run_tasks(igniter, parent_module, task_names) do
    task_names
    |> to_string()
    |> String.split(",", trim: true)
    |> Enum.map(&String.trim/1)
    |> Enum.reduce(igniter, fn task_name, acc ->
      case find_task_module(parent_module, task_name) do
        {:ok, module} ->
          Igniter.compose_task(acc, module)

        :error ->
          print_unknown_task(task_name, available_task_names(parent_module))
          acc
      end
    end)
  end

  def remove_config_key(igniter, file, app, module, key) do
    Igniter.update_elixir_file(igniter, "config/#{file}", fn zipper ->
      zipper
      |> Sourceror.Zipper.topmost()
      |> Igniter.Code.Common.move_to(fn z ->
        Igniter.Code.Function.function_call?(z, :config, 3) and
          Igniter.Code.Function.argument_equals?(z, 0, app) and
          Igniter.Code.Function.argument_equals?(z, 1, module)
      end)
      |> case do
        {:ok, zipper} ->
          Igniter.Code.Function.update_nth_argument(zipper, 2, fn opts_zipper ->
            Igniter.Code.Keyword.remove_keyword_key(opts_zipper, key)
          end)

        :error ->
          {:ok, zipper}
      end
    end)
  end

  @doc """
  Generates a migration with a unique timestamp.

  Tracks timestamps in igniter assigns to avoid duplicates when multiple
  migrations are created within the same second.
  """
  def gen_migration(igniter, repo, name, opts \\ []) do
    {igniter, timestamp} = next_migration_timestamp(igniter)
    Igniter.Libs.Ecto.gen_migration(igniter, repo, name, Keyword.put(opts, :timestamp, timestamp))
  end

  defp next_migration_timestamp(igniter) do
    current = migration_timestamp()
    last_used = igniter.assigns[:last_migration_timestamp] || 0

    timestamp = max(current, last_used + 1)
    igniter = Igniter.assign(igniter, :last_migration_timestamp, timestamp)

    {igniter, timestamp}
  end

  defp migration_timestamp do
    {{y, m, d}, {hh, mm, ss}} = :calendar.universal_time()
    String.to_integer("#{y}#{pad(m)}#{pad(d)}#{pad(hh)}#{pad(mm)}#{pad(ss)}")
  end

  defp pad(i) when i < 10, do: "0#{i}"
  defp pad(i), do: "#{i}"
end
