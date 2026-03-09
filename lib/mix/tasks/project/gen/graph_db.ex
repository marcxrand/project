defmodule Mix.Tasks.Project.Gen.GraphDb do
  @shortdoc "Generates graph database tables"
  @moduledoc "Generates graph database tables."
  use Igniter.Mix.Task

  alias Mix.Tasks.Project.Helpers

  @impl Igniter.Mix.Task
  def igniter(igniter) do
    repo = Helpers.repo(igniter)

    igniter
    |> maybe_add_pg_extensions()
    |> Igniter.compose_task(Mix.Tasks.Project.Add.Pgvector)
    |> add_nodes_migration(repo)
    |> add_edges_migration(repo)
    |> add_embeddings_migration(repo)
    |> add_indexes_migration(repo)
    |> add_views_migration(repo)
    |> add_node_schema()
    |> add_edge_schema()
    |> add_embedding_schema()
    |> add_member_node_type()
    |> add_graph_context()
  end

  defp maybe_add_pg_extensions(igniter) do
    repo_name =
      Helpers.repo(igniter)
      |> Module.split()
      |> List.last()
      |> Macro.underscore()

    migrations_path = "priv/#{repo_name}/migrations"
    igniter = Igniter.include_glob(igniter, Path.join(migrations_path, "*_add_extensions.exs"))

    has_extensions_migration? =
      igniter.rewrite
      |> Rewrite.sources()
      |> Enum.any?(fn source ->
        String.match?(source.path, ~r/migrations\/\d+_add_extensions\.exs$/)
      end)

    if has_extensions_migration? do
      igniter
    else
      Igniter.compose_task(igniter, Mix.Tasks.Project.Gen.PgExtensions)
    end
  end

  defp add_nodes_migration(igniter, repo) do
    migration_body = """
    def change do
      create table(:nodes, primary_key: false) do
        add :id, :binary_id, primary_key: true
        add :data, :map, null: false
        add :type, :string, null: false

        timestamps(type: :utc_datetime_usec)
        add :deleted_at, :utc_datetime_usec
      end
    end
    """

    Helpers.gen_migration(igniter, repo, "add_nodes", body: migration_body)
  end

  defp add_edges_migration(igniter, repo) do
    migration_body = """
    def change do
      create table(:edges, primary_key: false) do
        add :id, :binary_id, primary_key: true
        add :name, :string, null: false
        add :data, :map, null: false, default: %{}
        add :from_id, references(:nodes, type: :binary_id), null: false
        add :to_id, references(:nodes, type: :binary_id), null: false

        timestamps(type: :utc_datetime_usec)
      end
    end
    """

    Helpers.gen_migration(igniter, repo, "add_edges", body: migration_body)
  end

  defp add_embeddings_migration(igniter, repo) do
    migration_body = """
    def change do
      create table(:embeddings, primary_key: false) do
        add :id, :binary_id, primary_key: true
        add :type, :string, null: false
        add :text, :text, null: false
        add :vector, :vector, null: false
        add :model, :string, null: false
        add :node_id, references(:nodes, type: :binary_id), null: false

        timestamps(type: :utc_datetime_usec)
      end
    end
    """

    Helpers.gen_migration(igniter, repo, "add_embeddings", body: migration_body)
  end

  defp add_indexes_migration(igniter, repo) do
    migration_body = """
    def change do
      create index(:nodes, [:data], using: :gin)
      create index(:nodes, [:type])
      create index(:edges, [:data], using: :gin)
      create index(:edges, [:name])
      create index(:edges, [:from_id, :name])
      create index(:edges, [:to_id, :name])
      create index(:edges, [:from_id, :to_id, :name])
      create unique_index(:embeddings, [:node_id, :model, :type])

      create unique_index(:nodes, ["(data->>'email')"],
              where: "type = 'member' AND deleted_at IS NULL",
              name: :nodes_member_email_idx)

      execute(
        "CREATE INDEX nodes_name_trgm ON nodes USING GIN ((data->>'name') gin_trgm_ops)",
        "DROP INDEX nodes_name_trgm"
      )

      execute(
        "CREATE INDEX embeddings_vector_idx ON embeddings USING hnsw (vector vector_cosine_ops)",
        "DROP INDEX embeddings_vector_idx"
      )
    end
    """

    Helpers.gen_migration(igniter, repo, "add_indexes", body: migration_body)
  end

  defp add_views_migration(igniter, repo) do
    migration_body = """
    def up do
      execute "CREATE VIEW members_view AS SELECT * FROM nodes WHERE type = 'member'"
    end

    def down do
      execute "DROP VIEW members_view"
    end
    """

    Helpers.gen_migration(igniter, repo, "add_views", body: migration_body)
  end

  defp add_node_schema(igniter) do
    app_name = Igniter.Project.Application.app_name(igniter)
    app_module = Helpers.app_module(igniter)

    content = ~s'''
    defmodule #{app_module}.Graph.Node do
      use #{app_module}.Schema

      schema "nodes" do
        field :type, :string
        field :data, :map
        field :deleted_at, :utc_datetime_usec

        has_many :outgoing_edges, #{app_module}.Graph.Edge, foreign_key: :from_id
        has_many :incoming_edges, #{app_module}.Graph.Edge, foreign_key: :to_id
        has_many :embeddings, #{app_module}.Graph.Embedding

        timestamps()
      end

      def changeset(node, attrs) do
        node
        |> cast(attrs, [:type, :data])
        |> validate_required([:type, :data])
      end
    end
    '''

    Igniter.create_new_file(igniter, "lib/#{app_name}/graph/node.ex", content)
  end

  defp add_edge_schema(igniter) do
    app_name = Igniter.Project.Application.app_name(igniter)
    app_module = Helpers.app_module(igniter)

    content = ~s'''
    defmodule #{app_module}.Graph.Edge do
      @moduledoc """
      Ecto schema for graph edges — relationships between nodes.

      Edges represent directed relationships between nodes. Each edge has a `name`
      indicating the relationship type, and optional `data` for edge metadata.
      """

      use #{app_module}.Schema

      schema "edges" do
        field :name, :string
        field :data, :map, default: %{}

        belongs_to :from, #{app_module}.Graph.Node
        belongs_to :to, #{app_module}.Graph.Node

        timestamps()
      end

      def changeset(edge, attrs) do
        edge
        |> cast(attrs, [:name, :data, :from_id, :to_id])
        |> validate_required([:name, :from_id, :to_id])
        |> foreign_key_constraint(:from_id)
        |> foreign_key_constraint(:to_id)
      end
    end
    '''

    Igniter.create_new_file(igniter, "lib/#{app_name}/graph/edge.ex", content)
  end

  defp add_embedding_schema(igniter) do
    app_name = Igniter.Project.Application.app_name(igniter)
    app_module = Helpers.app_module(igniter)

    content = ~s'''
    defmodule #{app_module}.Graph.Embedding do
      @moduledoc """
      Ecto schema for graph embeddings — vector representations of nodes.

      Embeddings store vector representations of node content for semantic search.
      Each embedding is associated with a node and includes the model used to
      generate it and the source text.

      A unique constraint on `[node_id, model, type]` prevents duplicate embeddings.
      """

      use #{app_module}.Schema

      schema "embeddings" do
        field :type, :string
        field :vector, Pgvector.Ecto.Vector
        field :model, :string
        field :text, :string

        belongs_to :node, #{app_module}.Graph.Node

        timestamps()
      end

      def changeset(embedding, attrs) do
        embedding
        |> cast(attrs, [:type, :node_id, :vector, :model, :text])
        |> validate_required([:type, :node_id, :vector, :model, :text])
        |> foreign_key_constraint(:node_id)
        |> unique_constraint([:node_id, :model, :type])
      end
    end
    '''

    Igniter.create_new_file(igniter, "lib/#{app_name}/graph/embedding.ex", content)
  end

  defp add_member_node_type(igniter) do
    app_name = Igniter.Project.Application.app_name(igniter)
    app_module = Helpers.app_module(igniter)

    content = ~s'''
    defmodule #{app_module}.Graph.Member do
      @moduledoc """
      Example graph node type for members.

      Node type modules are plain Ecto embedded schemas that define:

        * `changeset/1` — validates the node's `data` field
        * `put_constraints/1` — (optional) adds database constraints to the node changeset
      """

      use Ecto.Schema
      import Ecto.Changeset

      @primary_key false

      embedded_schema do
        field :email, :string
        field :signed_in_at, :utc_datetime
        field :signed_in_count, :integer, default: 0
      end

      def changeset(data) do
        %__MODULE__{}
        |> cast(data, [:email, :signed_in_at, :signed_in_count])
        |> validate_required([:email])
        |> validate_format(:email, ~r/^[^ ]+@[^ ]+$/)
      end

      def put_constraints(changeset) do
        unique_constraint(changeset, :data, name: :nodes_member_email_idx)
      end
    end
    '''

    Igniter.create_new_file(igniter, "lib/#{app_name}/graph/member.ex", content)
  end

  defp add_graph_context(igniter) do
    app_name = Igniter.Project.Application.app_name(igniter)
    app_module = Helpers.app_module(igniter)

    content = ~s'''
    defmodule #{app_module}.Graph do
      @moduledoc """
      Context for working with the graph database.
      """

      import Ecto.Query

      alias #{app_module}.Repo
      alias #{app_module}.Graph.{Node, Edge}

      # Nodes

      def create_node(type_module, attrs) do
        with {:ok, data} <- cast_data(type_module, attrs) do
          %Node{}
          |> Node.changeset(%{type: type_name(type_module), data: data})
          |> maybe_put_constraints(type_module)
          |> Repo.insert()
        end
      end

      def get_node(id), do: Repo.get(Node, id)
      def get_node!(id), do: Repo.get!(Node, id)

      def delete_node(%Node{} = node) do
        node
        |> Ecto.Changeset.change(deleted_at: DateTime.utc_now())
        |> Repo.update()
      end

      # Edges

      def connect(%Node{} = from, %Node{} = to, name, data \\\\ %{}) do
        %Edge{}
        |> Edge.changeset(%{from_id: from.id, to_id: to.id, name: name, data: data})
        |> Repo.insert()
      end

      def disconnect(%Node{} = from, %Node{} = to, name) do
        {count, _} =
          from(e in Edge,
            where: e.from_id == ^from.id and e.to_id == ^to.id and e.name == ^name
          )
          |> Repo.delete_all()

        {:ok, count}
      end

      # Traversal

      def neighbors_query(%Node{} = node, direction \\\\ :outgoing)

      def neighbors_query(%Node{} = node, :outgoing) do
        from(n in Node,
          join: e in Edge, on: e.to_id == n.id,
          where: e.from_id == ^node.id,
          where: is_nil(n.deleted_at)
        )
      end

      def neighbors_query(%Node{} = node, :incoming) do
        from(n in Node,
          join: e in Edge, on: e.from_id == n.id,
          where: e.to_id == ^node.id,
          where: is_nil(n.deleted_at)
        )
      end

      def neighbors(%Node{} = node, direction \\\\ :outgoing) do
        node |> neighbors_query(direction) |> Repo.all()
      end

      # Private

      defp cast_data(type_module, attrs) do
        with {:ok, struct} <- Ecto.Changeset.apply_action(type_module.changeset(attrs), :validate) do
          {:ok, to_json_map(struct)}
        end
      end

      defp to_json_map(struct) do
        struct
        |> Map.from_struct()
        |> Map.new(fn {k, v} -> {Atom.to_string(k), v} end)
      end

      defp type_name(module) do
        module |> Module.split() |> List.last() |> String.downcase()
      end

      defp maybe_put_constraints(changeset, type_module) do
        if function_exported?(type_module, :put_constraints, 1) do
          type_module.put_constraints(changeset)
        else
          changeset
        end
      end
    end
    '''

    Igniter.create_new_file(igniter, "lib/#{app_name}/graph.ex", content)
  end
end
