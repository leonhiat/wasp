Here is the formal description of the Wasp language with a LaTeX document
containing the grammar, type system, and evaluation rules.

To view the PDF, you will need to generate it yourself (see below instructions).

## Which files to edit

Edit the document in `src/index.tex`. Add more packages (if needed) and set up
macros/commands in `src/_preamble.tex`. All document text should be in only
`index.text`.

## How to build

First, install tectonic: https://tectonic-typesetting.github.io/en-US/.
You do not need to install LaTeX.

To build the PDF, run `tectonic -X build` in this directory. The PDF will be
saved to `build/wasplang/wasplang.pdf`.
