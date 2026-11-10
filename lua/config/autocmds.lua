-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
--
-- Add any additional autocmds here
-- with `vim.api.nvim_create_autocmd`
--
-- Or remove existing autocmds by their group name (which is prefixed with `lazyvim_` for the defaults)
-- e.g. vim.api.nvim_del_augroup_by_name("lazyvim_wrap_spell")

-- Datenbank-Leiste (dadbod-ui) vom Startbild aus geöffnet: Startbild durch
-- ein leeres Fenster ersetzen. dadbod-ui öffnet Abfragen nur in normalen
-- Fenstern, sonst bleibt das Startbild in der Mitte stehen.
-- Danach die Autokommandos des Startbilds entfernen: snacks räumt sie hier nicht
-- selbst weg, sonst meldet es beim Schliessen des Fensters "Invalid window id".
vim.api.nvim_create_autocmd("FileType", {
  pattern = "dbui",
  callback = function()
    for _, win in ipairs(vim.api.nvim_list_wins()) do
      if vim.bo[vim.api.nvim_win_get_buf(win)].filetype == "snacks_dashboard" then
        vim.api.nvim_win_call(win, function()
          vim.cmd("enew")
        end)
        pcall(vim.api.nvim_del_augroup_by_name, "snacks_dashboard")
      end
    end
  end,
})

-- Java: 4 Leerzeichen einrücken wie IntelliJ und die Java-Konventionen.
-- LazyVim stellt überall 2 ein, jdtls formatierte beim Speichern danach um
-- (ganze Datei geändert, in Teamprojekten mit IntelliJ ein riesiger Diff).
vim.api.nvim_create_autocmd("FileType", {
  pattern = "java",
  callback = function()
    vim.opt_local.shiftwidth = 4
    vim.opt_local.tabstop = 4
  end,
})

-- Java-Tests mit Maven statt mit dem Test-Runner von jdtls: Leertaste t m die
-- ganze Testklasse, Leertaste t M die Methode unter dem Cursor. Der Runner von
-- jdtls fand in AssertJ (assertj-core hat eine module-info.java) keine Tests
-- ("0 succeeded"), Maven schon. Baut nur das Modul der Datei und was es braucht
-- (-pl … -am), unten im Terminal. spotless.check.skip: Formatierung erst vor dem
-- PR prüfen, sonst bricht der Build bei jeder kleinen Änderung schon davor ab.
local function maven_test(nur_methode)
  local datei = vim.api.nvim_buf_get_name(0)
  local root = vim.fs.root(datei, { "mvnw" })
  local modul = vim.fs.root(datei, { "pom.xml" })
  if not root or not modul then
    return vim.notify("Kein Maven-Projekt mit ./mvnw gefunden", vim.log.levels.WARN)
  end
  local test = vim.fn.expand("%:t:r")
  if nur_methode then
    local node = vim.treesitter.get_node()
    while node and node:type() ~= "method_declaration" do
      node = node:parent()
    end
    local name = node and node:field("name")[1]
    if not name then
      return vim.notify("Cursor steht in keiner Methode", vim.log.levels.WARN)
    end
    test = test .. "#" .. vim.treesitter.get_node_text(name, 0)
  end
  local cmd = "./mvnw -q test -Dtest=" .. test .. " -Dsurefire.failIfNoSpecifiedTests=false -Dspotless.check.skip=true"
  if modul ~= root then
    cmd = cmd .. " -pl " .. vim.fs.relpath(root, modul) .. " -am"
  end
  -- -q zeigt bei grünen Tests nichts an, darum am Schluss selbst melden
  cmd = cmd .. ' && echo "✓ grün: ' .. test .. '" || echo "✗ rot oder Fehler: ' .. test .. '"'
  vim.cmd("silent! wall")
  Snacks.terminal.open(cmd, { cwd = root, interactive = false, win = { position = "bottom", height = 0.35 } })
end

-- Projekte mit Spotless (z. B. AssertJ): nvim formatiert dort Java-Dateien
-- beim Speichern nicht. jdtls formatierte sonst nach eigenen Regeln halbe
-- Dateien um (25 Zeilen Diff für ein geändertes Wort), Leertaste u f half nur
-- bis zum Neustart. Formatiert wird dort mit ./mvnw spotless:apply; Leertaste
-- u F schaltet es für eine Datei trotzdem ein. Nur Java: Markdown, TS usw.
-- formatiert nvim weiter. Erkannt am Plugin (Maven: groupId/artifactId,
-- Gradle: Plugin-ID), nicht am Wort «spotless», das auch in Kommentaren steht.
local spotless_projekt = {}
local function hat_spotless(root)
  if spotless_projekt[root] == nil then
    spotless_projekt[root] = false
    for _, name in ipairs({ "pom.xml", "build.gradle", "build.gradle.kts" }) do
      local datei = root .. "/" .. name
      if vim.fn.filereadable(datei) == 1 then
        local inhalt = table.concat(vim.fn.readfile(datei), "\n")
        if inhalt:find("com.diffplug.spotless", 1, true) or inhalt:find("spotless-maven-plugin", 1, true) then
          spotless_projekt[root] = true
        end
      end
    end
  end
  return spotless_projekt[root]
end
vim.api.nvim_create_autocmd("FileType", {
  pattern = "java",
  callback = function(ev)
    local root = vim.fs.root(ev.buf, { "mvnw", "gradlew", ".git" })
    if root and hat_spotless(root) then
      vim.b[ev.buf].autoformat = false
    end
  end,
})

vim.api.nvim_create_autocmd("FileType", {
  pattern = "java",
  callback = function(ev)
    vim.keymap.set("n", "<leader>tm", function()
      maven_test(false)
    end, { buffer = ev.buf, desc = "Test-Klasse mit Maven" })
    vim.keymap.set("n", "<leader>tM", function()
      maven_test(true)
    end, { buffer = ev.buf, desc = "Test-Methode mit Maven" })
  end,
})

-- Java: neue, leere Datei mit package und Klasse füllen (wie IntelliJ/VS Code).
-- Das package kommt aus dem Pfad nach src/<main|test>/java/, der Klassenname aus
-- dem Dateinamen. Der snacks-Explorer meldet neue Dateien nicht an jdtls
-- (kein workspace/didCreateFiles), deshalb hier selbst.
vim.api.nvim_create_autocmd({ "BufNewFile", "BufReadPost" }, {
  pattern = "*.java",
  callback = function(ev)
    local zeilen = vim.api.nvim_buf_get_lines(ev.buf, 0, -1, false)
    if #zeilen > 1 or (zeilen[1] or "") ~= "" then
      return
    end
    local pfad = vim.api.nvim_buf_get_name(ev.buf)
    local klasse = vim.fn.fnamemodify(pfad, ":t:r")
    local ordner = pfad:match("/src/%w+/java/(.+)/[^/]+%.java$")
    local text = {}
    if ordner then
      vim.list_extend(text, { "package " .. ordner:gsub("/", ".") .. ";", "" })
    end
    vim.list_extend(text, { "public class " .. klasse .. " {", "    ", "}" })
    vim.api.nvim_buf_set_lines(ev.buf, 0, -1, false, text)
    local win = vim.fn.bufwinid(ev.buf)
    if win ~= -1 then
      vim.api.nvim_win_set_cursor(win, { #text - 1, 4 })
    end
  end,
})

-- Trouble-Listen unten (Fehlerliste der Tests, Leertaste x x, …) immer 10 Zeilen
-- hoch. Kam eine zweite dazu, verteilte nvim den Platz neu: die neue bekam 18–20
-- Zeilen und behielt sie, für den Code blieb kaum Platz. Verzögert, weil Trouble
-- das Fenster erst nach dem Öffnen fertig einrichtet. Listen rechts (Symbole)
-- sind nicht ganz breit und bleiben, wie sie sind.
vim.api.nvim_create_autocmd({ "FileType", "BufWinEnter" }, {
  callback = function(ev)
    if vim.bo[ev.buf].filetype ~= "trouble" then
      return
    end
    vim.defer_fn(function()
      for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
        if
          vim.w[win].trouble
          and vim.api.nvim_win_get_config(win).relative == ""
          and vim.api.nvim_win_get_width(win) == vim.o.columns
        then
          vim.api.nvim_win_set_height(win, 10)
        end
      end
    end, 300)
  end,
})

-- Datei umbenennen im Explorer (r): snacks lässt jdtls die Klasse im Puffer
-- umbenennen, benennt dann aber die Datei auf der Platte mit dem alten Inhalt
-- um und wirft den geänderten Puffer weg (auch eigene ungespeicherte
-- Änderungen). Deshalb den Puffer vorher speichern: im rename-Callback von
-- Snacks.rename.on_rename_file (dokumentierte API), der läuft nach den
-- Änderungen von jdtls und vor dem Verschieben der Datei.
-- Mit Datei gestartet (nvim Datei.java) lädt LazyVim diese Datei, bevor
-- snacks bereit ist, dann erst bei VeryLazy anpassen.
local function snacks_rename_speichern()
  local original = Snacks.rename.on_rename_file
  if type(original) ~= "function" then
    vim.notify("Snacks.rename.on_rename_file fehlt: Umbenennen speichert vorher nicht", vim.log.levels.WARN)
    return
  end
  Snacks.rename.on_rename_file = function(from, to, rename)
    if not rename then
      return original(from, to)
    end
    return original(from, to, function(...)
      local buf = vim.fn.bufnr(vim.fn.fnamemodify(from, ":p"))
      if buf > 0 and vim.api.nvim_buf_is_loaded(buf) and vim.bo[buf].modified then
        vim.api.nvim_buf_call(buf, function()
          vim.cmd("silent noautocmd write")
        end)
      end
      return rename(...)
    end)
  end
end
if _G.Snacks then
  snacks_rename_speichern()
else
  vim.api.nvim_create_autocmd("User", { pattern = "VeryLazy", once = true, callback = snacks_rename_speichern })
end
