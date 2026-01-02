defmodule Mix.Tasks.Project.Add.RemixIcons do
  use Igniter.Mix.Task

  require Igniter.Code.Common
  alias Mix.Tasks.Project.Helpers

  @impl Igniter.Mix.Task
  def igniter(igniter) do
    igniter
    |> add_dep()
    |> create_plugin()
    |> update_app_css()
    |> add_icon_function()
  end

  defp add_dep(igniter) do
    tag = fetch_latest_github_tag("Remix-Design", "RemixIcon") || "v4.8.0"

    Igniter.Project.Deps.add_dep(igniter, {
      :remixicons,
      github: "Remix-Design/RemixIcon",
      tag: tag,
      sparse: "icons",
      app: false,
      compile: false,
      depth: 1
    })
  end

  defp fetch_latest_github_tag(owner, repo) do
    cache_key = {:project_github_tag, owner, repo}

    case :persistent_term.get(cache_key, :not_cached) do
      :not_cached ->
        tag = do_fetch_latest_github_tag(owner, repo)
        :persistent_term.put(cache_key, tag)
        tag

      cached_tag ->
        cached_tag
    end
  end

  defp do_fetch_latest_github_tag(owner, repo) do
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

  defp create_plugin(igniter) do
    content = """
    const plugin = require("tailwindcss/plugin");
    const fs = require("fs");
    const path = require("path");

    module.exports = plugin(function ({ matchComponents, theme }) {
      let iconsDir = path.join(__dirname, "../../deps/remixicons/icons");
      let values = {};

      // Read all category directories
      fs.readdirSync(iconsDir).forEach((category) => {
        let categoryPath = path.join(iconsDir, category);
        if (fs.statSync(categoryPath).isDirectory()) {
          fs.readdirSync(categoryPath).forEach((file) => {
            if (file.endsWith(".svg")) {
              let name = path.basename(file, ".svg");
              let fullPath = path.join(categoryPath, file);
              values[name] = { name, fullPath };
              // Make -line variant the default (e.g., "search" maps to "search-line")
              if (name.endsWith("-line")) {
                let baseName = name.slice(0, -5);
                values[baseName] = { name: baseName, fullPath };
              }
            }
          });
        }
      });

      matchComponents(
        {
          remix: ({ name, fullPath }) => {
            let content = fs
              .readFileSync(fullPath)
              .toString()
              .replace(/\\r?\\n|\\r/g, "");
            content = encodeURIComponent(content);
            let size = theme("spacing.4");
            return {
              [`--remix-${name}`]: `url('data:image/svg+xml;utf8,${content}')`,
              "-webkit-mask": `var(--remix-${name})`,
              mask: `var(--remix-${name})`,
              "mask-repeat": "no-repeat",
              "background-color": "currentColor",
              "vertical-align": "middle",
              display: "inline-block",
              width: size,
              height: size,
            };
          },
        },
        { values },
      );
    });
    """

    Igniter.create_new_file(igniter, "assets/vendor/remixicons.js", content)
  end

  defp update_app_css(igniter) do
    plugin_import =
      """
      /* A Tailwind plugin that makes "remix-\#{ICON}" classes available.
         The remixicon installation itself is managed by your mix.exs */
      @plugin "../vendor/remixicons";
      """

    Igniter.update_file(igniter, "assets/css/app.css", fn source ->
      content = Rewrite.Source.get(source, :content)

      updated =
        String.replace(
          content,
          ~s|@plugin "../vendor/heroicons";\n|,
          ~s|@plugin "../vendor/heroicons";\n\n| <> plugin_import
        )

      Rewrite.Source.update(source, :content, updated)
    end)
  end

  defp add_icon_function(igniter) do
    app_web_module = Helpers.app_web_module(igniter)
    core_components_module = Module.concat([app_web_module, "CoreComponents"])

    remix_icon_code = ~S'''
    def icon(%{name: "remix-" <> _} = assigns) do
      ~H"""
      <span class={[@name, @class]} />
      """
    end
    '''

    Igniter.Project.Module.find_and_update_module!(igniter, core_components_module, fn zipper ->
      case move_to_hero_icon_function(zipper) do
        {:ok, zipper} ->
          {:ok, Sourceror.Zipper.insert_right(zipper, Sourceror.parse_string!(remix_icon_code))}

        :error ->
          {:ok, Igniter.Code.Common.add_code(zipper, remix_icon_code)}
      end
    end)
  end

  defp move_to_hero_icon_function(zipper) do
    Igniter.Code.Common.move_to(zipper, fn z ->
      match?({:def, _, [{:icon, _, _} | _]}, Sourceror.Zipper.node(z))
    end)
  end

end
