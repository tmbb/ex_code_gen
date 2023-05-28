defmodule CodeGen.DocumentationOnlyError do
  @doc """
  An exception to be raised when the user tries to invoke a function
  in a module created for documentation purposes only.

  When documenting a module that supports CodeGen, the easiest way
  is often to `use CodeGen, ...` inside the module itself so that
  we get an ExDoc page documenting all functions provided by the module.
  However, we often don't want the user to use thar module directly,
  as there might be important customizations for which there isn't
  a good default.

  An example of a configuration option without a good default is
  a Gettext module for a Phoenix components library.
  Users will want to provide their own Gettext module so that
  the components can be internationalized correctly.

  This exception is useful if you want to provide a module for
  documentation purposes only and don't want the functions
  defined in that module to be used.

  ## Example

  The following code shows an example of how

      defmodule CrazyFrameworkComponents.CodeGen do
        @moduledoc false

        defmacro __code_gen__(options) do
          # Use this option to control wether functions will be usable or not
          documentation_only? = Keyword.get(options, :documentation_only?, false)

          raise_if_documentation_only =
            maybe_raise_not_implemented =
              if documentation_only? do
                # This module is documentation only! Raise an exception
                quote do
                  [raise(CodeGen.ModuleForDocumentationOnlyError, unquote(__CALLER__.module))]
                end
              else
                # Don't generate any code
                []
              end

          quote do
            CodeGen.block "my_component" do
              @doc \"""
              Docs for my component.
              \"""
              def my_component(assigns) do
                # Use `unquote_splicing` so that we can convert the empty list to "no code"
                unquote_splicing(raise_if_documentation_only)
                # Actual code here
              end
            end
          end
        end
      end

      defmodule CrazyFrameworkComponents do
        @doc \"""
        The functions in this module are only for documentation purposes.
        They will raise an error if called
        \"""

        # Make it so that users can `use CodeGen, module: CrazyFrameworkComponents`
        defmacro __code_gen__(options) do
          quote do
            require CrazyFrameworkComponents.CodeGen
            CrazyFrameworkComponents.CodeGen.__code_gen__(unquote(options))
          end
        end

        use
          module: CrazyFrameworkComponents.CodeGen,
          options: [
            # Generate functions which raise instead of returning the right value
            documentation_only?: true,
            # Other options
          ]
      end
  """

  defexception [:message]

  @impl true
  def exception(module) do
    message = """
    Function not available. This module is for documentation purposes only.
    Please build your own module using:

      defmodule YourApp.YourVersionOf#{inspect(module)} do
        use CodeGen,
          module: #{inspect(module)},
          options: [
            # your options
          ]
      end
    """

    %__MODULE__{message: message}
  end
end
