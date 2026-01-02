defmodule Mix.Tasks.Project.Gen.Gigalixir do
  use Igniter.Mix.Task

  @erlang_default "28.3"
  @elixir_default "1.19.4"
  @nodejs_default "25.2.0"

  @impl Igniter.Mix.Task
  def igniter(igniter) do
    igniter
    |> add_tool_versions()
    |> edit_package_json()
  end

  defp add_tool_versions(igniter) do
    erlang = fetch_latest_erlang() || @erlang_default
    elixir = fetch_latest_elixir() || @elixir_default
    nodejs = fetch_latest_nodejs() || @nodejs_default

    content = """
    erlang #{erlang}
    elixir #{elixir}
    nodejs #{nodejs}
    """

    Igniter.create_new_file(igniter, ".tool-versions", content)
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

  defp fetch_latest_nodejs do
    case fetch_github_tag("nodejs", "node") do
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
