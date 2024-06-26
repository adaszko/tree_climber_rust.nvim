Implements specialized logic for visual-selecting Rust code syntax tree nodes stopping by at more places than
any language-agnostic plugin can.  Why would want to do that?  It speeds up frequent editing scenarios by
requiring fewer steps to select the interesting bits. It lifts your editing routines up a semantic level from
"visually select this word and the trailing comma" to "visually select this function argument".

[nvim-treesitter](https://github.com/nvim-treesitter/nvim-treesitter#incremental-selection) |  this plugin
:--------------:|:-------------------------:
![nvim-treesitter](https://raw.githubusercontent.com/adaszko/tree_climber_rust.nvim/demo/demo/treesitter.gif)  |  ![tree_climber_rust](https://raw.githubusercontent.com/adaszko/tree_climber_rust.nvim/demo/demo/tree_climber_rust.gif)

The demo illustrates selecting a tuple element but that's not all the pluging offers.  Analogous selection
behavior also works for any comma-separated syntax element, e.g. `vec![1, 2, 3]`, `<A, B, C>`, `f(1, 2, 3)`,
function parameters, etc.

# Setup

Instruct your favorite Neovim package manager to clone `adaszko/tree_climber_rust.nvim` from GitHub and then
hook it up to [rustaceanvim](https://github.com/mrcjkb/rustaceanvim) (which you should be using if you aren't
already):

```lua
vim.g.rustaceanvim = {
  server = {
    on_attach = function(client, bufnr)
      local opts = { noremap=true, silent=true }
      vim.api.nvim_buf_set_keymap(bufnr, 'n', 's', '<cmd>lua require("tree_climber_rust").init_selection()<CR>', opts)
      vim.api.nvim_buf_set_keymap(bufnr, 'x', 's', '<cmd>lua require("tree_climber_rust").select_incremental()<CR>', opts)
      vim.api.nvim_buf_set_keymap(bufnr, 'x', 'S', '<cmd>lua require("tree_climber_rust").select_previous()<CR>', opts)
    end,
  },
}
```

# Prior work

All of these below work well but do more coarse-grained jumps due to being language-agnostic and relying on
tree-sitter grammars to define jump points.

 * [tree-sitter's builtin incremental selection](https://github.com/nvim-treesitter/nvim-treesitter#incremental-selection)

 * [syntax-tree-surfer](https://github.com/ziontee113/syntax-tree-surfer) implements walking the syntax tree
   in all directions whereas this pluging only does walking upwards to keep cognitive load low while
   maximizing utility at the same time

 * [Helix's builtin `expand_selection`, `shrink_selection`, `select_prev_sibling`, `select_next_sibling`](https://docs.helix-editor.com/keymap.html)
    * Demo: [Navigating the syntax tree with helix](https://www.youtube.com/watch?v=8BikrCguI6M)

 * An alternative way to achieve similarish effects would be to define custom text objects via
   [nvim-treesitter-textobjects](https://github.com/nvim-treesitter/nvim-treesitter-textobjects#text-objects-select)
   custom [treesitter
   queries](https://github.com/nvim-treesitter/nvim-treesitter-textobjects/blob/23b820146956b3b681c19e10d3a8bc0cbd9a1d4c/queries/rust/textobjects.scm).
