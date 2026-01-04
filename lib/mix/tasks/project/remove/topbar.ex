defmodule Mix.Tasks.Project.Remove.Topbar do
  @shortdoc "Removes topbar progress indicator"
  @moduledoc "Removes the topbar progress indicator."
  use Igniter.Mix.Task

  @impl Igniter.Mix.Task
  def igniter(igniter) do
    igniter
    |> Igniter.rm("assets/vendor/topbar.js")
    |> edit_app_js()
    |> edit_package_json()
  end

  defp edit_app_js(igniter) do
    Igniter.update_file(igniter, "assets/js/app.js", fn source ->
      source
      |> Rewrite.Source.get(:content)
      |> String.split("\n")
      |> Enum.reject(&String.contains?(&1, ["topbar", "progress bar"]))
      |> Enum.join("\n")
      |> then(&Regex.replace(~r/\n{3,}/, &1, "\n\n"))
      |> then(&Rewrite.Source.update(source, :content, &1))
    end)
  end

  defp edit_package_json(igniter) do
    if Igniter.exists?(igniter, "package.json") do
      Igniter.update_file(igniter, "package.json", fn source ->
        source
        |> Rewrite.Source.get(:content)
        |> Jason.decode!()
        |> Map.delete("topbar")
        |> Jason.encode!(pretty: true)
        |> then(&Rewrite.Source.update(source, :content, &1))
      end)
    else
      igniter
    end
  end
end
