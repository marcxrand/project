defmodule Mix.Tasks.Project.Gen.HomePage do
  @shortdoc "Generates a minimal home page"
  @moduledoc "Generates a minimal home page."
  use Igniter.Mix.Task

  alias Mix.Tasks.Project.Helpers

  @impl Igniter.Mix.Task
  def igniter(igniter) do
    app_web = Helpers.app_web_module(igniter) |> Macro.underscore()
    path = "lib/#{app_web}/controllers/page_html/home.html.heex"

    content = """
    <Layouts.app flash={@flash}>
      <main class="flex justify-center">
        <div class="bg-gray-100 px-20 py-16">Home Page</div>
      </main>
    </Layouts.app>
    """

    Igniter.update_file(igniter, path, fn source ->
      Rewrite.Source.update(source, :content, content)
    end)
  end
end
