defmodule Mix.Tasks.Project.Remove.DaisyUI do
  @shortdoc "Removes DaisyUI components"
  @moduledoc "Removes DaisyUI components and configuration."
  use Igniter.Mix.Task

  @impl Igniter.Mix.Task
  def igniter(igniter) do
    igniter
    |> remove_vendor_files()
    |> edit_app_css()
  end

  defp remove_vendor_files(igniter) do
    igniter
    |> Igniter.rm("assets/vendor/daisyui.js")
    |> Igniter.rm("assets/vendor/daisyui-theme.js")
  end

  defp edit_app_css(igniter) do
    Igniter.update_file(igniter, "assets/css/app.css", fn source ->
      source
      |> Rewrite.Source.get(:content)
      |> remove_daisyui_plugin()
      |> remove_daisyui_theme_plugins()
      |> then(&Rewrite.Source.update(source, :content, &1))
    end)
  end

  defp remove_daisyui_plugin(content) do
    # Remove the daisyui plugin block (multiline comment + @plugin block)
    Regex.replace(
      ~r|/\* daisyUI Tailwind Plugin.*?\*/\n@plugin "\.\./vendor/daisyui" \{[^}]*\}\n+|s,
      content,
      ""
    )
  end

  defp remove_daisyui_theme_plugins(content) do
    content
    # Remove daisyui-theme block with comment
    |> then(fn c ->
      Regex.replace(
        ~r|/\* daisyUI theme plugin.*?\*/\n@plugin "\.\./vendor/daisyui-theme" \{[^}]*\}\n+|s,
        c,
        ""
      )
    end)
    # Remove any remaining daisyui-theme blocks without comments
    |> then(fn c ->
      Regex.replace(
        ~r|@plugin "\.\./vendor/daisyui-theme" \{[^}]*\}\n+|s,
        c,
        "",
        global: true
      )
    end)
  end
end
