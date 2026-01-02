![Project](https://i.ibb.co/Wv3t0J8c/Gemini-Generated-Image-k6flm1k6flm1k6fl-min.png)


# Project
Automate common Phoenix setup tasks so you can quickly get to building!

## Features
- **Add tasks** - Install and configure packages like Bun, Oban, Credo, Pgvector, and more
- **Remove tasks** - Clean up unwanted code like DaisyUI, Topbar, theme toggle
- **Gen tasks** - Generate boilerplate code and run convenience tasks like sorting dependencies by name

## Installation
Add `project` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:project, "~> 1.0"}
  ]
end
```

Then fetch the dependency:

```bash
mix deps.get
```

#### Generate a custom setup task for your project:

```bash
mix project.gen.setup
```

This creates `lib/mix/tasks/<your_app_name>.setup.ex` which you can edit to control which tasks run and in what order.

#### Or run the default setup task directly

```bash
mix project.setup
```

## Usage

#### Optional tasks can be added via flags:

```bash
mix project.setup --oban-pro --gigalixir --mix-test-watch
mix your_app_name.setup --oban-pro 
```

#### Any task can be run individually

Add a package:

```bash
mix project.add bun
mix project.add oban,credo,pgvector
```

Remove code:

```bash
mix project.remove daisy_ui
mix project.remove theme_toggle
```

Generate code:

```bash
mix project.gen home_page
mix project.gen app_layout
```

### Available Tasks

#### Add Tasks
- `bun` - Replace esbuild/tailwind with Bun
- `credo` - Add Credo for static analysis
- `dotenv_parser` - Add DotenvParser for .env files
- `ex_sync` - Add ExSync for auto-recompilation
- `libcluster` - Add libcluster for node clustering
- `mix_test_watch` - Add mix_test_watch for running tests on file changes (optional)
- `oban` - Add Oban for background jobs
- `oban_pro` - Add Oban Pro extensions (optional)
- `oban_web` - Add Oban Web UI
- `pgvector` - Add pgvector for vector similarity search
- `quokka` - Add Quokka for database migrations
- `remix_icons` - Add Remix Icons
- `tidewave` - Add Tidewave AI assistant
- `uuidv7` - Add UUIDv7 support

#### Remove Tasks
- `daisy_ui` - Remove DaisyUI components
- `live_title_suffix` - Remove live title suffix
- `repo_credentials` - Remove repo credentials from config
- `theme_toggle` - Remove theme toggle functionality
- `topbar` - Remove topbar progress indicator

#### Gen Tasks
- `app_layout` - Generate a clean app layout
- `class_formatter` - Generate TailwindCSS class formatter
- `gigalixir` - Generate Gigalixir deployment config (optional)
- `gitignore` - Generate .gitignore additions
- `graph_db` - Generate graph database tables for nodes and edges (optional)
- `home_page` - Generate a minimal home page
- `pg_extensions` - Generate PostgreSQL extensions migration
- `repo_config` - Generate repo configuration
- `schema` - Generate schema helpers
- `sort_deps` - Sort mix.exs dependencies alphabetically

## Customization

After running `mix project.gen.setup`, edit the `tasks/0` function in `lib/mix/tasks/<your_app_name>.setup.ex`.

- Reorder tasks
- Remove tasks you don't need
- Add your own custom tasks
- Use `{:optional, :flag_name}` placeholders for custom flags
