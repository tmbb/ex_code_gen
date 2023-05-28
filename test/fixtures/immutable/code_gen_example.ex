defmodule CodeGenExample do
  @moduledoc false

  use CodeGen,
    module: CodeGenTemplate,
    options: [
      c1: 7
    ]
end
