-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here
vim.opt.timeoutlen = 200

-- Prettier nur, wenn das Projekt eine Prettier-Config hat (.prettierrc …).
-- Sonst schrieb es beim Speichern jede Datei auf seinen Stil um (doppelte
-- Anführungszeichen, Semikolons), die Schulprojekte (Vite) verwenden ' ohne ;.
vim.g.lazyvim_prettier_needs_config = true
