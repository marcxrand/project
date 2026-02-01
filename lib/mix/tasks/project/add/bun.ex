defmodule Mix.Tasks.Project.Add.Bun do
  @shortdoc "Replaces esbuild and tailwind with Bun"
  @moduledoc "Replaces `esbuild` and `tailwind` with `Bun`."
  use Igniter.Mix.Task

  alias Mix.Tasks.Project.Helpers

  @impl Igniter.Mix.Task
  def igniter(igniter) do
    igniter
    |> remove_esbuild()
    |> remove_tailwind()
    |> add_dep()
    |> add_package_json()
    |> clean_deploy_script()
    |> edit_config()
    |> edit_config_dev()
    |> edit_mix_aliases()
    |> Igniter.add_task("assets.setup")
  end

  defp add_dep(igniter) do
    {package, version} = Igniter.Project.Deps.determine_dep_type_and_version!("bun")
    opts = quote(do: [runtime: Mix.env() == :dev])

    Igniter.Project.Deps.add_dep(igniter, {package, version, opts})
  end

  defp add_package_json(igniter) do
    has_topbar? = Igniter.exists?(igniter, "assets/vendor/topbar.js")

    # Fetch all npm versions in parallel (including "bun" for edit_config later)
    packages =
      if has_topbar?,
        do: ["tailwindcss", "@tailwindcss/cli", "topbar", "bun"],
        else: ["tailwindcss", "@tailwindcss/cli", "bun"]

    versions = Helpers.fetch_npm_versions_parallel(packages)

    dependencies = %{
      "phoenix" => "workspace:*",
      "phoenix_html" => "workspace:*",
      "phoenix_live_view" => "workspace:*",
      "tailwindcss" => versions["tailwindcss"] || "^4.1.18",
      "@tailwindcss/cli" => versions["@tailwindcss/cli"] || "^4.1.18"
    }

    dependencies =
      if has_topbar? do
        Map.put(dependencies, "topbar", versions["topbar"] || "^3.0.0")
      else
        dependencies
      end

    new_data = %{"workspaces" => ["../deps/*"], "dependencies" => dependencies}

    if Igniter.exists?(igniter, "assets/package.json") do
      Igniter.update_file(igniter, "assets/package.json", fn source ->
        content = Rewrite.Source.get(source, :content)

        updated =
          content
          |> Jason.decode!()
          |> Map.merge(new_data)
          |> Jason.encode!(pretty: true)

        Rewrite.Source.update(source, :content, updated <> "\n")
      end)
    else
      contents = Jason.encode!(new_data, pretty: true)
      Igniter.create_new_file(igniter, "assets/package.json", contents <> "\n")
    end
  end

  defp clean_deploy_script(igniter) do
    if Igniter.exists?(igniter, "assets/package.json") do
      Igniter.update_file(igniter, "assets/package.json", fn source ->
        content = Rewrite.Source.get(source, :content)
        json = Jason.decode!(content)

        case get_in(json, ["scripts", "deploy"]) do
          nil ->
            source

          deploy_script ->
            cleaned = String.replace(deploy_script, ~r/ && rm -f _build\/esbuild\*?/, "")
            updated = put_in(json, ["scripts", "deploy"], cleaned)
            Rewrite.Source.update(source, :content, Jason.encode!(updated, pretty: true) <> "\n")
        end
      end)
    else
      igniter
    end
  end

  defp remove_esbuild(igniter) do
    igniter
    |> Igniter.Project.Config.remove_application_configuration("config.exs", :esbuild)
    |> Igniter.Project.Deps.remove_dep(:esbuild)
  end

  defp remove_tailwind(igniter) do
    igniter
    |> Igniter.Project.Config.remove_application_configuration("config.exs", :tailwind)
    |> Igniter.Project.Deps.remove_dep(:tailwind)
  end

  defp edit_config(igniter) do
    version = Helpers.fetch_npm_version("bun") || "1.3.5"

    igniter
    |> Igniter.Project.Config.configure("config.exs", :bun, [:version], version)
    |> Igniter.Project.Config.configure(
      "config.exs",
      :bun,
      [:assets],
      {:code, quote(do: [args: [], cd: Path.expand("../assets", __DIR__)])}
    )
    |> Igniter.Project.Config.configure(
      "config.exs",
      :bun,
      [:css],
      {:code,
       quote(
         do: [
           args:
             ~w(run tailwindcss --input=css/app.css --output=../priv/static/assets/css/app.css),
           cd: Path.expand("../assets", __DIR__)
         ]
       )}
    )
    |> Igniter.Project.Config.configure(
      "config.exs",
      :bun,
      [:js],
      {:code,
       quote(
         do: [
           args:
             ~w(build js/app.js --outdir=../priv/static/assets/js --external /fonts/* --external /images/*),
           cd: Path.expand("../assets", __DIR__)
         ]
       )}
    )
    |> Igniter.Project.Config.configure(
      "config.exs",
      :phoenix_live_view,
      [:colocated_js],
      {:code,
       quote(
         do: [
           target_directory: Path.expand("../assets/node_modules/phoenix-colocated", __DIR__)
         ]
       )}
    )
  end

  defp edit_config_dev(igniter) do
    app_name = Igniter.Project.Application.app_name(igniter)
    app_web_name = Mix.Tasks.Project.Helpers.app_web_module(igniter)
    endpoint = Module.concat([app_web_name, "Endpoint"])

    igniter
    |> Igniter.Project.Config.configure(
      "dev.exs",
      app_name,
      [endpoint, :watchers],
      bun_css: {Bun, :install_and_run, [:css, ~w(--watch)]},
      bun_js: {Bun, :install_and_run, [:js, ~w(--sourcemap=inline --watch)]}
    )
  end

  defp edit_mix_aliases(igniter) do
    igniter
    |> Igniter.Project.TaskAliases.modify_existing_alias("assets.setup", fn zipper ->
      {:ok, Sourceror.Zipper.replace(zipper, ["bun.install --if-missing", "bun assets install"])}
    end)
    |> Igniter.Project.TaskAliases.modify_existing_alias("assets.build", fn zipper ->
      {:ok, Sourceror.Zipper.replace(zipper, ["bun css", "bun js"])}
    end)
    |> Igniter.Project.TaskAliases.modify_existing_alias("assets.deploy", fn zipper ->
      {:ok,
       Sourceror.Zipper.replace(zipper, ["bun css --minify", "bun js --minify", "phx.digest"])}
    end)
  end
end
