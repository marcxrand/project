defmodule Mix.Tasks.Project.Add.Tidewave do
  use Igniter.Mix.Task

  @impl Igniter.Mix.Task
  def igniter(igniter) do
    igniter
    |> add_dep()
    |> update_endpoint()
  end

  defp add_dep(igniter) do
    {package, version} = Igniter.Project.Deps.determine_dep_type_and_version!("tidewave")
    Igniter.Project.Deps.add_dep(igniter, {package, version, only: :dev})
  end

  defp update_endpoint(igniter) do
    {_, endpoint} = Igniter.Libs.Phoenix.select_endpoint(igniter)

    if endpoint do
      code = """
      # Tidewave
      if Code.ensure_loaded?(Tidewave) do
        plug Tidewave
      end
      """

      Igniter.Project.Module.find_and_update_module!(igniter, endpoint, fn zipper ->
        case Sourceror.Zipper.search_pattern(zipper, "if code_reloading? do end") do
          nil -> Igniter.Code.Common.add_code(zipper, code, placement: :after)
          found -> {:ok, Igniter.Code.Common.add_code(found, code, placement: :before)}
        end
      end)
    else
      Igniter.add_warning(igniter, "No Phoenix endpoint found!")
    end
  end
end
