# Future Language Features

**None of the features below is available in language 1.0.** They are listed so that notebooks written today avoid them and so
the names are held back. There is no promised date and no promised syntax.

## Reserved commands

These names are reserved now. They parse, and evaluating them gives the error ``` `name` is reserved for a future version; not
available in language 1.0```.

| Command | Intended meaning |
|---------|------------------|
| `factor` | factor a polynomial |
| `solve` | solve an equation, optionally for a symbol |
| `subs` | substitute values for symbols |
| `approx` | approximate an exact value numerically |
| `diff` | differentiate, optionally with respect to a symbol |
| `integrate` | integrate, optionally with respect to a symbol |

## Other ideas

- Comparison operators `<` `>` `<=` `>=` `!=`.
- Ranges over more than one variable, and a range variable other than `x`.
- A continuation character for a line that starts with an operator.
- A language version chosen per cell or per notebook.

## Not planned

- Implicit multiplication (`2x`, `3(x+1)`). Multiplication stays explicit so every input reads one way.
