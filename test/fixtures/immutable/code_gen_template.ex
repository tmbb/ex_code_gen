defmodule CodeGenTemplate do
  def __code_gen__(opts) do
    c1 = Keyword.get(opts, :c1, 1)
    c2 = Keyword.get(opts, :c3, 2)
    c3 = Keyword.get(opts, :c3, 3)

    quote do
      # Define some code inside a block, which we'll be able
      # to dump into our own module if we want
      CodeGen.block "f1/1" do
        @constant1 unquote(c1)

        def f1(x) do
          x + @constant1
        end
      end

      # Anothe code block
      CodeGen.block "f2/1" do
        def f2(x), do: x + unquote(c2)
      end

      # This code block is more complex and has comments
      CodeGen.block "f3/1" do
        @comment__ "This is a comment outside the function"
        @comment__ "This is a another comment outside the function"
        @comment__ "Yet another comment"
        @newline_after_comment__
        def f3(x) do
          @comment__ "this is a comment inside the function"
          x + unquote(c3)
        end
      end

      # You can define functions outside a code block
      # if you don't want the user to be able to redefine the function.
      def another_function() do
        # ...
      end

      # We need to mark some functions as overridable so that we can actually
      # dump their source code into the module and things will work.
      # It's too hard for CodeGen to understand which functions are being generated
      # and generate this list on its own.
      defoverridable f1: 1, f2: 1, f3: 1
    end
  end
end
