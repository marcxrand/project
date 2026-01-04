defmodule Mix.Tasks.Project.Remove.AgentsMd do
  @shortdoc "Removes the agent.md file"
  @moduledoc "Removes the `agent.md` file."
  use Igniter.Mix.Task

  @impl Igniter.Mix.Task
  def igniter(igniter) do
    Igniter.rm(igniter, "agent.md")
  end
end
