defmodule Mix.Tasks.Project.Add.DotenvParser do
  @shortdoc "Adds DotenvParser for .env files"
  @moduledoc "Adds `dotenv_parser` to load environment variables from `.env` file."
  use Igniter.Mix.Task

  @impl Igniter.Mix.Task
  def igniter(igniter) do
    igniter
    |> add_dep()
    |> Igniter.create_new_file(".env", "VARIABLE=value")
    |> edit_runtime_exs()
    |> edit_gitignore()
  end

  defp add_dep(igniter) do
    {package, version} = Igniter.Project.Deps.determine_dep_type_and_version!("dotenv_parser")
    Igniter.Project.Deps.add_dep(igniter, {package, version})
  end

  defp edit_runtime_exs(igniter) do
    code = """
    if config_env() == :dev and File.exists?(".env") do
      DotenvParser.load_file(".env")
    end
    """

    Igniter.update_elixir_file(igniter, "config/runtime.exs", fn zipper ->
      case Sourceror.Zipper.search_pattern(zipper, "import Config") do
        nil -> Igniter.Code.Common.add_code(zipper, code, placement: :after)
        found -> {:ok, Igniter.Code.Common.add_code(found, code, placement: :after)}
      end
    end)
  end

  defp edit_gitignore(igniter) do
    Igniter.update_file(igniter, ".gitignore", fn source ->
      content = Rewrite.Source.get(source, :content)

      if String.contains?(content, ".env") do
        source
      else
        content = String.trim_trailing(content) <> "\n\n# Environment variables\n.env\n"
        Rewrite.Source.update(source, :content, content)
      end
    end)
  end
end
