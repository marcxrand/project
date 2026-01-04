defmodule Mix.Tasks.Project.Remove.AgentsMd do
  use Igniter.Mix.Task

  @impl Igniter.Mix.Task
  def igniter(igniter) do
    Igniter.rm(igniter, "agent.md")
  end
end
