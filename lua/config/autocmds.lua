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
        vim.notify("Kompiliere und suche main-Klassen …")
        client:request("java/buildWorkspace", false, function()
          vim.schedule(starten)
        end, ev.buf)
      end, { buffer = ev.buf, desc = "Run/Continue (main der Datei)" })
    end)
  end,
})
