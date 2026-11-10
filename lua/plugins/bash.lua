-- Bash: Language Server und ShellCheck. bashls ruft ShellCheck selbst auf,
-- sobald es installiert ist. shfmt (Formatierung) bringt LazyVim schon mit.
return {
  {
    "neovim/nvim-lspconfig",
    opts = { servers = { bashls = {} } },
  },
  {
    "mason-org/mason.nvim",
    opts = { ensure_installed = { "shellcheck" } },
  },
}
