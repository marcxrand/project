defmodule Mix.Tasks.Project.Remove.AgentsMd do
  @shortdoc "Removes the AGENTS.md file"
  @moduledoc "Removes the `AGENTS.md` file."
  use Igniter.Mix.Task

  @impl Igniter.Mix.Task
  def igniter(igniter) do
    if Igniter.exists?(igniter, "AGENTS.md") do
      Igniter.rm(igniter, "AGENTS.md")
    else
      igniter
    end
  end
end
