defmodule Mix.Tasks.Project.Gen.GraphDb do
  @shortdoc "Generates graph database tables"
  @moduledoc "Generates graph database tables."
  use Igniter.Mix.Task

  alias Mix.Tasks.Project.Helpers

  @impl Igniter.Mix.Task
  def igniter(igniter) do
    repo = Helpers.repo(igniter)

    igniter
    |> add_nodes_migration(repo)
    |> add_edges_migration(repo)
    |> add_indexes_migration(repo)
    |> add_views_migration(repo)
    |> Igniter.add_task("ecto.reset")
  end

  defp add_nodes_migration(igniter, repo) do
    migration_body = """
    def change do
      create table(:nodes, primary_key: false) do
        add :id, :binary_id, primary_key: true
        add :type, :string, null: false
        add :data, :map, default: %{}, null: false
        add :deleted_at, :utc_datetime_usec

        timestamps(type: :utc_datetime_usec)
      end
    end
    """

    Mix.Tasks.Project.Helpers.gen_migration(igniter, repo, "add_nodes", body: migration_body)
  end

  defp add_edges_migration(igniter, repo) do
    migration_body = """
    def change do
      create table(:edges, primary_key: false) do
        add :id, :binary_id, primary_key: true
        add :type, :string, null: false
        add :weight, :float, default: 1.0, null: false
        add :source_id, references(:nodes, type: :binary_id), null: false
        add :target_id, references(:nodes, type: :binary_id), null: false
        add :data, :map, default: %{}, null: false

        timestamps(type: :utc_datetime_usec)
      end
    end
    """

    Mix.Tasks.Project.Helpers.gen_migration(igniter, repo, "add_edges", body: migration_body)
  end

  defp add_indexes_migration(igniter, repo) do
    migration_body = """
    def change do
      create index(:nodes, [:data], using: :gin)
      create index(:nodes, [:type])

      create unique_index(:nodes, ["(data->>'slug')"],
              where: "type = 'person' AND deleted_at IS NULL",
              name: :nodes_person_slug_unique)

      create index(:edges, [:data], using: :gin)
      create index(:edges, [:source_id])
      create index(:edges, [:target_id])
      create index(:edges, [:type])

      create index(:edges, [:source_id, :type])
      create index(:edges, [:target_id, :type])

      create index(:edges, [:source_id, :type, :target_id, :weight], name: :edges_outbound)
      create index(:edges, [:target_id, :type, :source_id, :weight], name: :edges_inbound)

      create unique_index(:edges, [:source_id, :target_id, :type], name: :edges_unique)
     end
    """

    Mix.Tasks.Project.Helpers.gen_migration(igniter, repo, "add_indexes", body: migration_body)
  end

  defp add_views_migration(igniter, repo) do
    migration_body = """
    def up do
      execute "CREATE VIEW people_view AS SELECT * FROM nodes WHERE type = 'person'"
    end

    def down do
      execute "DROP VIEW people_view"
    end
    """

    Mix.Tasks.Project.Helpers.gen_migration(igniter, repo, "add_views", body: migration_body)
  end
end
