defmodule CodeGenTest do
  use ExUnit.Case
  doctest CodeGen

  test "the right code is generated" do
    assert CodeGenExample.f1(1) == 8
  end

  test "end to end" do
    src = "test/fixtures/immutable/code_gen_example.ex"
    dst = "test/fixtures/mutable/code_gen_example_sandbox.ex"

    try do
      File.cp!(src, dst)
      replace_in_file(dst, "defmodule CodeGenExample do", "defmodule CodeGenExample_Sandbox do")

      # Compile the new file
      Kernel.ParallelCompiler.compile([dst])

      # Add some indirections to avoid warnings
      target_module = CodeGenExample_Sandbox
      target_module.__code_gen_dump_source__("f1/1")

      assert File.read!(dst) =~ "def f1(x) do"
      assert File.read!(dst) =~ "x + @constant1"
    after
      File.rm!(dst)
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
