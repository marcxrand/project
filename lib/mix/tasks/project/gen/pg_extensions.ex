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
      execute "CREATE EXTENSION IF NOT EXISTS vector"

      execute \"""
      CREATE OR REPLACE FUNCTION public.f_unaccent(text)
        RETURNS text
        LANGUAGE sql IMMUTABLE PARALLEL SAFE STRICT AS
      $func$
        SELECT public.unaccent('public.unaccent', $1)
      $func$;
      \"""
    end

    def down do
      execute "DROP EXTENSION IF EXISTS citext"
      execute "DROP EXTENSION IF EXISTS pg_trgm"
      execute "DROP EXTENSION IF EXISTS unaccent"
      execute "DROP EXTENSION IF EXISTS vector"
      execute "DROP FUNCTION IF EXISTS public.f_unaccent(text);"
    end
    """

    igniter
    |> Mix.Tasks.Project.Helpers.gen_migration(repo, "add_extensions", body: migration_body)
    |> Igniter.add_task("ecto.reset")
  end
end
