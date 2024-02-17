A version of [treesitter's incremental
selection](https://github.com/nvim-treesitter/nvim-treesitter#incremental-selection) specialized for Rust
code.

# Setup

Assuming you're using [rustaceanvim](https://github.com/mrcjkb/rustaceanvim) for Rust support in Neovim:

```lua
vim.api.nvim_command('set runtimepath+=~/repos/tree-climber-rust.nvim')
tree_climber_rust = require('tree-climber-rust')

vim.g.rustaceanvim = {
  server = {
    on_attach = function(client, bufnr)
      local opts = { noremap=true, silent=true }
      vim.api.nvim_buf_set_keymap(bufnr, 'n', 's', '<cmd>lua tree_climber_rust.init_selection()<CR>', opts)
      vim.api.nvim_buf_set_keymap(bufnr, 'x', 's', '<cmd>lua tree_climber_rust.select_incremental()<CR>', opts)
      vim.api.nvim_buf_set_keymap(bufnr, 'x', 'S', '<cmd>lua tree_climber_rust.select_previous()<CR>', opts)
    end,
    [...]
  },
}
```

# Development

Quick hack to iterate fast.  Place this in your `.vimrc` (adjusting paths) to unit test on every write:

```vimrc
augroup tree_climber_rust_test_on_write
    autocmd!
    autocmd BufWritePost ~/repos/tree_climber_rust.nvim/lua/tree_climber_rust.lua lua package.loaded.tree_climber_rust = nil; require('tree_climber_rust').test()
augroup END
```
