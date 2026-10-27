# nvim

Meine Neovim-Konfiguration auf Basis von [LazyVim](https://github.com/LazyVim/LazyVim),
Farbschema Catppuccin Mocha (transparent).

## Installation auf einem neuen PC (Fedora)

### 1. Pakete

```bash
sudo dnf install neovim git ripgrep fd-find gcc make unzip curl \
    tree-sitter-cli lazygit nodejs22 nodejs22-npm java-25-openjdk-devel
```

| Paket | Wofür |
| --- | --- |
| `neovim` | Neovim 0.11 oder neuer (getestet mit 0.12.6) |
| `git` | lazy.nvim lädt die Plugins mit Git |
| `ripgrep`, `fd-find` | Suche in Dateien und nach Dateinamen |
| `gcc`, `make`, `tree-sitter-cli` | Treesitter-Parser (Syntax) bauen |
| `unzip`, `curl` | Mason lädt damit Language-Server herunter |
| `lazygit` | Git-Oberfläche (`<leader>gg`) |
| `nodejs22`, `nodejs22-npm` | TypeScript, Prettier, ESLint, markdownlint |
| `java-25-openjdk-devel` | Java-Extra: jdtls braucht Java 21 oder neuer |

Andere Distribution: gleiche Programme, Paketnamen können abweichen.

### 2. Nerd Font

Ohne Nerd Font erscheinen statt Symbolen Kästchen. Nicht in Fedora enthalten:

```bash
mkdir -p ~/.local/share/fonts/JetBrainsMono
cd ~/.local/share/fonts/JetBrainsMono
curl -LO https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.tar.xz
tar xf JetBrainsMono.tar.xz && rm JetBrainsMono.tar.xz
fc-cache -f
```

Danach im Terminal die Schrift „JetBrainsMono Nerd Font“ einstellen (foot: `font=` in `foot.ini`).

### 3. Config holen

Vorhandene Config vorher wegschieben:

```bash
mv ~/.config/nvim{,.bak}
mv ~/.local/share/nvim{,.bak}
mv ~/.local/state/nvim{,.bak}
mv ~/.cache/nvim{,.bak}
```

Dann klonen (SSH-Alias `github-privat` = Konto amschibli, siehe `~/.ssh/config`):

```bash
git clone git@github-privat:amschibli/nvim.git ~/.config/nvim
```

Ohne SSH-Alias: `git clone git@github.com:amschibli/nvim.git ~/.config/nvim`.

markdownlint auch ausserhalb von Neovim mit denselben Regeln (optional):

```bash
ln -s ~/.config/nvim/.markdownlint-cli2.yaml ~/.markdownlint-cli2.yaml
```

### 4. Erster Start

```bash
nvim
```

- lazy.nvim installiert alle Plugins in den Versionen aus `lazy-lock.json`
- Mason installiert danach die Language-Server und Werkzeuge (jdtls, TypeScript, ESLint, Prettier, markdownlint …)
- Braucht Internet und ein paar Minuten. Fortschritt: `:Lazy` bzw. `:Mason`
- Danach Neovim einmal neu starten

### 5. Prüfen

```vim
:checkhealth
```

Rote Meldungen zeigen, was noch fehlt (meist ein Programm aus Schritt 1).

## Was drin ist

| Datei | Inhalt |
| --- | --- |
| `lazyvim.json` | aktive LazyVim-Extras: Java, TypeScript, JSON, Markdown, Prettier, ESLint, Debugger (DAP), Tests, mini-hipatterns |
| `lua/config/options.lua` | `timeoutlen = 200` |
| `lua/config/keymaps.lua` | `jj` im Einfügemodus = Escape |
| `lua/plugins/colorscheme.lua` | Catppuccin Mocha, transparenter Hintergrund |
| `lua/plugins/disabled.lua` | noice.nvim aus |
| `lua/plugins/markdownlint.lua` | markdownlint mit `.markdownlint-cli2.yaml` aus diesem Repo |
| `.markdownlint-cli2.yaml` | MD013 (maximale Zeilenlänge) aus |
| `lazy-lock.json` | genaue Plugin-Versionen |

## Aktualisieren

- Plugins: `:Lazy update`, danach `lazy-lock.json` committen
- Änderungen hochladen: `cd ~/.config/nvim && git add -A && git commit -m "…" && git push`
- Auf einem anderen PC holen: `cd ~/.config/nvim && git pull`, dann in Neovim `:Lazy restore` (Plugins auf die Versionen aus `lazy-lock.json`)
