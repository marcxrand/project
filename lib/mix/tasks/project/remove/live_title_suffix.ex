defmodule Mix.Tasks.Project.Remove.LiveTitleSuffix do
  use Igniter.Mix.Task

  alias Mix.Tasks.Project.Helpers

  @impl Igniter.Mix.Task
  def igniter(igniter) do
    app_web = Helpers.app_web_module(igniter) |> Macro.underscore()
    path = "lib/#{app_web}/components/layouts/root.html.heex"

    Igniter.update_file(igniter, path, fn source ->
      source
      |> Rewrite.Source.get(:content)
      |> String.replace(
        ~r/<\.live_title([^>]*) suffix="[^"]*"([^>]*)>\s*(\{[^}]+\})\s*<\/\.live_title>/s,
        "<.live_title\\1\\2>\\3</.live_title>"
      )
      |> then(&Rewrite.Source.update(source, :content, &1))
    end)
  end
end
