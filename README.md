# nvim

Meine Neovim-Konfiguration auf Basis von [LazyVim](https://github.com/LazyVim/LazyVim).

Liegt unter `~/.config/nvim`.

| Datei | Inhalt |
| --- | --- |
| `lua/config/options.lua` | Optionen |
| `lua/config/keymaps.lua` | eigene Tasten |
| `lua/config/autocmds.lua` | Autocommands |
| `lua/plugins/` | Plugins: Farbschema, deaktivierte Plugins, markdownlint |
| `lazy-lock.json` | genaue Plugin-Versionen |

## Einrichten

```bash
git clone git@github-privat:amschibli/nvim.git ~/.config/nvim
nvim   # lazy.nvim installiert die Plugins beim ersten Start
```
