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
    |> add_atom_map_type()
    |> add_node_schema()
    |> add_edge_schema()
    |> add_embedding_schema()
    |> add_node_type_behaviour()
    |> add_member_node_type()
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
        add :data, :map, null: false
        add :type, :string, null: false

        timestamps(type: :utc_datetime_usec)
        add :deleted_at, :utc_datetime_usec
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
        add :data, :map, null: false
        add :from_id, references(:nodes, type: :binary_id), null: false
        add :to_id, references(:nodes, type: :binary_id), null: false

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
        add :type, :string, null: false
        add :text, :text, null: false
        add :vector, :vector, size: 1536, null: false
        add :model, :string, null: false
        add :node_id, references(:nodes, type: :binary_id), null: false

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
      create index(:edges, [:data], using: :gin)
      create index(:edges, [:from_id])
      create index(:edges, [:to_id])
      create index(:edges, [:name])
      create index(:edges, [:from_id, :name])
      create index(:edges, [:to_id, :name])
      create unique_index(:edges, [:from_id, :to_id, :name])
      create unique_index(:embeddings, [:node_id, :model])

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

  defp add_atom_map_type(igniter) do
    app_module = Helpers.app_module(igniter)
    app_name = Igniter.Project.Application.app_name(igniter)

    content = ~s'''
    defmodule #{app_module}.Ecto.AtomMap do
      @moduledoc """
      Custom Ecto type that stores maps as JSON but loads them with atom keys.

      This ensures consistent atom key access throughout application code,
      regardless of whether data was just inserted or loaded from the database.

      ## Usage

          schema "nodes" do
            field :data, #{app_module}.Ecto.AtomMap
          end

      Then access with atom keys: `node.data[:name]` or `node.data.name`
      """

      use Ecto.Type

      @impl true
      def type, do: :map

      @impl true
      def cast(data) when is_map(data) do
        {:ok, atomize_keys(data)}
      end

      def cast(_), do: :error

      @impl true
      def load(nil), do: {:ok, nil}

      def load(data) when is_map(data) do
        {:ok, atomize_keys(data)}
      end

      @impl true
      def dump(nil), do: {:ok, nil}
      def dump(data) when is_map(data), do: {:ok, data}
      def dump(_), do: :error

      # Structs (like DateTime) should pass through unchanged
      defp atomize_keys(%_{} = struct), do: struct

      defp atomize_keys(map) when is_map(map) do
        Map.new(map, fn {k, v} -> {to_atom(k), atomize_keys(v)} end)
      end

      defp atomize_keys(list) when is_list(list), do: Enum.map(list, &atomize_keys/1)
      defp atomize_keys(value), do: value

      defp to_atom(key) when is_atom(key), do: key
      defp to_atom(key) when is_binary(key), do: String.to_atom(key)
    end
    '''

    Igniter.create_new_file(igniter, "lib/#{app_name}/ecto/atom_map.ex", content)
  end

  defp add_node_type_behaviour(igniter) do
    app_name = Igniter.Project.Application.app_name(igniter)
    app_module = Helpers.app_module(igniter)

    content = ~s'''
    defmodule #{app_module}.Graph.NodeType do
      @moduledoc """
      Behaviour for defining node types in the graph.

      Each node type implements this behaviour to define:
      - Its type name (stored in the `type` column)
      - A changeset for validating the `data` field
      - The conflict target for upsert operations

      ## Using the Macro

          defmodule #{app_module}.Graph.NodeType.Publication do
            use #{app_module}.Graph.NodeType, conflict_field: :host

            embedded_schema do
              field :host, :string
              field :name, :string
            end

            @impl true
            def changeset(data) do
              %__MODULE__{}
              |> cast(data, [:host, :name])
              |> validate_required([:host])
            end
          end

      ## Options

        * `:type` - The type name string. Defaults to the lowercase last segment
          of the module name (e.g., `NodeType.Publication` → `"publication"`).
        * `:conflict_field` - Required. The field used for upsert conflict detection.
      """

      @doc """
      Returns the type name stored in the `type` column.
      """
      @callback type_name() :: String.t()

      @doc """
      Returns the SQL fragment for the conflict target used in upserts.
      Should match the unique index for this type.
      """
      @callback conflict_target() :: String.t()

      @doc """
      Returns a changeset for validating the node's data.
      The changeset is used to validate the `data` field before insertion.
      """
      @callback changeset(data :: map()) :: Ecto.Changeset.t()

      defmacro __using__(opts) do
        conflict_field = Keyword.fetch!(opts, :conflict_field)

        quote do
          @behaviour unquote(__MODULE__)

          use Ecto.Schema
          import Ecto.Changeset

          @primary_key false

          @impl true
          def type_name do
            unquote(opts[:type]) || __MODULE__ |> Module.split() |> List.last() |> String.downcase()
          end

          @impl true
          def conflict_target do
            "((data->>'#\{unquote(conflict_field)}')) WHERE type = '#\{type_name()}'"
          end

          defoverridable type_name: 0, conflict_target: 0
        end
      end
    end
    '''

    Igniter.create_new_file(igniter, "lib/#{app_name}/graph/node_type.ex", content)
  end

  defp add_node_schema(igniter) do
    app_name = Igniter.Project.Application.app_name(igniter)
    app_module = Helpers.app_module(igniter)

    content = ~s'''
    defmodule #{app_module}.Graph.Node do
      use #{app_module}.Schema

      schema "nodes" do
        field :type, :string
        field :data, #{app_module}.Ecto.AtomMap
        field :deleted_at, :utc_datetime_usec

        timestamps()
      end

      def changeset(node, attrs, type_module) do
        node
        |> Ecto.Changeset.cast(attrs, [:type, :data, :deleted_at])
        |> Ecto.Changeset.validate_required([:type, :data])
        |> validate_data(type_module)
        |> put_unique_constraint(type_module)
      end

      defp put_unique_constraint(changeset, type_module) do
        case type_module.type_name() do
          "member" -> Ecto.Changeset.unique_constraint(changeset, :data, name: :nodes_member_email_idx)
          _ -> changeset
        end
      end

      defp validate_data(changeset, type_module) do
        case Ecto.Changeset.get_field(changeset, :data) do
          nil ->
            changeset

          data ->
            data_changeset = type_module.changeset(data)

            if data_changeset.valid? do
              validated_data =
                data_changeset
                |> Ecto.Changeset.apply_changes()
                |> Map.from_struct()
                |> Map.reject(fn {_k, v} -> is_nil(v) end)

              Ecto.Changeset.put_change(changeset, :data, validated_data)
            else
              Enum.reduce(data_changeset.errors, changeset, fn {field, {msg, opts}}, cs ->
                Ecto.Changeset.add_error(cs, :"data.\#{field}", msg, opts)
              end)
            end
        end
      end
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

  defp add_member_node_type(igniter) do
    app_name = Igniter.Project.Application.app_name(igniter)
    app_module = Helpers.app_module(igniter)

    content = ~s'''
    defmodule #{app_module}.Graph.NodeType.Member do
      use #{app_module}.Graph.NodeType, conflict_field: :email

      embedded_schema do
        field :email, :string
        field :signed_in_at, :utc_datetime
        field :signed_in_count, :integer, default: 0
      end

      @impl true
      def changeset(data) do
        %__MODULE__{}
        |> cast(data, [:email, :signed_in_at, :signed_in_count])
        |> validate_required([:email])
        |> validate_format(:email, ~r/^[^\s]+@[^\s]+$/)
      end
    end
    '''

    Igniter.create_new_file(igniter, "lib/#{app_name}/graph/node_type/member.ex", content)
  end
end
