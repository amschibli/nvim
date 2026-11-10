-- SQL: Abfrage unter dem Cursor ausführen (wie Ctrl+Enter in DataGrip).
-- Abfragen gehen vom ersten Zeichen Code bis zum Strichpunkt, egal wie viele
-- Zeilen. Markiert sie genau und lässt dadbod-ui die Auswahl ausführen.
-- Nicht über Treesitter: Der SQL-Parser macht aus BEGIN … ROLLBACK/COMMIT einen
-- einzigen Block und kennt SAVEPOINT nicht, darin fand Ctrl+Enter nichts.

-- Alle Abfragen als { anfang = { zeile, spalte }, ende = { zeile, spalte } }
-- (Zeile ab 1, Spalte ab 0, Ende = Strichpunkt). Ein ; in Kommentaren
-- (--, /* */) oder Texten ('…', "…", $$…$$) zählt nicht.
--
-- Eingebunden über after/ftplugin/{sql,mysql,plsql}.lua, getestet mit
-- nvim -l test/sql_abfragen.lua

local M = {}

function M.abfragen(zeilen)
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

function M.unter_cursor()
  if vim.b.dbui_db_key_name == nil then
    vim.notify("Datei über die Datenbank-Leiste öffnen (<leader>D), sonst fehlt die Verbindung", vim.log.levels.WARN)
    return
  end
  local zeile = vim.api.nvim_win_get_cursor(0)[1]
  local anfang, ende
  for _, abfrage in ipairs(M.abfragen(vim.api.nvim_buf_get_lines(0, 0, -1, false))) do
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

-- Tasten für einen SQL-Puffer (aus after/ftplugin)
function M.tasten(buf)
  for _, taste in ipairs({ "<C-CR>", "<leader>Q" }) do
    vim.keymap.set("n", taste, M.unter_cursor, { buffer = buf, desc = "Abfrage unter dem Cursor ausführen" })
  end
  -- Q allein spielt das letzte Makro ab. Kommt bei <leader>Q die Leertaste
  -- zu spät (timeoutlen 200 ms), landete so ein versehentlich aufgenommenes
  -- Makro im Text. In SQL-Dateien deshalb abgeschaltet.
  vim.keymap.set("n", "Q", "<Nop>", { buffer = buf, desc = "Makro abspielen (in SQL aus)" })
end

return M
