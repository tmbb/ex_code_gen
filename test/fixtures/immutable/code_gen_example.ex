defmodule CodeGenExample do
  use CodeGen,
    module: CodeGenTemplate,
    options: [
      c1: 7
    ]
end
