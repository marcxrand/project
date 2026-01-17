![Project](https://media.cleanshot.cloud/media/8387/TSEL6OnynojJFHFhWkKdlYvW08STho3rsfDHCwJX.jpeg?Expires=1767563816&Signature=JSHVCHqbp8umamPnfFDQ5KExEzUKMRXlUmGDezIUKy-2OC0Nqu2rzFs2e0qXEoPxJM0YZnJBopuIz2mSvL63vBM7efppc9PUz3uX1yCyGm9vX8tuFMbg4kBfk0vpWKe3Bx8mKCBZdhYx22G-D82MPYvrfO8nNUaCzsHzBdcPcrK0K1wxY05ALJbFTsOBzChoMqeKQqUoJbrC0VZk9b03IxjAr41e4-~RT3fIv3WCUMxPcBc9XTvP7908WbxpLff2Rc~a785ES8Nh~OHYuAdmMWgD5jqqYQF3PdQhy1xq7zwUQnyB0weEt4klwzYS4hOECnISXK4OVJyFLsf8rOGq7A__&Key-Pair-Id=K269JMAT9ZF4GZ)


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
    {:project, "~> 1.0", only: :dev}
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

For a complete list of available tasks, see the [documentation](https://hexdocs.pm/project/api-reference.html#tasks).

## Customization

After running `mix project.gen.setup`, edit the `tasks/0` function in `lib/mix/tasks/<your_app_name>.setup.ex`.

- Reorder tasks
- Remove tasks you don't need
- Add your own custom tasks
- Use `{:optional, :flag_name}` placeholders for custom flags
