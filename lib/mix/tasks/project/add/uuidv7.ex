defmodule Mix.Tasks.Project.Add.UUIDv7 do
  use Igniter.Mix.Task

  @impl Igniter.Mix.Task
  def igniter(igniter) do
    igniter
    |> add_dep()
    |> update_schema()
  end

  defp add_dep(igniter) do
    {package, version} = Igniter.Project.Deps.determine_dep_type_and_version!("uuidv7")
    Igniter.Project.Deps.add_dep(igniter, {package, version})
  end

  defp update_schema(igniter) do
    app_name = Igniter.Project.Application.app_name(igniter)
    schema_path = "lib/#{app_name}/schema.ex"

    if Igniter.exists?(igniter, schema_path) do
      Igniter.update_file(igniter, schema_path, fn source ->
        content = Rewrite.Source.get(source, :content)
        updated = String.replace(content, ":binary_id", "UUIDv7")
        Rewrite.Source.update(source, :content, updated)
      end)
    else
      igniter
    end
  end
end
