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
    |> add_node_type_behaviour()
    |> add_node_types_registry()
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
      - Conflict keys for upsert operations
      - Type-specific constraints

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
        * `:conflict_field` - The field used for upsert conflict detection.
      """

      @callback type_name() :: String.t()
      @callback changeset(data :: map()) :: Ecto.Changeset.t()
      @callback conflict_keys() :: [atom()]
      @callback put_constraints(Ecto.Changeset.t()) :: Ecto.Changeset.t()

      defmacro __using__(opts) do
        conflict_field = opts[:conflict_field]

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
          def conflict_keys do
            case unquote(conflict_field) do
              nil -> []
              field -> [field]
            end
          end

          @impl true
          def put_constraints(changeset), do: changeset

          defoverridable type_name: 0, conflict_keys: 0, put_constraints: 1
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

      alias #{app_module}.Graph.NodeTypes

      schema "nodes" do
        field :type, :string
        field :data, :map
        field :deleted_at, :utc_datetime_usec

        timestamps()
      end

      def changeset(node, attrs) do
        changeset =
          node
          |> cast(attrs, [:type, :data, :deleted_at])
          |> validate_required([:type, :data])

        with {_, type} when is_binary(type) <- fetch_field(changeset, :type),
             {:ok, type_module} <- NodeTypes.fetch(type) do
          changeset
          |> validate_data(type_module)
          |> type_module.put_constraints()
        else
          _ -> add_error(changeset, :type, "is not a valid node type")
        end
      end

      defp validate_data(changeset, type_module) do
        case get_field(changeset, :data) do
          nil ->
            changeset

          data ->
            data_changeset = type_module.changeset(data)

            if data_changeset.valid? do
              validated_data =
                data_changeset
                |> apply_changes()
                |> Map.from_struct()
                |> Map.reject(fn {_k, v} -> is_nil(v) end)
                |> Map.new(fn {k, v} -> {Atom.to_string(k), v} end)

              put_change(changeset, :data, validated_data)
            else
              Enum.reduce(data_changeset.errors, changeset, fn {field, {msg, opts}}, cs ->
                add_error(cs, :"data.\#{field}", msg, opts)
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

    content = ~s'''
    defmodule #{app_module}.Graph.Edge do
      @moduledoc """
      Ecto schema for graph edges — relationships between nodes.

      Edges represent directed relationships between nodes. Each edge has a `name`
      indicating the relationship type, and optional `data` for edge metadata.

      A unique constraint on `[from_id, to_id, name]` prevents duplicate edges.
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

      A unique constraint on `[node_id, model]` prevents duplicate embeddings.
      """

      use #{app_module}.Schema

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

  defp add_node_types_registry(igniter) do
    app_name = Igniter.Project.Application.app_name(igniter)
    app_module = Helpers.app_module(igniter)

    content = ~s'''
    defmodule #{app_module}.Graph.NodeTypes do
      @moduledoc """
      Registry mapping node type name strings to their implementing modules.
      """

      @types %{
        "member" => #{app_module}.Graph.Member
      }

      def module!(type), do: Map.fetch!(@types, type)
      def fetch(type), do: Map.fetch(@types, type)
      def valid?(type), do: Map.has_key?(@types, type)
      def all, do: @types
    end
    '''

    Igniter.create_new_file(igniter, "lib/#{app_name}/graph/node_types.ex", content)
  end

  defp add_member_node_type(igniter) do
    app_name = Igniter.Project.Application.app_name(igniter)
    app_module = Helpers.app_module(igniter)

    content = ~s'''
    defmodule #{app_module}.Graph.Member do
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
        |> validate_format(:email, ~r/^[^ ]+@[^ ]+$/)
      end

      @impl true
      def put_constraints(changeset) do
        unique_constraint(changeset, :data, name: :nodes_member_email_idx)
      end
    end
    '''

    Igniter.create_new_file(igniter, "lib/#{app_name}/graph/member.ex", content)
  end
end
