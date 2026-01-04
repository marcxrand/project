defmodule Mix.Tasks.Project.Setup do
  @moduledoc """
  Runs all Project tasks listed in tasks/0.

  ## Usage

      mix project.setup
      mix project.setup --oban-pro --gigalixir
  """

  use Igniter.Mix.Task

  @impl Igniter.Mix.Task
  def info(_argv, _composing_task) do
    schema = Enum.map(optional_tasks(), fn {flag, _module} -> {flag, :boolean} end)
    %Igniter.Mix.Task.Info{schema: schema}
  end

  # Composes all tasks in order. Each task's changes are accumulated into the igniter.
  @impl Igniter.Mix.Task
  def igniter(igniter) do
    opts = igniter.args.options

    tasks()
    |> expand_optional_tasks(opts)
    |> Enum.reduce(igniter, fn module, acc ->
      Igniter.compose_task(acc, module)
    end)
  end

  defp expand_optional_tasks(tasks, opts) do
    Enum.flat_map(tasks, fn
      {:optional, key} ->
        if opts[key] do
          optional_tasks()
          |> Keyword.get(key, [])
          |> List.wrap()
        else
          []
        end

      module ->
        [module]
    end)
  end

  # Optional tasks enabled via flags (e.g., --gigalixir, --oban-pro)
  # Values can be a single module or a list of modules.
  def optional_tasks do
    [
      ex_sync: Mix.Tasks.Project.Add.ExSync,
      gigalixir: [
        Mix.Tasks.Project.Gen.Gigalixir,
        Mix.Tasks.Project.Gen.GigalixirLibcluster
      ],
      graph_db: Mix.Tasks.Project.Gen.GraphDb,
      mix_test_watch: Mix.Tasks.Project.Add.MixTestWatch,
      oban_pro: Mix.Tasks.Project.Add.ObanPro
    ]
  end

  # Edit this list as needed. To customize a task, create a new module
  # (e.g., Mix.Tasks.MyApp.Add.Oban) and replace it in the list below.
  # Use {:optional, :flag_name} to insert optional tasks at specific positions.
  # These are only included when their flag is passed (e.g., --oban-pro).
  def tasks do
    [
      # Remove code
      Mix.Tasks.Project.Remove.AgentsMd,
      Mix.Tasks.Project.Remove.DaisyUI,
      Mix.Tasks.Project.Remove.LiveTitleSuffix,
      Mix.Tasks.Project.Remove.RepoCredentials,
      Mix.Tasks.Project.Remove.ThemeToggle,
      Mix.Tasks.Project.Remove.Topbar,

      # Generate code
      Mix.Tasks.Project.Gen.AppLayout,
      Mix.Tasks.Project.Gen.ClassFormatter,
      Mix.Tasks.Project.Gen.Gitignore,
      Mix.Tasks.Project.Gen.HomePage,
      Mix.Tasks.Project.Gen.PgExtensions,
      Mix.Tasks.Project.Gen.RepoConfig,
      Mix.Tasks.Project.Gen.Schema,

      # Add packages
      Mix.Tasks.Project.Add.Bun,
      Mix.Tasks.Project.Add.Credo,
      Mix.Tasks.Project.Add.DotenvParser,
      {:optional, :ex_sync},
      Mix.Tasks.Project.Add.Libcluster,
      Mix.Tasks.Project.Add.Oban,
      Mix.Tasks.Project.Add.ObanWeb,
      {:optional, :oban_pro},
      Mix.Tasks.Project.Add.Pgvector,
      Mix.Tasks.Project.Add.Quokka,
      Mix.Tasks.Project.Add.RemixIcons,
      Mix.Tasks.Project.Add.Tidewave,
      Mix.Tasks.Project.Add.Uuidv7,

      # Other optional
      {:optional, :gigalixir},
      {:optional, :graph_db},
      {:optional, :mix_test_watch},

      # Sort dependencies
      Mix.Tasks.Project.Gen.SortDeps
    ]
  end
end
