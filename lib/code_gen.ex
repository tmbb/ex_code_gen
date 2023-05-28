defmodule CodeGen do
  @moduledoc """
  Documentation for `CodeGen`.

  ## Examples

      use CodeGen,
        module: TemplateModule,
        options: [
          a: 1,
          b: :x,
          c: "abc"
        ]
  """

  @doc """
  Define a named code block for code generation.

  This macro simply returns its contents
  such that the source of the expressions inside the block
  can be dumped by the user into the host's module file.
  """
  defmacro block(block_name, do: body) do
    body_without_special_module_attributes = remove_special_module_attributes(body)
    body_without_problematic_hygiene = remove_hygiene(body_without_special_module_attributes, __CALLER__)
    processed_body = body_without_problematic_hygiene

    original_code = quoted_to_pretty_string(body)
    postprocessed_code = postprocess_original_code(original_code)

    code_to_inject =
      postprocessed_code
      |> Code.format_string!()
      |> IO.iodata_to_binary()

    quote do
      # Append the new code block to the list of code blocs we already have
      @__code_gen_blocks__ {unquote(block_name), unquote(code_to_inject)}

      # Add the processed body to the module's AST
      unquote(processed_body)
    end
  end

  defp is_code_gen_comment(ast) do
    case ast do
      # @comment__ "" is a comment
      {:@, _meta1, [{:comment__, _meta2, [text]}]} when is_binary(text) ->
        true

      # @new_line_after_comment__ is a blank line that follows a comment
      {:@, _meta1, [{:newline_after_comment__, _meta2, atom}]} when is_atom(atom) ->
        true

      _other ->
        false
    end
  end

  defp remove_special_module_attributes(ast) do
    Macro.prewalk(ast, fn
      {fun, meta, args} when is_list(args) ->
        filtered_args = Enum.reject(args, &is_code_gen_comment/1)
        {fun, meta, filtered_args}

      other ->
        other
    end)
  end

  defp unhygienize_meta(meta) do
    meta
    |> Keyword.delete(:context)
    |> Keyword.delete(:counter)
  end

  defp remove_hygiene(ast, _env) do
    Macro.prewalk(ast, fn
      {:assigns, meta, module} when is_atom(module) ->
        {:assigns, unhygienize_meta(meta), nil}

      {:def, meta, args} ->
        {:def, unhygienize_meta(meta), args}

      other ->
        other
    end)
  end

  # Convert a quoted expression into codem, not into an iolist.
  # We might have to perform regex substitutions)
  defp quoted_to_pretty_string(ast) do
    unix_style_ast =
      Macro.prewalk(ast, fn
        # Make sure @doc "..." uses heredocs instead of simple quoted strings
        {:@, meta1, [{:doc, meta2, [binary]}]} when is_binary(binary) ->
          unix_style_binary = String.replace(binary, "\r\n", "\n")
          {:@, meta1, [{:doc, meta2, [unix_style_binary]}]}

        other ->
          other
      end)

    unix_style_ast
    |> Macro.to_string()
    |> prettify_code()
  end

  # Format code as a binary (not as an iolist.
  # We might have to perform regex substitution)
  defp prettify_code(code) do
    code
    |> Code.format_string!()
    |> IO.iodata_to_binary()
  end

  defp replace_line_comment(original_code) do
    Regex.replace(~r/@comment__\s"((.|\\")+)"/, original_code, fn _, text, _ ->
      unescaped_string_contents = Macro.unescape_string(text)
      # The string may contain more than one line
      # We must handle that case (elixir comments can contain only one line)
      lines = String.split(unescaped_string_contents, "\n")

      # Add the `#` character to all lines
      lines
      |> Enum.map(fn line -> "# #{line}" end)
      |> Enum.join("\n")
    end)
  end

  defp replace_doc(original_code) do
    Regex.replace(~r/( *)@doc "((.|\\")+)"/, original_code, fn _, spaces, text, _ ->
      # indent_level = String.length(spaces)
      unescaped_string_contents =
        text
        |> String.replace("\r\n", "\n")
        |> Macro.unescape_string()

      # The string may contain more than one line
      # We must handle that case (elixir comments can contain only one line)
      lines =
        unescaped_string_contents
        |> String.trim_trailing("\n")
        |> String.split("\n")
        |> Enum.map(fn line -> [spaces, line, "\n"] end)

      iolist = [spaces, "@doc \"\"\"\n", lines, spaces, "\"\"\""]

      IO.iodata_to_binary(iolist)
    end)
  end

  defp replace_multiline_comment(original_code) do
    Regex.replace(~r/@comment__\s"""((.|\\")+)"""/, original_code, fn _, text, _ ->
      unescaped_string_contents = Macro.unescape_string(text)
      # The string may contain more than one line
      # We must handle that case (elixir comments can contain only one line)
      lines = String.split(unescaped_string_contents, "\n")

      # Add the `#` character to all lines
      lines
      |> Enum.map(fn line -> "# #{line}" end)
      |> Enum.join("\n")
    end)
  end

  # Replace the special attributes by comments in the code - not in a quoted expression!
  defp postprocess_original_code(original_code) do
    # Replace module attrributes by comments (NOTE: this expects strings in quotes!)
    code_with_comments =
      original_code
      |> replace_doc()
      |> replace_multiline_comment()
      |> replace_line_comment()

    # Replace newlines after comments (no need for a regex, it's just a static string)
    code_with_comments_and_newlines =
      String.replace(code_with_comments, "@newline_after_comment__\n", "\n\n")

    code_with_comments_and_newlines
  end

  @doc false
  def inject_before_final_end(file_path, content_to_inject) do
    file = File.read!(file_path)

    if String.contains?(file, content_to_inject) do
      :ok
    else
      Mix.shell().info([:green, "* injecting ", :reset, Path.relative_to_cwd(file_path)])

      content =
        file
        |> String.trim_trailing()
        |> String.trim_trailing("end")
        |> Kernel.<>("\n" <> content_to_inject)
        |> Kernel.<>("\nend\n")

      formatted_content = Code.format_string!(content) |> IO.iodata_to_binary()

      File.write!(file_path, formatted_content)
    end
  end

  @doc false
  def _show_block(name, block) do
    block_lines = String.split(block, "\n")
    iodata = [
        "┌───────────────────────────────────────────────────────\n",
        ["│ Block: ", name, "\n"],
        "├───────────────────────────────────────────────────────\n",
        for line <- block_lines do
          ["│ ", line, "\n"]
        end,
        "└───────────────────────────────────────────────────────\n",
      ]

    IO.iodata_to_binary(iodata)
  end

  @doc false
  def _show_blocks(blocks) do
    iodata =
      for {name, block} <- blocks do
        _show_block(name, block)
      end

    IO.iodata_to_binary(iodata)
  end

  @doc """
  Displays the generated blocks
  """
  def show_blocks(module), do: module.__code_gen_info__(:show_blocks)


  @doc """
  Displays the generated blocks
  """
  def show_block(module, name), do: module.__code_gen_info__({:show_block, name})

  @doc """
  Get the names of the generated blocks.
  """
  def block_names(module), do: module.__code_gen_info__(:block_names)

  @doc """
  Returns the generated blocks as a list of pairs of the form `{name, code}`,
  where code is the binary representation of the code.
  """
  def blocks(module), do: module.__code_gen_info__(:blocks)

  @doc """
  Dumps the source code of a generated block into the module's file.
  The new code is added to the end of the module (just before the closing `end` tag).
  """
  def dump_source(module, block_name), do: module.__code_gen_dump_source__(block_name)

  defmacro __before_compile__(env) do
    quote do
      @doc false
      def __code_gen_info__(:blocks), do: Enum.reverse(@__code_gen_blocks__)

      def __code_gen_info__(:file), do: unquote(env.file)

      def __code_gen_info__(:show_blocks) do
        blocks = __code_gen_info__(:blocks)
        binary = CodeGen._show_blocks(blocks)
        IO.puts(binary)
      end

      def __code_gen_info__({:show_block, block_name}) do
        blocks = __code_gen_info__(:blocks)

        case Enum.find(blocks, fn {k, v} -> k == block_name end) do
          {block_name, code_to_inject} ->
            binary = CodeGen._show_block(block_name, code_to_inject)
            IO.puts(binary)

          nil ->
            raise "Ooops, block does not exist"
        end
      end

      def __code_gen_info__(:block_names) do
        for {block_name, _body} <- __code_gen_info__(:blocks), do: block_name
      end

      @doc false
      def __code_gen_dump_source__(block_name) do
        blocks = __code_gen_info__(:blocks)

        case Enum.find(blocks, fn {k, v} -> k == block_name end) do
          {_block_name, code_to_inject} ->
            path = __code_gen_info__(:file)
            CodeGen.inject_before_final_end(path, code_to_inject)

          nil ->
            raise "Ooops, block does not exist"
        end
      end

      defoverridable __code_gen_info__: 1,
                     __code_gen_dump_source__: 1
    end
  end

  defmacro __using__(opts) do
    module_ast = Keyword.fetch!(opts, :module)
    options = Keyword.get(opts, :options, [])

    quote do
      Module.register_attribute(__MODULE__, :__code_gen_blocks__, accumulate: true)
      require CodeGen
      @before_compile CodeGen

      # Require the module and run the macro to generate the AST
      require unquote(module_ast)
      unquote(module_ast).__code_gen__(unquote(options))
    end
  end
end
