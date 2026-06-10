# Neovim Config

LazyVim-based Neovim config with local C++/rbuild customizations.

## Custom Commands

| Command | Description | Example |
| --- | --- | --- |
| `:Rbuild` | Run local `/Users/yimu/.vim/mac-tools/rbuild -f <current-file-relative-path>` and send output to quickfix. | `:Rbuild` |
| `:Rbuild <args>` | Append extra args after the current file path. | `:Rbuild --makefile --test` |
| `:RbuildStop` | Stop the currently running `Rbuild` job. | `:RbuildStop` |
| `:Grep <keyword>` | Search all directories with ripgrep, excluding `tags` files. Uses the word under cursor when `<keyword>` is omitted. | `:Grep AdInfo` |
| `:Grepa <keyword>` | Search `huichuan/ad_server_v2`, excluding `tags` files. | `:Grepa AdInfo` |
| `:Grept <keyword>` | Search `huichuan/trigger_server_v2`, excluding `tags` files. | `:Grept TriggerInfo` |
| `:Grepm <keyword>` | Search `huichuan/media_server`, excluding `tags` files. | `:Grepm MediaInfo` |
| `:Grepe <keyword>` | Search `huichuan/exchange_server`, excluding `tags` files. | `:Grepe ModuleRpc` |
| `:Grepp <keyword>` | Search all `.proto` files, excluding `tags` files. | `:Grepp CreativeInfo` |
| `:Grep1 <keyword>` | Search the current file's level-1 directory, excluding `tags` files. | `:Grep1 AdInfo` |
| `:Grep2 <keyword>` | Search the current file's level-2 directory, excluding `tags` files. | `:Grep2 AdInfo` |
| `:Grep3 <keyword>` | Search the current file's level-3 directory, excluding `tags` files. | `:Grep3 AdInfo` |
| `:Grep4 <keyword>` | Search the current file's level-4 directory, excluding `tags` files. | `:Grep4 AdInfo` |
| `:Grepp1 <keyword>` | Search `.proto` files in the current file's level-1 directory, excluding `tags` files. | `:Grepp1 AdInfo` |
| `:Grepp2 <keyword>` | Search `.proto` files in the current file's level-2 directory, excluding `tags` files. | `:Grepp2 AdInfo` |
| `:Grepp3 <keyword>` | Search `.proto` files in the current file's level-3 directory, excluding `tags` files. | `:Grepp3 AdInfo` |
| `:Grepp4 <keyword>` | Search `.proto` files in the current file's level-4 directory, excluding `tags` files. | `:Grepp4 AdInfo` |
| `:Gd` | Proto-aware definition jump. From C++, `*.pb.h` include lines open the matching `.proto`; proto-generated symbols search `message/enum/service` definitions in `.proto` files before falling back to LSP. | `:Gd` |

When the current buffer is `/Users/yimu/Work/wlyb/common/rta/rta_client/rta_client.cc`, `:Rbuild` runs:

```bash
/Users/yimu/.vim/mac-tools/rbuild -f common/rta/rta_client/rta_client.cc
```

`Rbuild` opens the quickfix window automatically. Compiler errors that match `file:line:column` or `file:line` formats become jumpable quickfix entries.

Useful quickfix commands:

| Command | Description |
| --- | --- |
| `:copen` | Open quickfix. |
| `:cclose` | Close quickfix. |
| `:cnext` | Jump to next error. |
| `:cprev` | Jump to previous error. |
| `:cc` | Jump to the current quickfix entry. |

## Custom Keymaps

| Key | Mode | Description |
| --- | --- | --- |
| `\g` | Normal | Search the symbol under cursor with the same ripgrep quickfix helper as `:Grep`, excluding `tags` files, scoped to the first two path components of the current file. |
| `<F5>` | Normal | Jump to next quickfix entry (`:cnext`). |
| `<F6>` | Normal | Jump to previous quickfix entry (`:cprev`). |

## UI

The top bufferline shows the real buffer id for each buffer. You can jump to one with `:buffer <id>`.

## C++ Support

C/C++ is configured through `clangd` in `lua/plugins/cpp.lua`.

Useful LazyVim defaults:

| Key | Description |
| --- | --- |
| `gd` | Go to definition. |
| `gr` | Find references. |
| `gI` | Go to implementation. |
| `K` | Show hover information. |

For best C++ navigation, keep `compile_commands.json` available in the project root or a parent directory that `clangd` can discover.
