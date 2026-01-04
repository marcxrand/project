defmodule Mix.Tasks.Project.Gen.Setup do
  @shortdoc "Generates a custom setup task"
  @moduledoc "Generates a custom setup task for the project."
  use Igniter.Mix.Task

  @source_path Path.join(__DIR__, "../setup.ex")

  @impl Igniter.Mix.Task
  def igniter(igniter) do
    app_name = Igniter.Project.Application.app_name(igniter)
    app_module = app_name |> to_string() |> Macro.camelize()

    content =
      @source_path
      |> File.read!()
      |> String.replace("Mix.Tasks.Project.Setup", "Mix.Tasks.#{app_module}.Setup")
      |> String.replace("project", to_string(app_name))

    Igniter.create_new_file(igniter, "lib/mix/tasks/#{app_name}.setup.ex", content)
  end
end
