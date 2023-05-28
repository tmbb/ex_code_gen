defmodule CodeGenTest do
  use ExUnit.Case
  doctest CodeGen

  test "CodeGen generates the the right code according to options" do
    assert CodeGenExample.f1(1) == 8
  end

  test "end to end" do
    src = "test/fixtures/immutable/code_gen_example.ex"
    dst = "test/fixtures/mutable/code_gen_example_sandbox.ex"

    try do
      File.cp!(src, dst)
      replace_in_file(dst, "defmodule CodeGenExample do", "defmodule CodeGenExample_Sandbox do")

      # The file doesn't contain the generated code
      refute File.read!(dst) =~ "def f1(x) do"
      refute File.read!(dst) =~ "x + @constant1"

      # Compile the new file
      Kernel.ParallelCompiler.compile([dst])

      CodeGen.dump_source(CodeGenExample_Sandbox, "f1/1")

      # The file now contains the generated source code
      assert File.read!(dst) =~ "def f1(x) do"
      assert File.read!(dst) =~ "x + @constant1"
    after
      # Clean up
      File.rm!(dst)
    end
  end

  test "the documentation module error exception exists" do
    assert_raise CodeGen.DocumentationOnlyError, fn ->
      raise CodeGen.DocumentationOnlyError, MyModule
    end
  end

  defp replace_in_file(path, to_replace, replacement) do
    new_contents =
      path
      |> File.read!()
      |> String.replace(to_replace, replacement)

    File.write!(path, new_contents)
  end
end
