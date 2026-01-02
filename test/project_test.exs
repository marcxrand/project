defmodule ProjectTest do
  use ExUnit.Case

  test "setup task defines tasks list" do
    tasks = Mix.Tasks.Project.Setup.tasks()
    assert is_list(tasks)
    assert length(tasks) > 0
  end

  test "setup task defines optional tasks" do
    optional = Mix.Tasks.Project.Setup.optional_tasks()
    assert is_list(optional)
    assert Keyword.has_key?(optional, :oban_pro)
    assert Keyword.has_key?(optional, :gigalixir)
  end
end
