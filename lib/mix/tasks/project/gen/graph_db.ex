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
    |> add_schemas_node()
    |> Igniter.add_task("ecto.reset")
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
        add :name, :string, null: false
        add :weight, :float, default: 1.0, null: false
        add :from_id, references(:nodes, type: :binary_id), null: false
        add :to_id, references(:nodes, type: :binary_id), null: false
        add :data, :map, default: %{}, null: false

        timestamps(type: :utc_datetime_usec)
      end
    end
    """

    Mix.Tasks.Project.Helpers.gen_migration(igniter, repo, "add_edges", body: migration_body)
  end

  defp add_embeddings_migration(igniter, repo) do
    migration_body = """
    def change do
      create table(:embeddings, primary_key: false) do
        add :id, :binary_id, primary_key: true
        add :node_id, references(:nodes, type: :binary_id), null: false
        add :vector, :vector, size: 1536, null: false
        add :model, :string, null: false
        add :text, :text, null: false

        timestamps(type: :utc_datetime_usec)
      end
    end
    """

    Mix.Tasks.Project.Helpers.gen_migration(igniter, repo, "add_embeddings", body: migration_body)
  end

  defp add_indexes_migration(igniter, repo) do
    migration_body = """
    def change do
      create index(:nodes, [:data], using: :gin)
      create index(:nodes, [:type])

      execute("CREATE INDEX nodes_name_trgm ON nodes USING GIN ((data->>'name') gin_trgm_ops)",
      "DROP INDEX nodes_name_trgm")

      create unique_index(:nodes, ["(data->>'slug')"],
              where: "type = 'member' AND deleted_at IS NULL",
              name: :nodes_member_slug_unique)

      create index(:edges, [:data], using: :gin)
      create index(:edges, [:from_id])
      create index(:edges, [:to_id])
      create index(:edges, [:name])

      create index(:edges, [:from_id, :name])
      create index(:edges, [:to_id, :name])

      create index(:edges, [:from_id, :name, :to_id, :weight], name: :edges_outbound)
      create index(:edges, [:to_id, :name, :from_id, :weight], name: :edges_inbound)

      create unique_index(:edges, [:from_id, :to_id, :name], name: :edges_unique)

      create unique_index(:embeddings, [:node_id, :model])

      execute("CREATE INDEX embeddings_vector_idx ON embeddings USING hnsw (vector vector_cosine_ops)", "DROP INDEX embeddings_vector_idx")
     end
    """

    Mix.Tasks.Project.Helpers.gen_migration(igniter, repo, "add_indexes", body: migration_body)
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

    Mix.Tasks.Project.Helpers.gen_migration(igniter, repo, "add_views", body: migration_body)
  end

  defp add_node_schema(igniter) do
    app_name = Igniter.Project.Application.app_name(igniter)
    app_module = Helpers.app_module(igniter)

    content = ~s'''
    defmodule #{app_module}.Graph.Node do
      @moduledoc """
      Ecto schema for graph nodes - the primary entity in the knowledge graph.

      ## Overview

      Nodes represent entities in the graph. Each node has a `type` field and a `data`
      JSONB field containing type-specific attributes.

      ## Soft Deletion

      Nodes support soft deletion via `deleted_at`. Query with `include_deleted: true`
      option to include deleted nodes.

      ## Relationships

      - `outgoing_edges` - Edges where this node is the source (`from_id`)
      - `incoming_edges` - Edges where this node is the target (`to_id`)
      - `embeddings` - Vector embeddings for semantic search

      ## Accessing Data

          #{app_module}.Graph.Node.name(node)  # => "Example Name"
          #{app_module}.Graph.Node.slug(node)  # => "example-name"
      """

      use #{app_module}.Schema

      alias #{app_module}.Schemas

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
        |> cast(attrs, [:type, :data, :deleted_at])
        |> validate_required([:type, :data])
        |> validate_inclusion(:type, Schemas.Node.type_values())
        |> validate_node_data()
      end

      defp validate_node_data(changeset) do
        type = get_field(changeset, :type)
        data = get_field(changeset, :data)

        if type && data do
          case #{app_module}.Schemas.Node.validate(type, data) do
            {:ok, _validated} ->
              changeset

            {:error, errors} when is_list(errors) ->
              Enum.reduce(errors, changeset, fn error, cs ->
                add_error(cs, :data, error)
              end)

            {:error, error} ->
              add_error(changeset, :data, error)
          end
        else
          changeset
        end
      end

      @doc "Returns the name from the node's data field"
      def name(%__MODULE__{data: %{"name" => name}}), do: name
      def name(_), do: nil

      @doc "Returns the slug from the node's data field"
      def slug(%__MODULE__{data: %{"slug" => slug}}), do: slug
      def slug(_), do: nil

      @doc "Returns true if the node has been soft-deleted"
      def deleted?(%__MODULE__{deleted_at: nil}), do: false
      def deleted?(%__MODULE__{deleted_at: _}), do: true
    end
    '''

    Igniter.create_new_file(igniter, "lib/#{app_name}/graph/node.ex", content)
  end

  defp add_edge_schema(igniter) do
    app_name = Igniter.Project.Application.app_name(igniter)
    app_module = Helpers.app_module(igniter)

    id_type =
      if Igniter.Project.Deps.has_dep?(igniter, :uuidv7) do
        "UUIDv7"
      else
        ":binary_id"
      end

    content = ~s'''
    defmodule #{app_module}.Graph.Edge do
      @moduledoc """
      Ecto schema for graph edges - relationships between nodes.

      ## Overview

      Edges represent directed relationships between nodes. Each edge has a `name`
      indicating the relationship type, and optional `data` for edge metadata.

      ## Schema

      - `from_id` - Source node UUID (foreign key to nodes)
      - `to_id` - Target node UUID (foreign key to nodes)
      - `name` - Relationship type
      - `weight` - Numeric weight for the relationship (default: 1.0)
      - `data` - Optional JSONB metadata (e.g., role, confidence, context)
      - `inserted_at` / `updated_at` - Timestamps

      ## Notes

      - Uses UUIDv7 for ordered, time-based IDs
      """

      use Ecto.Schema

      import Ecto.Changeset

      @primary_key {:id, #{id_type}, autogenerate: true}
      @foreign_key_type #{id_type}
      @timestamps_opts [type: :utc_datetime_usec]

      schema "edges" do
        field :name, :string
        field :weight, :float, default: 1.0
        field :data, :map, default: %{}

        belongs_to :from, #{app_module}.Graph.Node
        belongs_to :to, #{app_module}.Graph.Node

        timestamps()
      end

      def changeset(edge, attrs) do
        edge
        |> cast(attrs, [:name, :weight, :data, :from_id, :to_id])
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

    id_type =
      if Igniter.Project.Deps.has_dep?(igniter, :uuidv7) do
        "UUIDv7"
      else
        ":binary_id"
      end

    content = ~s'''
    defmodule #{app_module}.Graph.Embedding do
      @moduledoc """
      Ecto schema for graph embeddings - vector representations of nodes.

      ## Overview

      Embeddings store vector representations of node content for semantic search.
      Each embedding is associated with a node and includes the model used to
      generate it and the source text.

      ## Schema

      - `node_id` - Reference to the parent node
      - `vector` - Vector embedding (1536 dimensions for OpenAI ada-002)
      - `model` - Name of the embedding model used
      - `text` - Source text that was embedded

      ## Notes

      - A node can have multiple embeddings from different models
      - Unique constraint on `[node_id, model]` prevents duplicate embeddings
      """

      use Ecto.Schema

      import Ecto.Changeset

      @primary_key {:id, #{id_type}, autogenerate: true}
      @foreign_key_type #{id_type}
      @timestamps_opts [type: :utc_datetime_usec]

      schema "embeddings" do
        field :vector, Pgvector.Ecto.Vector
        field :model, :string
        field :text, :string

        belongs_to :node, #{app_module}.Graph.Node

        timestamps()
      end

      def changeset(embedding, attrs) do
        embedding
        |> cast(attrs, [:node_id, :vector, :model, :text])
        |> validate_required([:node_id, :vector, :model, :text])
        |> foreign_key_constraint(:node_id)
        |> unique_constraint([:node_id, :model])
      end
    end
    '''

    Igniter.create_new_file(igniter, "lib/#{app_name}/graph/embedding.ex", content)
  end

  defp add_schemas_node(igniter) do
    app_name = Igniter.Project.Application.app_name(igniter)
    app_module = Helpers.app_module(igniter)

    content = ~s'''
    defmodule #{app_module}.Schemas.Node do
      @moduledoc """
      Node data validation and type-specific schemas.

      ## Overview

      This module contains embedded schemas for each node type and validates
      the `data` field based on the node's `type`.

      ## Adding New Node Types

      1. Add a nested schema module (e.g., `defmodule PersonData do ... end`)
      2. Add an entry to `@types` mapping the type string to the schema module

      ## Usage

          #{app_module}.Schemas.Node.validate("member", %{"name" => "Jane", "slug" => "jane"})
          # => {:ok, %#{app_module}.Schemas.Node.MemberData{name: "Jane", slug: "jane"}}

          #{app_module}.Schemas.Node.validate("member", %{})
          # => {:error, ["name can't be blank", "slug can't be blank"]}
      """

      import Ecto.Changeset

      # ------------------------------------------------------------------
      # Type-specific schemas
      # ------------------------------------------------------------------

      defmodule MemberData do
        @moduledoc "Embedded schema for member node data."
        use Ecto.Schema
        import Ecto.Changeset

        @primary_key false
        embedded_schema do
          field :name, :string
          field :slug, :string
          field :email, :string
          field :description, :string
        end

        def changeset(schema, attrs) do
          schema
          |> cast(attrs, [:name, :slug, :email, :description])
          |> validate_required([:name, :slug])
          |> validate_format(:slug, ~r/^[a-z0-9]+(?:-[a-z0-9]+)*$/, message: "must be lowercase with hyphens")
          |> validate_format(:email, ~r/^[^\s]+@[^\s]+$/, message: "must be a valid email")
        end
      end

      # ------------------------------------------------------------------
      # Type registry
      # ------------------------------------------------------------------

      @types %{
        "member" => MemberData
      }

      @doc "Returns list of valid node type strings"
      def type_values, do: Map.keys(@types)

      @doc "Returns the schema module for a given type"
      def schema_for(type), do: Map.get(@types, type)

      # ------------------------------------------------------------------
      # Validation
      # ------------------------------------------------------------------

      @doc "Validates data for the given node type"
      def validate(type, data) do
        case schema_for(type) do
          nil ->
            {:error, "unknown node type: \#{type}"}

          schema_module ->
            struct(schema_module)
            |> schema_module.changeset(data)
            |> validate_changeset()
        end
      end

      defp validate_changeset(%{valid?: true} = changeset) do
        {:ok, Ecto.Changeset.apply_changes(changeset)}
      end

      defp validate_changeset(%{errors: errors}) do
        messages = Enum.map(errors, fn {field, {msg, _opts}} ->
          "\#{field} \#{msg}"
        end)
        {:error, messages}
      end
    end
    '''

    Igniter.create_new_file(igniter, "lib/#{app_name}/schemas/node.ex", content)
  end
end
