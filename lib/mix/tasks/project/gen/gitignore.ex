defmodule Mix.Tasks.Project.Gen.Gitignore do
  @shortdoc "Adds items to .gitignore"
  @moduledoc "Adds items to `.gitignore`."
  use Igniter.Mix.Task

  alias Mix.Tasks.Project.Helpers

  @impl Igniter.Mix.Task
  def igniter(igniter) do
    Helpers.update_file_content(igniter, ".gitignore", fn content ->
      String.trim_trailing(content) <> "\n\n# Ignore macOS system files\n.DS_Store\n"
    end)
  end
end
