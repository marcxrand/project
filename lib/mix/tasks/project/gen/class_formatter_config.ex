defmodule Mix.Tasks.Project.Gen.ClassFormatterConfig do
  use Igniter.Mix.Task

  alias Mix.Tasks.Project.Helpers

  @impl Igniter.Mix.Task
  def igniter(igniter) do
    app_web_name = Helpers.app_web_module(igniter)
    formatter_module = Module.concat([app_web_name, "Formatters", "ClassFormatter"])

    value = {:%{}, [], [class: formatter_module]}

    Igniter.update_elixir_file(igniter, ".formatter.exs", fn zipper ->
      Igniter.Code.Keyword.set_keyword_key(zipper, :attribute_formatters, value, fn _ ->
        {:ok, value}
      end)
    end)
  end
end
