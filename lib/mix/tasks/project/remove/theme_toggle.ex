defmodule Mix.Tasks.Project.Remove.ThemeToggle do
  use Igniter.Mix.Task

  alias Mix.Tasks.Project.Helpers

  @impl Igniter.Mix.Task
  def igniter(igniter) do
    app_web = Helpers.app_web_module(igniter) |> Macro.underscore()

    igniter
    |> remove_from_root_layout(app_web)
    |> remove_from_layouts_module(app_web)
  end

  defp remove_from_root_layout(igniter, app_web) do
    path = "lib/#{app_web}/components/layouts/root.html.heex"

    Igniter.update_file(igniter, path, fn source ->
      source
      |> Rewrite.Source.get(:content)
      |> remove_theme_scripts()
      |> then(&Rewrite.Source.update(source, :content, &1))
    end)
  end

  defp remove_from_layouts_module(igniter, app_web) do
    igniter
    |> remove_theme_toggle_function(app_web)
    |> remove_theme_toggle_usage(app_web)
  end

  defp remove_theme_scripts(content) do
    # Match script tags without crossing into other script tags, including surrounding whitespace
    regex = ~r/\n?\s*<script(?:\s[^>]*)?>(?:(?!<script)(?!<\/script>).)*theme(?:(?!<script)(?!<\/script>).)*<\/script>\s*/si

    content
    |> String.replace(regex, "\n")
    |> String.replace(~r/\n{3,}/, "\n\n")
  end

  defp remove_theme_toggle_usage(igniter, app_web) do
    path = "lib/#{app_web}/components/layouts.ex"

    Igniter.update_file(igniter, path, fn source ->
      content =
        source
        |> Rewrite.Source.get(:content)
        |> String.replace(~r/^.*<\.theme_toggle\s*\/>.*\n/m, "")

      Rewrite.Source.update(source, :content, content)
    end)
  end

  defp remove_theme_toggle_function(igniter, app_web) do
    path = "lib/#{app_web}/components/layouts.ex"

    Igniter.update_file(igniter, path, fn source ->
      content =
        source
        |> Rewrite.Source.get(:content)
        |> String.replace(
          ~r/\n\s*@doc\s+"""[^"]*theme[^"]*"""\s*\n\s*def theme_toggle\(assigns\) do\s*\n\s*~H"""[\s\S]*?"""\s*\n\s*end/i,
          ""
        )

      Rewrite.Source.update(source, :content, content)
    end)
  end
end
