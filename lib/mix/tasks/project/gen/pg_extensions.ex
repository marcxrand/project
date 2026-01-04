defmodule Mix.Tasks.Project.Gen.PgExtensions do
  @shortdoc "Generates PostgreSQL extensions migration"
  @moduledoc "Generates PostgreSQL extensions migration."
  use Igniter.Mix.Task

  alias Mix.Tasks.Project.Helpers

  @impl Igniter.Mix.Task
  def igniter(igniter) do
    repo = Helpers.repo(igniter)

    migration_body = """
    def up do
      execute "CREATE EXTENSION IF NOT EXISTS citext"
      execute "CREATE EXTENSION IF NOT EXISTS pg_trgm"
      execute "CREATE EXTENSION IF NOT EXISTS unaccent"

      execute \"""
      CREATE OR REPLACE FUNCTION public.immutable_unaccent(regdictionary, text)
        RETURNS text
        LANGUAGE c IMMUTABLE PARALLEL SAFE STRICT
        AS '$libdir/unaccent', 'unaccent_dict';
      \"""

      execute \"""
      CREATE OR REPLACE FUNCTION public.f_unaccent(text)
        RETURNS text
        LANGUAGE sql IMMUTABLE PARALLEL SAFE STRICT
      RETURN public.immutable_unaccent(regdictionary 'public.unaccent', $1);
      \"""
    end

    def down do
      execute "DROP EXTENSION IF EXISTS citext"
      execute "DROP EXTENSION IF EXISTS pg_trgm"
      execute "DROP EXTENSION IF EXISTS unaccent"

      execute "DROP FUNCTION IF EXISTS immutable_unaccent(regdictionary, text);"
      execute "DROP FUNCTION IF EXISTS f_unaccent(text);"
    end
    """

    igniter
    |> Mix.Tasks.Project.Helpers.gen_migration(repo, "add_extensions", body: migration_body)
    |> Igniter.add_task("ecto.reset")
  end
end
