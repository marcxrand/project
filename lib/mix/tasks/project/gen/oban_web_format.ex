defmodule Mix.Tasks.Project.Gen.ObanWebFormat do
  @shortdoc "Formats the Oban Web dashboard route"
  @moduledoc "Formats the Oban Web dashboard route in the router."
  use Igniter.Mix.Task

  @impl Igniter.Mix.Task
  def igniter(igniter) do
    {igniter, router} = Igniter.Libs.Phoenix.select_router(igniter)
    router_path = Igniter.Project.Module.proper_location(igniter, router)

    if Igniter.exists?(igniter, router_path) do
      Igniter.update_file(igniter, router_path, fn source ->
        content = Rewrite.Source.get(source, :content)

        updated =
          String.replace(content, ~r/oban_dashboard\("([^"]+)"\)/, "oban_dashboard \"\\1\"")

        Rewrite.Source.update(source, :content, updated)
      end)
    else
      igniter
    end
  end
end
