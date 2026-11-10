# nvim

Neovim configuration based on [LazyVim](https://github.com/LazyVim/LazyVim),
set up for Java (Maven, JUnit, debugging), TypeScript/React, SQL and Markdown.
Color scheme: Catppuccin Mocha with a transparent background.

## Installation (Fedora, Debian or Arch)

```bash
git clone https://github.com/amschibli/nvim.git ~/.config/nvim
~/.config/nvim/install.sh
```

Move an existing configuration out of the way first
(`mv ~/.config/nvim{,.bak}`, likewise `~/.local/share/nvim`,
`~/.local/state/nvim` and `~/.cache/nvim`). The repository can also be cloned
elsewhere; `install.sh` then links it to `~/.config/nvim`.

`install.sh` can be run repeatedly and skips whatever is already in place:

| Step | Fedora | Debian | Arch |
| --- | --- | --- | --- |
| Packages (sudo) | git, ripgrep, fd, gcc, make, unzip, curl, python3, wl-clipboard, Node + npm (if `node` is missing), Java 25, psql/mysql clients | the same plus `python3-venv` (for sqlfluff); Java 25, otherwise 21 | the same via pacman (`base-devel`, `jdk-openjdk`, `mariadb-clients`); runs `pacman -Syu`, which updates the whole system |
| Neovim 0.12+ | from Fedora | from GitHub into `~/.local/opt/nvim` (Debian ships 0.10) | from Arch |
| lazygit | from GitHub into `~/.local/bin` | same | from Arch |
| tree-sitter CLI 0.26.1+ | from Fedora | from GitHub into `~/.local/bin` | from Arch |
| Nerd Font | JetBrainsMono into `~/.local/share/fonts` (only if `fc-list` exists) | same | same |
| Config | `~/.config/nvim`, `~/.markdownlint-cli2.yaml` | same | same |
| Plugins, Mason, Treesitter | installed headless (`scripts/headless-setup.lua`, package list in `mason.txt`) | same | same |

Options: `--no-packages` (no sudo), `--no-tools` (plugins etc. are installed on
the first start instead), `--no-font`.

After the installation:

- Set the terminal font to "JetBrainsMono Nerd Font", otherwise icons show up
  as boxes.
- Debian: `~/.local/bin` is added to `PATH` at login only. Log out and back in,
  or run `source ~/.profile`.
- Check `:checkhealth` in Neovim.

Java for projects: if SDKMAN is installed, Neovim uses
`~/.sdkman/candidates/java/current` (see `lua/config/options.lua`), otherwise
the system Java. jdtls itself needs Java 21 or newer.

### Adding Mason packages

After adding an extra or a language server, update the list used by
`install.sh`:

```bash
ls ~/.local/share/nvim/mason/packages > ~/.config/nvim/mason.txt
```

### Testing the installation

Run `install.sh` in a fresh container (requires podman):

```bash
~/.config/nvim/test/container-test.sh fedora
~/.config/nvim/test/container-test.sh debian
~/.config/nvim/test/container-test.sh arch
```

The test opens a Java file, checks for errors and compares the installed Mason
packages with `mason.txt`. Add `-i` to get a shell in the container afterwards.

## Contents

| File | Purpose |
| --- | --- |
| `lazyvim.json` | LazyVim extras: Java, TypeScript, JSON, YAML, Markdown, SQL, Docker, Prettier, ESLint, DAP, tests, mini-hipatterns, mini-surround, neogen, Outline, Overseer, Treesitter context, REST (kulala) |
| `lua/config/options.lua` | `timeoutlen = 200`; Prettier only in projects with a Prettier config; `nvim <dir>` changes into that directory; Java from SDKMAN |
| `lua/config/keymaps.lua` | `jj` in insert mode = Escape |
| `lua/config/autocmds.lua` | SQL query under the cursor, Java helpers (see below), Trouble list height |
| `lua/plugins/java.lua` | jdtls: static import favorites (JUnit, Mockito, AssertJ …), rename class with the file, IntelliJ-style `toString()` |
| `lua/plugins/spring-boot.lua` | Spring Boot language server (spring-boot.nvim): completion in `application.properties`/`.yml`, `:SpringBoot` to find beans and endpoints; only in projects with a Spring Boot dependency |
| `lua/plugins/dap.lua` | debugger UI opens on breakpoints only, sidebar on the right, console for `main`, stopping a session also stops the program |
| `lua/plugins/dadbod.lua` | extra table queries in the database sidebar (schema with keys, foreign keys) |
| `lua/plugins/blink.lua` | completion: Tab accepts ("super-tab") |
| `lua/plugins/frontend.lua` | CSS parsers, cssls, html-lsp, cssmodules_ls (`gd` from `styles.x` into the `.module.css`) |
| `lua/plugins/bash.lua` | bash-language-server and ShellCheck (warnings in the editor); shfmt formats on save |
| `lua/plugins/colorscheme.lua` | Catppuccin Mocha, transparent |
| `lua/plugins/markdownlint.lua` | markdownlint with `.markdownlint-cli2.yaml` from this repository |
| `lua/plugins/disabled.lua` | noice.nvim disabled |
| `.markdownlint-cli2.yaml` | MD013 (line length) disabled |
| `lazy-lock.json` | pinned plugin versions |

## Java

- Indentation: 4 spaces, as in IntelliJ and the Java conventions.
- A new, empty `.java` file is filled with `package` and class declaration
  (package derived from the path below `src/main/java` or `src/test/java`).
- `<leader>tm` / `<leader>tM`: run the test class / test method with `./mvnw`
  in a terminal at the bottom.
- `<leader>tt` / `<leader>tr`: run tests through the debugger, failures are
  listed in Trouble afterwards.
- `<leader>dc`: run or continue; finds the `main` class of the current file.
- Projects using spotless (`pom.xml` / `build.gradle`) are not formatted on
  save; use `./mvnw spotless:apply`. `<leader>uF` re-enables formatting for a
  single buffer.

## Databases

Extra `lang.sql`: vim-dadbod with UI (dadbod-ui), completion for tables and
columns, sqlfluff as linter and formatter.

- `<leader>D` toggles the database sidebar (`:DBUIToggle`).
- Add a connection: press `A` in the sidebar and enter a URL, e.g.
  - PostgreSQL: `postgresql://user:password@localhost:5432/mydb`
  - MySQL: `mysql://user:password@localhost:3306/mydb`
- Connections are stored locally in `~/.local/share/nvim/dadbod_ui/`,
  **not** in this repository (passwords).
- `Ctrl + Enter` (or `<leader>Q`): run **only the query under the cursor**,
  even across many lines (like DataGrip). A query runs from its first character
  to the semicolon; semicolons in comments and strings are ignored. Also works
  inside `BEGIN … COMMIT` and with `SAVEPOINT`.
- `<leader>S`: run the whole file or the selected lines; results appear in a
  table below.
- `<leader>W`: save the query as a draft (name ending in `.sql`).
- Sidebar: `o` expands tables and columns, `R` refreshes, `?` lists all keys.

## Updating

- Plugins: `:Lazy update`, then commit `lazy-lock.json`.
- Pull changes on another machine: `git -C ~/.config/nvim pull`, then
  `:Lazy restore` in Neovim (plugins back to the versions in `lazy-lock.json`).
