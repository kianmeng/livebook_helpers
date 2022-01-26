defmodule LivebookHelpers do
  @moduledoc """
  Documentation for `LivebookHelpers`.
  """

  @doc """
  Takes a module and a path to a file, creates a livebook from the moduledocs in the given
  module. The `.livemd` extension is automatically added.

  This function will take a module and turn the module doc found there into a livebook.
  This make it really easy to create one set of information and have it be represented
  in different formats. For example you can write a README, use it as the moduledoc then
  run this function to spit out a livebook with all the same info.

  Below is a summary of what we do to create the Livebook:

  * The module is used as the title for the Livebook.
  * Each function's @doc is put under a section with the function's name and arity.
  * doctests become (formatted) elixir cells
  * The magic line to make github render livebooks as markdown is added.
  *
  """
  def livebook_from_module(module, livebook_path) do
    File.write(Path.expand(livebook_path <> ".livemd"), livebook_string(module))
  end

  def livebook_string(module) do
    {:docs_v1, _, :elixir, _, %{"en" => module_doc}, _, function_docs} = Code.fetch_docs(module)

    start_of_page = """
    <!-- vim: syntax=markdown -->

    # #{inspect(module)}

    #{parse_module_doc(module_doc)}\
    """

    Enum.reduce(function_docs, start_of_page, fn
      {{:function, function_name, arity}, _, [_], %{"en" => doc}, _meta}, acc ->
        acc <> "## #{function_name}/#{arity}\n\n" <> elixir_cells(doc)
    end)
  end

  def parse_module_doc(module_doc) do
    module_doc
    |> String.split("\n", trim: true)
    |> parse_elixir_cells({"", ""})
  end

  def elixir_cells(doc) do
    doc
    |> String.split("\n", trim: true)
    |> parse_elixir_cells({"", ""})
  end

  def parse_elixir_cells([], {acc, _}), do: acc

  def parse_elixir_cells(["    ...>" <> _code_sample | _rest], {_acc, ""}) do
    raise "Parsing error - missing the begining iex> of the doc test"
  end

  # We need to collect the elixir cell so we can format it.
  def parse_elixir_cells(["    ...>" <> code_sample | rest], {acc, current_elixir_cell}) do
    parse_elixir_cells(rest, {acc, current_elixir_cell <> "#{code_sample}\n"})
  end

  def parse_elixir_cells(["    iex>" <> code_sample | rest], {acc, ""}) do
    parse_elixir_cells(rest, {acc, "#{code_sample}\n"})
  end

  def parse_elixir_cells(["    iex>" <> _code_sample | _rest], {_acc, _}) do
    raise "Parsing error - You can't have a code block inside a code block"
  end

  def parse_elixir_cells([line | rest], {acc, ""}) do
    parse_elixir_cells(rest, {acc <> "#{line}\n", ""})
  end

  # Here we are one line after the ...> which means we are on the last line of a doctest.
  # This is the output and so can be ignored because Livebook will output it when you run
  # the cell. But it means we have collected all of the lines and so can format the cell
  # and save it.
  def parse_elixir_cells([_line | rest], {acc, current_elixir_cell}) do
    elixir_cell = """

    ```elixir
    #{Code.format_string!(current_elixir_cell)}
    ```

    """

    parse_elixir_cells(rest, {acc <> elixir_cell, ""})
  end
end
