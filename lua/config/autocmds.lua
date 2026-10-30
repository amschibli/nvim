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

-- SQL: Abfrage unter dem Cursor ausführen (wie Ctrl+Enter in DataGrip).
-- Abfragen gehen vom ersten Zeichen Code bis zum Strichpunkt, egal wie viele
-- Zeilen. Markiert sie genau und lässt dadbod-ui die Auswahl ausführen.
-- Nicht über Treesitter: Der SQL-Parser macht aus BEGIN … ROLLBACK/COMMIT einen
-- einzigen Block und kennt SAVEPOINT nicht, darin fand Ctrl+Enter nichts.

-- Alle Abfragen als { anfang = { zeile, spalte }, ende = { zeile, spalte } }
-- (Zeile ab 1, Spalte ab 0, Ende = Strichpunkt). Ein ; in Kommentaren
-- (--, /* */) oder Texten ('…', "…", $$…$$) zählt nicht.
local function sql_abfragen(zeilen)
  local abfragen, anfang, letztes = {}, nil, nil
  local im -- offener Kommentar oder Text: "/*", "'", '"' oder "$tag$"
  for nr, zeile in ipairs(zeilen) do
    local i = 1
    while i <= #zeile do
      local c = zeile:sub(i, i)
      if im == "/*" then
        if zeile:sub(i, i + 1) == "*/" then
          im, i = nil, i + 1
        end
      elseif im == "'" or im == '"' then
        if c == im then
          im = nil
        end
        letztes = { nr, i - 1 }
      elseif im then
        if zeile:sub(i, i + #im - 1) == im then
          im, i = nil, i + #im - 1
        end
        letztes = { nr, i - 1 }
      elseif zeile:sub(i, i + 1) == "--" then
        break
      elseif zeile:sub(i, i + 1) == "/*" then
        im, i = "/*", i + 1
      elseif not c:match("%s") then
        anfang = anfang or { nr, i - 1 }
        letztes = { nr, i - 1 }
        if c == "'" or c == '"' then
          im = c
        elseif c == "$" and zeile:match("^%$[%w_]*%$", i) then
          im = zeile:match("^%$[%w_]*%$", i)
          i = i + #im - 1
        elseif c == ";" then
          table.insert(abfragen, { anfang = anfang, ende = letztes })
          anfang = nil
        end
      end
      i = i + 1
    end
  end
  if anfang then -- letzte Abfrage ohne Strichpunkt
    table.insert(abfragen, { anfang = anfang, ende = letztes })
  end
  return abfragen
end

local function sql_abfrage_unter_cursor()
  if vim.b.dbui_db_key_name == nil then
    vim.notify("Datei über die Datenbank-Leiste öffnen (<leader>D), sonst fehlt die Verbindung", vim.log.levels.WARN)
    return
  end
  local zeile = vim.api.nvim_win_get_cursor(0)[1]
  local anfang, ende
  for _, abfrage in ipairs(sql_abfragen(vim.api.nvim_buf_get_lines(0, 0, -1, false))) do
    if zeile >= abfrage.anfang[1] and zeile <= abfrage.ende[1] then
      anfang, ende = abfrage.anfang, abfrage.ende
      break
    end
  end
  if not anfang then
    vim.notify("Keine Abfrage unter dem Cursor", vim.log.levels.WARN)
    return
  end
  local cursor = vim.api.nvim_win_get_cursor(0)
  vim.api.nvim_buf_set_mark(0, "<", anfang[1], anfang[2], {})
  vim.api.nvim_buf_set_mark(0, ">", ende[1], ende[2], {})
  vim.cmd([[execute "normal gv\<Plug>(DBUI_ExecuteQuery)"]])
  vim.api.nvim_win_set_cursor(0, cursor)
end

vim.api.nvim_create_autocmd("FileType", {
  pattern = { "sql", "mysql", "plsql" },
  callback = function(ev)
    for _, taste in ipairs({ "<C-CR>", "<leader>Q" }) do
      vim.keymap.set("n", taste, sql_abfrage_unter_cursor, { buffer = ev.buf, desc = "Abfrage unter dem Cursor ausführen" })
    end
    -- Q allein spielt das letzte Makro ab. Kommt bei <leader>Q die Leertaste
    -- zu spät (timeoutlen 200 ms), landete so ein versehentlich aufgenommenes
    -- Makro im Text. In SQL-Dateien deshalb abgeschaltet.
    vim.keymap.set("n", "Q", "<Nop>", { buffer = ev.buf, desc = "Makro abspielen (in SQL aus)" })
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

-- Projekte mit eigenem Formatierer (spotless in pom.xml / build.gradle, z. B.
-- AssertJ): nvim formatiert dort beim Speichern nicht. jdtls formatierte sonst
-- nach eigenen Regeln halbe Dateien um (25 Zeilen Diff für ein geändertes
-- Wort), Leertaste u f half nur bis zum Neustart. Formatiert wird dort mit
-- ./mvnw spotless:apply; Leertaste u F schaltet es für eine Datei trotzdem ein.
local eigener_formatierer = {}
vim.api.nvim_create_autocmd({ "BufReadPost", "BufNewFile" }, {
  callback = function(ev)
    local root = vim.fs.root(ev.buf, { "mvnw", "gradlew", ".git" })
    if not root then
      return
    end
    if eigener_formatierer[root] == nil then
      eigener_formatierer[root] = false
      for _, name in ipairs({ "pom.xml", "build.gradle", "build.gradle.kts" }) do
        local datei = root .. "/" .. name
        if vim.fn.filereadable(datei) == 1 and vim.fn.match(vim.fn.readfile(datei), "spotless") >= 0 then
          eigener_formatierer[root] = true
        end
      end
    end
    if eigener_formatierer[root] then
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

-- Java-Tests (Leertaste t t / t r): danach unten die Fehlerliste (Trouble) mit
-- den roten Tests öffnen, sind alle grün, wieder schliessen. Der Fokus bleibt
-- im Code. Gleiche Tasten wie LazyVim (extras.lang.java), nur mit after_test;
-- vim.schedule, damit sie nach den LazyVim-Tasten gesetzt werden.
local function java_test_liste(items)
  local trouble = require("trouble")
  if items and #items > 0 then
    trouble.open({ mode = "qflist", focus = false })
    trouble.refresh({ mode = "qflist" })
  else
    trouble.close({ mode = "qflist" })
  end
end

vim.api.nvim_create_autocmd("LspAttach", {
  callback = function(ev)
    local client = vim.lsp.get_client_by_id(ev.data.client_id)
    if not client or client.name ~= "jdtls" then
      return
    end
    vim.schedule(function()
      -- jdtls hängt sich auch an kurzlebige Hilfspuffer, die dann schon weg sind
      if not vim.api.nvim_buf_is_valid(ev.buf) then
        return
      end
      local jdap = require("jdtls.dap")
      vim.keymap.set("n", "<leader>tt", function()
        jdap.test_class({ after_test = java_test_liste })
      end, { buffer = ev.buf, desc = "Run All Test" })
      vim.keymap.set("n", "<leader>tr", function()
        jdap.test_nearest_method({ after_test = java_test_liste })
      end, { buffer = ev.buf, desc = "Run Nearest Test" })
      -- Leertaste d c: main-Methode der aktuellen Datei direkt starten, ohne
      -- Auswahlliste. Die main-Klassen vorher neu suchen: LazyVim tut das nur
      -- beim Start von jdtls, neue Klassen fehlten sonst bis :JdtWipeDataAndRestart.
      -- Läuft schon ein Debug-Lauf: weiter wie gewohnt. Keine main in der Datei:
      -- Auswahlliste (z. B. Spring-App starten, Haltepunkt im Controller).
      vim.keymap.set("n", "<leader>dc", function()
        local dap = require("dap")
        if dap.session() then
          return dap.continue()
        end
        local paket
        for _, zeile in ipairs(vim.api.nvim_buf_get_lines(0, 0, 50, false)) do
          paket = zeile:match("^%s*package%s+([%w_%.]+)%s*;")
          if paket then
            break
          end
        end
        local klasse = vim.fn.expand("%:t:r")
        klasse = paket and (paket .. "." .. klasse) or klasse
        local function starten()
          jdap.setup_dap_main_class_configs({
            on_ready = vim.schedule_wrap(function()
              for _, config in ipairs(dap.configurations.java or {}) do
                if config.mainClass == klasse then
                  return dap.run(config)
                end
              end
              dap.continue()
            end),
          })
        end
        -- Vorher kompilieren: Eine eben gespeicherte neue Klasse gab sonst
        -- "Hauptklasse … konnte nicht gefunden werden". Fehler in anderen
        -- Dateien stören nicht, gestartet wird trotzdem.
        -- Altes Programm in der Konsole (z. B. eben mit Leertaste d t beendet)
        -- erst ganz fertig werden lassen, sonst bricht der Start ab mit
        -- "jobstart … requires unmodified buffer".
        for _, buf in ipairs(vim.api.nvim_list_bufs()) do
          local job = vim.bo[buf].filetype == "dapui_console" and vim.b[buf].terminal_job_id
          if job and vim.fn.jobwait({ job }, 0)[1] == -1 then
            vim.fn.jobstop(job)
            vim.fn.jobwait({ job }, 10000)
          end
        end
        vim.notify("Kompiliere und suche main-Klassen …")
        client:request("java/buildWorkspace", false, function()
          vim.schedule(starten)
        end, ev.buf)
      end, { buffer = ev.buf, desc = "Run/Continue (main der Datei)" })
    end)
  end,
})

-- Datei umbenennen im Explorer (r): snacks lässt jdtls die Klasse im Puffer
-- umbenennen, benennt dann aber die Datei auf der Platte mit dem alten Inhalt
-- um und wirft den geänderten Puffer weg (auch eigene ungespeicherte
-- Änderungen). Deshalb den Puffer vorher speichern.
-- Mit Datei gestartet (nvim Datei.java) lädt LazyVim diese Datei, bevor
-- snacks bereit ist, dann erst bei VeryLazy anpassen.
local function snacks_rename_speichern()
  local original = Snacks.rename._rename
  Snacks.rename._rename = function(from, to)
    local buf = vim.fn.bufnr(vim.fn.fnamemodify(from, ":p"))
    if buf > 0 and vim.api.nvim_buf_is_loaded(buf) and vim.bo[buf].modified then
      vim.api.nvim_buf_call(buf, function()
        vim.cmd("silent noautocmd write")
      end)
    end
    return original(from, to)
  end
end
if _G.Snacks then
  snacks_rename_speichern()
else
  vim.api.nvim_create_autocmd("User", { pattern = "VeryLazy", once = true, callback = snacks_rename_speichern })
end
