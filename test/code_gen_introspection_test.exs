defmodule CodeGenIntrospectionTest do
  use ExUnit.Case
  doctest CodeGen

  import ExUnit.CaptureIO

  test "show_block - f1/1" do
    expected = """
      ┌───────────────────────────────────────────────────────
      │ Block: f1/1
      ├───────────────────────────────────────────────────────
      │ @constant1 7
      │ def f1(x) do
      │   x + @constant1
      │ end
      └───────────────────────────────────────────────────────
      """

    actual = capture_io(fn -> CodeGen.show_block(CodeGenExample, "f1/1") end)
    assert actual =~ expected
  end

  test "show_block - f2/1" do
    expected = """
      ┌───────────────────────────────────────────────────────
      │ Block: f2/1
      ├───────────────────────────────────────────────────────
      │ def f2(x) do
      │   x + 2
      │ end
      └───────────────────────────────────────────────────────
      """

    actual = capture_io(fn -> CodeGen.show_block(CodeGenExample, "f2/1") end)
    assert actual =~ expected
  end


  test "show_block - f3/1" do
    expected = """
      ┌───────────────────────────────────────────────────────
      │ Block: f3/1
      ├───────────────────────────────────────────────────────
      │ # This is a comment outside the function
      │ # This is a another comment outside the function
      │ # Yet another comment
      │\s
      │ def f3(x) do
      │   # this is a comment inside the function
      │   x + 3
      │ end
      └───────────────────────────────────────────────────────
      """

    actual = capture_io(fn -> CodeGen.show_block(CodeGenExample, "f3/1") end)
    assert actual =~ expected
  end

  test "shows all blocks" do
    # Capture each block individually
    actual_output_f1 = capture_io(fn -> CodeGen.show_block(CodeGenExample, "f1/1") end)
    actual_output_f2 = capture_io(fn -> CodeGen.show_block(CodeGenExample, "f2/1") end)
    actual_output_f3 = capture_io(fn -> CodeGen.show_block(CodeGenExample, "f3/1") end)

    # Capture all blocks, as shown by `show_blocks`
    actual_output_all = capture_io(fn -> CodeGen.show_blocks(CodeGenExample) end)

    # Confirm that all the above blocks are shown
    assert actual_output_all =~ String.trim(actual_output_f1)
    assert actual_output_all =~ String.trim(actual_output_f2)
    assert actual_output_all =~ String.trim(actual_output_f3)
  end

  test "CodeGen creates the correct number of blocks" do
    assert length(CodeGen.blocks(CodeGenExample)) == 3
  end

  test "blocks have the right names" do
    assert CodeGen.block_names(CodeGenExample) == ["f1/1", "f2/1", "f3/1"]
  end
end
