-- Java-Dateien. Läuft bei jedem Setzen des Dateityps java (Neovim: after/ftplugin),
-- also nur Dinge, die man gefahrlos wiederholen kann.

local buf = vim.api.nvim_get_current_buf()
local projekt = require("java_projekt")

-- 4 Leerzeichen einrücken wie IntelliJ und die Java-Konventionen.
-- LazyVim stellt überall 2 ein, jdtls formatierte beim Speichern danach um
-- (ganze Datei geändert, in Teamprojekten mit IntelliJ ein riesiger Diff).
vim.opt_local.shiftwidth = 4
vim.opt_local.tabstop = 4

-- Hat das Projekt eine eigene Formatter-Datei (lua/java_projekt.lua), deren
-- Einrückung übernehmen: jdtls nimmt Tab/Leerzeichen und Breite vom Editor,
-- nicht aus der Datei. Eine .editorconfig setzt Neovim danach und gewinnt.
local formatter = projekt.formatter(vim.fs.root(buf, { "mvnw", "gradlew", "pom.xml", "build.gradle", ".git" }))
if formatter then
  vim.opt_local.expandtab = not formatter.tab
  if formatter.breite then
    vim.opt_local.shiftwidth = formatter.breite
    vim.opt_local.tabstop = formatter.breite
  end
end

-- Formatieren beim Speichern:
-- - Spotless im Projekt: gar nicht (lua/java_projekt.lua, ./mvnw spotless:apply)
-- - sonst nur die geänderten Zeilen statt der ganzen Datei
--   (projekt.geaenderte_formatieren). Dafür das Formatieren von LazyVim für
--   diesen Puffer aus. Leertaste u f (global aus) gilt weiterhin; Leertaste u F
--   schaltet das Formatieren der ganzen Datei durch LazyVim wieder ein.
vim.b[buf].autoformat = false
local root = vim.fs.root(buf, { "mvnw", "gradlew", ".git" })
local gruppe = vim.api.nvim_create_augroup("java_geaenderte_formatieren_" .. buf, { clear = true })
if not (root and projekt.hat_spotless(root)) then
  vim.api.nvim_create_autocmd("BufWritePre", {
    group = gruppe,
    buffer = buf,
    callback = function()
      if vim.g.autoformat == false or vim.b[buf].autoformat == true then
        return
      end
      projekt.geaenderte_formatieren(buf)
    end,
  })
end

-- Leertaste t m / t M: Testklasse / Testmethode mit Maven (lua/java_projekt.lua)
vim.keymap.set("n", "<leader>tm", function()
  projekt.maven_test(false)
end, { buffer = buf, desc = "Test-Klasse mit Maven" })
vim.keymap.set("n", "<leader>tM", function()
  projekt.maven_test(true)
end, { buffer = buf, desc = "Test-Methode mit Maven" })

-- Java: neue, leere Datei mit package und Klasse füllen (wie IntelliJ/VS Code).
-- Das package kommt aus dem Pfad nach src/<main|test>/java/, der Klassenname aus
-- dem Dateinamen. Der snacks-Explorer meldet neue Dateien nicht an jdtls
-- (kein workspace/didCreateFiles), deshalb hier selbst.
local function neue_datei_fuellen()
  -- Nur echte .java-Dateien: jdtls öffnet auch Klassen aus Bibliotheken
  -- (jdt://…), die beim Setzen des Dateityps noch leer sind.
  local pfad = vim.api.nvim_buf_get_name(buf)
  if vim.bo[buf].buftype ~= "" or not pfad:match("%.java$") then
    return
  end
  local zeilen = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  if #zeilen > 1 or (zeilen[1] or "") ~= "" then
    return
  end
  local klasse = vim.fn.fnamemodify(pfad, ":t:r")
  local ordner = pfad:match("/src/%w+/java/(.+)/[^/]+%.java$")
  local text = {}
  if ordner then
    vim.list_extend(text, { "package " .. ordner:gsub("/", ".") .. ";", "" })
  end
  vim.list_extend(text, { "public class " .. klasse .. " {", "    ", "}" })
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, text)
  local win = vim.fn.bufwinid(buf)
  if win ~= -1 then
    vim.api.nvim_win_set_cursor(win, { #text - 1, 4 })
  end
end
neue_datei_fuellen()
