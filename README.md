# nvim

Meine Neovim-Konfiguration auf Basis von [LazyVim](https://github.com/LazyVim/LazyVim),
Farbschema Catppuccin Mocha (transparent).

## Installation (Fedora oder Debian)

```bash
git clone git@github.com:amschibli/nvim.git ~/.config/nvim
~/.config/nvim/install.sh
```

Mit SSH-Alias: `git clone git@github-privat:amschibli/nvim.git ~/.config/nvim`.
Eine vorhandene Config vorher wegschieben (`mv ~/.config/nvim{,.bak}`, ebenso
`~/.local/share/nvim`, `~/.local/state/nvim`, `~/.cache/nvim`).

`install.sh` kann mehrmals laufen und überspringt, was schon da ist:

| Schritt | Fedora | Debian |
| --- | --- | --- |
| Pakete (sudo) | git, ripgrep, fd, gcc, make, unzip, curl, python3, wl-clipboard, Node + npm (falls kein `node`), Java 25, psql/mysql | dasselbe, dazu `python3-venv` (sqlfluff); Java 25, sonst 21 |
| Neovim 0.12+ | aus Fedora | von GitHub nach `~/.local/opt/nvim` (Debian hat 0.10) |
| lazygit | von GitHub nach `~/.local/bin` | gleich |
| tree-sitter-CLI 0.26.1+ | aus Fedora | von GitHub nach `~/.local/bin` |
| Nerd Font | JetBrainsMono nach `~/.local/share/fonts` (nur mit `fc-list`) | gleich |
| Config | `~/.config/nvim` (Symlink, falls woanders geklont), `~/.markdownlint-cli2.yaml` | gleich |
| Plugins, Mason, Treesitter | headless vorinstalliert (`scripts/headless-setup.lua`, Liste in `mason.txt`) | gleich |

Optionen: `--no-packages` (kein sudo), `--no-tools` (Plugins usw. erst beim ersten
Start), `--no-font`. Danach im Terminal die Schrift «JetBrainsMono Nerd Font»
einstellen und `:checkhealth` ansehen.

Java für eigene Projekte: Ist SDKMAN installiert, nimmt Neovim dessen
`~/.sdkman/candidates/java/current` (siehe `lua/config/options.lua`), sonst das
Java aus dem System.

### Neue Mason-Pakete

Wer ein Extra oder Language-Server dazunimmt, aktualisiert die Liste für
`install.sh`:

```bash
ls ~/.local/share/nvim/mason/packages > ~/.config/nvim/mason.txt
```

### Testen

`install.sh` in einem frischen Container ausprobieren (braucht podman):

```bash
~/.config/nvim/test/container-test.sh fedora
~/.config/nvim/test/container-test.sh debian
```

Mit `-i` am Ende bleibt man danach in einer Shell im Container und kann `nvim`
ausprobieren.

## Was drin ist

| Datei | Inhalt |
| --- | --- |
| `lazyvim.json` | aktive LazyVim-Extras: Java, TypeScript, JSON, Markdown, SQL, Prettier, ESLint, Debugger (DAP), Tests, mini-hipatterns, mini-surround, neogen (JavaDoc), Outline, Overseer (Aufgaben), Treesitter-Kontext, REST (kulala) |
| `lua/config/options.lua` | `timeoutlen = 200` |
| `lua/config/keymaps.lua` | `jj` im Einfügemodus = Escape |
| `lua/config/autocmds.lua` | SQL: Abfrage unter dem Cursor ausführen, Startbild weg beim Öffnen der Datenbank-Leiste |
| `lua/plugins/colorscheme.lua` | Catppuccin Mocha, transparenter Hintergrund |
| `lua/plugins/disabled.lua` | noice.nvim aus |
| `lua/plugins/markdownlint.lua` | markdownlint mit `.markdownlint-cli2.yaml` aus diesem Repo |
| `lua/plugins/frontend.lua` | CSS-Parser, cssls (CSS), html-lsp, cssmodules_ls (`g d` von `styles.x` in die `.module.css`) |
| `.markdownlint-cli2.yaml` | MD013 (maximale Zeilenlänge) aus |
| `lazy-lock.json` | genaue Plugin-Versionen |

## Datenbanken (statt DataGrip)

Extra `lang.sql`: vim-dadbod mit Oberfläche (dadbod-ui), Vervollständigung von Tabellen und Spalten, sqlfluff als Linter und Formatierer.

- `<leader>D` öffnet und schliesst die Datenbank-Leiste (`:DBUIToggle`)
- Verbindung anlegen: in der Leiste `A`, dann die URL eingeben, z. B.
  - PostgreSQL: `postgresql://benutzer:passwort@localhost:5432/techflow`
  - MySQL: `mysql://benutzer:passwort@localhost:3306/datenbank`
- Verbindungen speichert dadbod-ui lokal in `~/.local/share/nvim/dadbod_ui/`, **nicht** im Repo (Passwörter)
- `Ctrl + Enter` (oder `<leader>Q`): **nur die Abfrage unter dem Cursor** ausführen, auch über viele Zeilen (wie DataGrip). Eigene Funktion in `lua/config/autocmds.lua`, findet die Abfrage mit Treesitter
- `<leader>S`: ganze Datei oder markierte Zeilen ausführen. Ergebnis als Tabelle darunter
- `<leader>W`: Entwurf speichern (Name mit `.sql`)
- Leiste: `o` öffnet Tabellen und Spalten, `R` lädt neu, `?` zeigt alle Tasten

## Aktualisieren

- Plugins: `:Lazy update`, danach `lazy-lock.json` committen
- Änderungen hochladen: `cd ~/.config/nvim && git add -A && git commit -m "…" && git push`
- Auf einem anderen PC holen: `cd ~/.config/nvim && git pull`, dann in Neovim `:Lazy restore` (Plugins auf die Versionen aus `lazy-lock.json`)
