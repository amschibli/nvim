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
vim.api.nvim_create_autocmd("FileType", {
  pattern = "dbui",
  callback = function()
    for _, win in ipairs(vim.api.nvim_list_wins()) do
      if vim.bo[vim.api.nvim_win_get_buf(win)].filetype == "snacks_dashboard" then
        vim.api.nvim_win_call(win, function()
          vim.cmd("enew")
        end)
      end
    end
  end,
})

-- SQL: Abfrage unter dem Cursor ausführen (wie Ctrl+Enter in DataGrip).
-- Treesitter liefert Anfang und Ende der Abfrage, egal wie viele Zeilen.
-- Markiert sie genau und lässt dadbod-ui die Auswahl ausführen.
local function sql_abfrage_unter_cursor()
  if vim.b.dbui_db_key_name == nil then
    vim.notify("Datei über die Datenbank-Leiste öffnen (<leader>D), sonst fehlt die Verbindung", vim.log.levels.WARN)
    return
  end
  local ok, parser = pcall(vim.treesitter.get_parser, 0, "sql")
  if not ok or not parser then
    vim.notify("Kein SQL-Parser (Treesitter)", vim.log.levels.ERROR)
    return
  end
  local zeile = vim.api.nvim_win_get_cursor(0)[1] - 1
  local anfang, ende
  for knoten in parser:parse()[1]:root():iter_children() do
    if knoten:type() == "statement" then
      local sr, sc, er, ec = knoten:range()
      -- Strichpunkt gehört dazu (eigener Knoten direkt danach)
      local naechster = knoten:next_sibling()
      if naechster and naechster:type() == ";" then
        _, _, er, ec = naechster:range()
      end
      if zeile >= sr and zeile <= er then
        anfang, ende = { sr + 1, sc }, { er + 1, math.max(ec - 1, 0) }
        break
      end
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
  end,
})
