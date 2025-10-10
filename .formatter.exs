# SPDX-FileCopyrightText: 2020 Zach Daniel
#
# SPDX-License-Identifier: MIT

# Used by "mix format"
spark_locals_without_parens = [args: 1, form: 1, form: 2]

[
  import_deps: [:ash, :phoenix],
  plugins: [Phoenix.LiveView.HTMLFormatter],
  inputs: ["{mix}.exs", "{config,lib,test}/**/*.{ex,exs,heex}"],
  locals_without_parens: spark_locals_without_parens,
  export: [
    locals_without_parens: spark_locals_without_parens
  ]
]
