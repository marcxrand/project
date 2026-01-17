defmodule Mix.Tasks.Project.Gen.Gigalixir do
  @shortdoc "Generates Gigalixir deployment configuration"
  @moduledoc "Generates Gigalixir deployment configuration."
  use Igniter.Mix.Task

  alias Mix.Tasks.Project.Helpers

  @erlang_default "28.3"
  @elixir_default "1.19.4"

  @impl Igniter.Mix.Task
  def igniter(igniter) do
    igniter
    |> add_elixir_buildpack()
    |> add_buildpacks_file()
    |> add_build_assets_script()
    |> add_procfile()
    |> add_scripts_module()
    |> configure_repo_ssl()
    |> configure_endpoint_server()
    |> edit_package_json()
    |> remove_colocated_hooks()
    |> Igniter.add_notice("Run: gigalixir config:set OBAN_PRO_AUTH_KEY=<your-key>")
    |> Igniter.add_notice(
      "Run: gigalixir create -n \"your-app-name\" && gigalixir pg:create --free && git push gigalixir"
    )
  end

  defp add_elixir_buildpack(igniter) do
    erlang = fetch_latest_erlang() || @erlang_default
    elixir = fetch_latest_elixir() || @elixir_default

    content = """
    erlang_version=#{erlang}
    elixir_version=#{elixir}

    # Fetch Oban Pro
    hook_pre_fetch_dependencies="mix hex.repo add oban https://repo.oban.pro \
      --fetch-public-key SHA256:4/OSKi0NRF91QVVXlGAhb/BIMLnK8NHcx/EWs+aIWPc \
      --auth-key ${OBAN_PRO_AUTH_KEY}"

    # Run custom asset build after compilation (uses Bun via mix tasks)
    hook_post_compile="./build_assets"

    """

    if Igniter.exists?(igniter, "elixir_buildpack.config") do
      Igniter.update_file(igniter, "elixir_buildpack.config", fn source ->
        Rewrite.Source.update(source, :content, content)
      end)
    else
      Igniter.create_new_file(igniter, "elixir_buildpack.config", content)
    end
  end

  defp add_buildpacks_file(igniter) do
    content = """
    https://github.com/gigalixir/gigalixir-buildpack-elixir
    https://github.com/gigalixir/gigalixir-buildpack-releases.git
    """

    if Igniter.exists?(igniter, ".buildpacks") do
      Igniter.update_file(igniter, ".buildpacks", fn source ->
        Rewrite.Source.update(source, :content, content)
      end)
    else
      Igniter.create_new_file(igniter, ".buildpacks", content)
    end
  end

  defp add_build_assets_script(igniter) do
    content = """
    #!/usr/bin/env bash

    set -e

    echo "-----> Building assets with Bun"

    # Install Bun and npm dependencies
    echo "-----> Setting up assets..."
    mix assets.setup

    # Build and digest assets (uses mix bun tasks under the hood)
    echo "-----> Deploying assets..."
    mix assets.deploy

    echo "-----> Assets built successfully!"
    """

    igniter
    |> Igniter.create_new_file("build_assets", content)
    |> Igniter.add_notice("Run: chmod +x ./build_assets")
  end

  defp add_procfile(igniter) do
    scripts_module = Igniter.Project.Module.module_name(igniter, "Scripts")

    content = """
    web: /app/bin/$GIGALIXIR_APP_NAME eval '#{scripts_module}.migrate' && /app/bin/$GIGALIXIR_APP_NAME $GIGALIXIR_COMMAND
    """

    Igniter.create_new_file(igniter, "rel/overlays/Procfile", content)
  end

  defp add_scripts_module(igniter) do
    app_name = Igniter.Project.Application.app_name(igniter)
    scripts_module = Igniter.Project.Module.module_name(igniter, "Scripts")

    content = """
    defmodule #{scripts_module} do
      def migrate do
        load_app()

        for repo <- repos() do
          {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :up, all: true))
        end
      end

      def rollback(repo, version) do
        load_app()
        {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :down, to: version))
      end

      defp repos do
        Application.fetch_env!(:#{app_name}, :ecto_repos)
      end

      defp load_app do
        # Many platforms require SSL when connecting to the database
        Application.ensure_all_started(:ssl)
        Application.ensure_loaded(:#{app_name})
      end
    end
    """

    Igniter.create_new_file(igniter, "lib/#{app_name}/scripts.ex", content)
  end

  defp configure_repo_ssl(igniter) do
    app_name = Igniter.Project.Application.app_name(igniter)
    repo = Helpers.repo(igniter)
    ssl_opts = {:code, "[verify: :verify_none, cacerts: :public_key.cacerts_get()]"}

    Igniter.Project.Config.configure_runtime_env(igniter, :prod, app_name, [repo, :ssl], ssl_opts)
  end

  defp configure_endpoint_server(igniter) do
    app_name = Igniter.Project.Application.app_name(igniter)
    endpoint = Module.concat([Helpers.app_web_module(igniter), "Endpoint"])

    Igniter.Project.Config.configure_runtime_env(igniter, :prod, app_name, [endpoint, :server], true)
  end

  defp edit_package_json(igniter) do
    has_esbuild? = Igniter.Project.Deps.has_dep?(igniter, :esbuild)

    deploy_script =
      if has_esbuild?,
        do: "cd .. && mix assets.deploy && rm -f _build/esbuild*",
        else: "cd .. && mix assets.deploy"

    if Igniter.exists?(igniter, "assets/package.json") do
      Igniter.update_file(igniter, "assets/package.json", fn source ->
        content = Rewrite.Source.get(source, :content)

        updated =
          content
          |> Jason.decode!()
          |> put_in([Access.key("scripts", %{}), "deploy"], deploy_script)
          |> Jason.encode!(pretty: true)

        Rewrite.Source.update(source, :content, updated <> "\n")
      end)
    else
      content =
        %{"scripts" => %{"deploy" => deploy_script}}
        |> Jason.encode!(pretty: true)

      Igniter.create_new_file(igniter, "assets/package.json", content <> "\n")
    end
  end

  defp remove_colocated_hooks(igniter) do
    app_js_path = "assets/js/app.js"
    app_name = Igniter.Project.Application.app_name(igniter)

    if Igniter.exists?(igniter, app_js_path) do
      Igniter.update_file(igniter, app_js_path, fn source ->
        content = Rewrite.Source.get(source, :content)

        updated =
          content
          # Remove the colocated hooks import line
          |> String.replace(
            ~r/import \{hooks as colocatedHooks\} from "phoenix-colocated\/#{app_name}"\n/,
            ""
          )
          # Remove hooks option from LiveSocket
          |> String.replace(~r/\s*hooks: \{\.\.\.colocatedHooks\},?\n/, "")

        Rewrite.Source.update(source, :content, updated)
      end)
    else
      igniter
    end
  end

  defp fetch_latest_erlang do
    case fetch_github_tag("erlang", "otp") do
      "OTP-" <> version -> version
      _ -> nil
    end
  end

  defp fetch_latest_elixir do
    case fetch_github_tag("elixir-lang", "elixir") do
      "v" <> version -> version
      _ -> nil
    end
  end

  defp fetch_github_tag(owner, repo) do
    :inets.start()
    :ssl.start()

    url = ~c"https://api.github.com/repos/#{owner}/#{repo}/releases/latest"
    headers = [{~c"user-agent", ~c"mix-task"}, {~c"accept", ~c"application/vnd.github+json"}]

    case :httpc.request(:get, {url, headers}, [timeout: 5_000], body_format: :binary) do
      {:ok, {{_, 200, _}, _, body}} ->
        case Jason.decode(body) do
          {:ok, %{"tag_name" => tag}} -> tag
          _ -> nil
        end

      _ ->
        nil
    end
  end
end
