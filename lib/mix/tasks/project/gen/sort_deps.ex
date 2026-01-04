defmodule Mix.Tasks.Project.Gen.SortDeps do
  @shortdoc "Sorts dependencies in mix.exs"
  @moduledoc "Sorts dependencies in `mix.exs`."
  use Igniter.Mix.Task

  @impl Igniter.Mix.Task
  def igniter(igniter) do
    Igniter.update_file(igniter, "mix.exs", fn source ->
      content = Rewrite.Source.get(source, :content)

      updated =
        Regex.replace(
          ~r/(defp deps do\s*\n\s*\[)([\s\S]*?)(\n\s*\]\s*\n\s*end)/,
          content,
          fn _, prefix, deps_content, suffix ->
            sorted = sort_deps(deps_content)
            prefix <> sorted <> suffix
          end
        )

      Rewrite.Source.update(source, :content, updated)
    end)
  end

  defp sort_deps(deps_content) do
    deps_content
    |> split_deps()
    |> Enum.sort_by(&extract_name/1)
    |> Enum.join(",")
  end

  defp split_deps(content) do
    # Split by top-level commas, handling nested brackets
    content
    |> String.trim()
    |> split_at_top_level_commas([])
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
  end

  defp split_at_top_level_commas(string, acc) do
    case find_top_level_comma(string, 0, 0, 0, 0) do
      nil ->
        Enum.reverse([string | acc])

      pos ->
        {dep, rest} = String.split_at(string, pos)
        rest = String.slice(rest, 1..-1//1)
        split_at_top_level_commas(rest, [dep | acc])
    end
  end

  defp find_top_level_comma(<<>>, _pos, _parens, _brackets, _braces), do: nil

  defp find_top_level_comma(<<?,, _rest::binary>>, pos, 0, 0, 0), do: pos

  defp find_top_level_comma(<<?(, rest::binary>>, pos, parens, brackets, braces),
    do: find_top_level_comma(rest, pos + 1, parens + 1, brackets, braces)

  defp find_top_level_comma(<<?), rest::binary>>, pos, parens, brackets, braces),
    do: find_top_level_comma(rest, pos + 1, parens - 1, brackets, braces)

  defp find_top_level_comma(<<?[, rest::binary>>, pos, parens, brackets, braces),
    do: find_top_level_comma(rest, pos + 1, parens, brackets + 1, braces)

  defp find_top_level_comma(<<?], rest::binary>>, pos, parens, brackets, braces),
    do: find_top_level_comma(rest, pos + 1, parens, brackets - 1, braces)

  defp find_top_level_comma(<<?{, rest::binary>>, pos, parens, brackets, braces),
    do: find_top_level_comma(rest, pos + 1, parens, brackets, braces + 1)

  defp find_top_level_comma(<<?}, rest::binary>>, pos, parens, brackets, braces),
    do: find_top_level_comma(rest, pos + 1, parens, brackets, braces - 1)

  defp find_top_level_comma(<<_char, rest::binary>>, pos, parens, brackets, braces),
    do: find_top_level_comma(rest, pos + 1, parens, brackets, braces)

  defp extract_name(dep_string) do
    case Regex.run(~r/\{:(\w+)/, dep_string) do
      [_, name] -> name
      _ -> dep_string
    end
  end
end
