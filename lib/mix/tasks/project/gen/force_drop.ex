defmodule Mix.Tasks.Project.Gen.ForceDrop do
  @shortdoc "Updates ecto.drop alias to use --force-drop"
  @moduledoc "Updates the `ecto.drop` alias in `mix.exs` to use `--force-drop`."
  use Igniter.Mix.Task

  @impl Igniter.Mix.Task
  def igniter(igniter) do
    Igniter.update_file(igniter, "mix.exs", fn source ->
      content = Rewrite.Source.get(source, :content)

      updated =
        String.replace(content, "\"ecto.drop\"", "\"ecto.drop --force-drop\"")

      Rewrite.Source.update(source, :content, updated)
    end)
  end
end
