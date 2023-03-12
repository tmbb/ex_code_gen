defmodule CodeGen do
  @moduledoc """
  Documentation for `CodeGen`.
  """

  defmacro block(block_name, do: body) do
    body_without_special_module_attributes = remove_special_module_attributes(body)

    original_code = quoted_to_pretty_string(body)
    code_with_comments_and_newlines = replace_special_module_attributes_by_comments(original_code)

    code_to_inject =
      code_with_comments_and_newlines
      |> Code.format_string!()
      |> IO.iodata_to_binary()

    quote do
      # Append the new code block to the list of code blocs we already have
      @__code_gen_blocks__ {unquote(block_name), unquote(code_to_inject)}

      # Add the processed body to the module's AST
      unquote(body_without_special_module_attributes)
    end
  end

  defp is_code_gen_comment(ast) do
    case ast do
      {:@, _meta1, [{:comment__, _meta2, [text]}]} when is_binary(text) ->
        true

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

  defp quoted_to_pretty_string(ast) do
    ast
    |> Macro.to_string()
    |> prettify_code()
  end

  defp prettify_code(code) do
    code
    |> Code.format_string!()
    |> IO.iodata_to_binary()
  end

  defp replace_special_module_attributes_by_comments(original_code) do
    code_with_comments =
      Regex.replace(~r/@comment__\s"((.|\\")+)"/, original_code, fn _, text, _ ->
        unescaped_string_contents = Macro.unescape_string(text)
        lines = String.split(unescaped_string_contents, "\n")

        lines
        |> Enum.map(fn line -> "# #{line}" end)
        |> Enum.join("\n")
      end)

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
  def show_blocks(blocks) do
    for {name, block} <- blocks do
      block_lines = String.split(block, "\n")
      IO.puts("┌────────────────────────────────────────────────────────")
      IO.puts(["│ Block: ", name])
      IO.puts("├───────────────────────────────────────────────────────")
      for line <- block_lines do
        IO.puts(["│ ", line])
      end
      IO.puts("└───────────────────────────────────────────────────────\n")
    end

    :ok
  end

  defmacro __before_compile__(env) do
    quote do
      def __code_gen_info__(:blocks), do: Enum.reverse(@__code_gen_blocks__)

      def __code_gen_info__(:file), do: unquote(env.file)

      def __code_gen_info__(:show_blocks) do
        blocks = __code_gen_info__(:blocks)
        CodeGen.show_blocks(blocks)
      end

      def __code_gen_info__(:block_names) do
        for {block_name, _body} <- __code_gen_info__(:blocks), do: block_name
      end

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

    {module, []} = Code.eval_quoted(module_ast)
    generated_code = module.__code_gen__(options)

    quote do
      Module.register_attribute(__MODULE__, :__code_gen_blocks__, accumulate: true)
      require CodeGen
      @before_compile CodeGen

      unquote(generated_code)
    end
  end
end
