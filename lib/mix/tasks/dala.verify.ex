defmodule Mix.Tasks.Dala.Verify do
  @shortdoc "Verify Dala DSL definitions and project configuration"

  @moduledoc """
  Verifies Dala DSL definitions in the current project and reports any issues.

  ## Usage

      mix dala.verify              # Run all verifications
      mix dala.verify --dsl        # Verify DSL definitions only
      mix dala.verify --components # List all available components
      mix dala.verify --strict     # Exit with error code on warnings

  ## What it checks

  When `--dala.verify --dsl` is used, the following checks are performed:

  - **Unknown component types** — component atoms not in the registry
  - **Invalid prop names** — props not accepted by the component (with typo suggestions)
  - **Event handler types** — event handler props that are not atoms or {pid, tag} tuples
  - **Leaf with children** — children placed inside leaf components
  - **Invalid attribute types** — attribute types not in the valid set
  - **Missing handlers** — event handlers referenced in UI but no handle_event/3 clause
  - **Invalid variants** — invalid variant values on text components

  ## Examples

      mix dala.verify --dsl
      mix dala.verify --dsl --strict
      mix dala.verify --components
  """

  use Mix.Task

  @switches [
    dsl: :boolean,
    components: :boolean,
    strict: :boolean
  ]

  @impl Mix.Task
  def run(argv) do
    {opts, _rest, _invalid} = OptionParser.parse(argv, strict: @switches)

    cond do
      opts[:components] ->
        list_components()

      opts[:dsl] ->
        verify_dsl(opts)

      true ->
        verify_all(opts)
    end
  end

  # ── DSL verification ────────────────────────────────────────────────────────

  defp verify_dsl(opts) do
    Mix.shell().info("\n🔍 Verifying Dala DSL definitions...\n")

    modules = find_dala_screens()

    if modules == [] do
      Mix.shell().info("  No Dala screen modules found in the current project.")
      Mix.shell().info("  Make sure your screens use `Dala.Screen` or `Dala.Spark.Dsl`.")
    else
      all_warnings =
        Enum.flat_map(modules, fn module ->
          Mix.shell().info("  Checking #{inspect(module)}...")
          Dala.Spark.DslVerifier.verify_module(module)
        end)

      report(all_warnings, opts)
    end
  end

  # ── All verification ────────────────────────────────────────────────────────

  defp verify_all(opts) do
    Mix.shell().info("\n🔍 Running all Dala verifications...\n")

    dsl_warnings =
      case find_dala_screens() do
        [] ->
          Mix.shell().info("  No Dala screen modules found.")
          []

        modules ->
          Enum.flat_map(modules, &Dala.Spark.DslVerifier.verify_module/1)
      end

    report(dsl_warnings, opts)
  end

  # ── Report ───────────────────────────────────────────────────────────────────

  defp report([], _opts) do
    Mix.shell().info("\n  ✓ All DSL definitions look correct. No issues found.\n")
  end

  defp report(warnings, opts) do
    errors = Enum.filter(warnings, &(&1.type == :error))
    warns = Enum.filter(warnings, &(&1.type == :warning))

    Dala.Spark.DslVerifier.print_warnings(warnings)

    Mix.shell().info("\n#{Dala.Spark.DslVerifier.format_report(warnings)}")

    if opts[:strict] and (length(errors) > 0 or length(warns) > 0) do
      Mix.raise(
        "DSL verification failed with #{length(errors)} error(s) and #{length(warns)} warning(s)"
      )
    end

    if length(errors) > 0 do
      exit({:shutdown, 1})
    end
  end

  # ── Component listing ───────────────────────────────────────────────────────

  defp list_components do
    components = Dala.Ui.Component.all()
    leaf_count = Enum.count(components, fn {_, c} -> c.category == :leaf end)
    container_count = Enum.count(components, fn {_, c} -> c.category == :container end)

    Mix.shell().info("""

    ╔══════════════════════════════════════════════════════════════╗
    ║           Dala UI Component Registry                         ║
    ║           #{leaf_count} leaf + #{container_count} container = #{length(components)} total components                    ║
    ╚══════════════════════════════════════════════════════════════╝
    """)

    Mix.shell().info("  Container components:")

    components
    |> Enum.filter(fn {_, c} -> c.category == :container end)
    |> Enum.sort_by(fn {name, _} -> name end)
    |> Enum.each(fn {name, comp} ->
      props = Enum.take(comp.props, 5) |> Enum.map_join(", ", &"#{&1}")
      extra = if length(comp.props) > 5, do: "...", else: ""
      Mix.shell().info("    :#{name} — #{comp.doc} (#{props}#{extra})")
    end)

    Mix.shell().info("\n  Leaf components:")

    components
    |> Enum.filter(fn {_, c} -> c.category == :leaf end)
    |> Enum.sort_by(fn {name, _} -> name end)
    |> Enum.each(fn {name, comp} ->
      props = Enum.take(comp.props, 5) |> Enum.map_join(", ", &"#{&1}")
      extra = if length(comp.props) > 5, do: "...", else: ""
      Mix.shell().info("    :#{name} — #{comp.doc} (#{props}#{extra})")
    end)

    Mix.shell().info("")
  end

  # ── Screen module discovery ──────────────────────────────────────────────────

  defp find_dala_screens do
    # Find all loaded modules that use Dala.Spark.Dsl
    :code.all_loaded()
    |> Enum.map(fn {mod, _} -> mod end)
    |> Enum.filter(fn mod ->
      Code.ensure_loaded?(mod) and
        function_exported?(mod, :__spark_dsl__, 0)
    end)
    |> Enum.sort()
  end
end
