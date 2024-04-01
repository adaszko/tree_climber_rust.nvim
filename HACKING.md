Quick hack to iterate fast.  Place this in your `.vimrc` (adjusting paths) to reload and unit test on every
save of the pluging code:

```vimrc
set runtimepath+=~/repos/tree-climber-rust.nvim
augroup tree_climber_rust_test_on_write
    autocmd!
    autocmd BufWritePost ~/repos/tree_climber_rust.nvim/lua/tree_climber_rust.lua lua package.loaded.tree_climber_rust = nil; require('tree_climber_rust').test()
augroup END
```
