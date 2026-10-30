-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here
vim.opt.timeoutlen = 200

-- Prettier nur, wenn das Projekt eine Prettier-Config hat (.prettierrc …).
-- Sonst schrieb es beim Speichern jede Datei auf seinen Stil um (doppelte
-- Anführungszeichen, Semikolons), die Schulprojekte (Vite) verwenden ' ohne ;.
vim.g.lazyvim_prettier_needs_config = true

-- nvim mit einem Ordner geöffnet (nvim swe2_problems-to-fix, oder Enter auf
-- einem Ordner in yazi): in diesen Ordner wechseln. Sonst blieb das
-- Arbeitsverzeichnis der Ordner darüber (SOE-2), und ein jdtls ohne gefundenes
-- Projekt las alle Projekte darin ein, ihre Fehler standen in der Liste.
if vim.fn.argc() == 1 and vim.fn.isdirectory(vim.fn.argv(0)) == 1 then
  vim.fn.chdir(vim.fn.argv(0))
end

-- Java aus SDKMAN, auch wenn nvim nicht aus einer bash mit .bashrc kommt (yazi,
-- Sway). Sonst fanden ./mvnw und das Terminal nur /usr/bin/java, das Fedora-
-- Paket java-25-openjdk-headless ohne javac und ohne ct.sym: Maven brach ab mit
-- "Releaseversion 17 nicht unterstützt" (Leertaste t m in AssertJ).
local sdkman_java = vim.fn.expand("~/.sdkman/candidates/java/current")
if (vim.env.JAVA_HOME or "") == "" and vim.fn.isdirectory(sdkman_java) == 1 then
  vim.env.JAVA_HOME = sdkman_java
  vim.env.PATH = sdkman_java .. "/bin:" .. vim.env.PATH
end
