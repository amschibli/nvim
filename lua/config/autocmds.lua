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

-- Datenbank-Leiste: Abfrage löschen (d) setzt im Abfrage-Fenster mit b# den
-- vorherigen Puffer ein, und das ist meist die Leiste selbst. Dann zeigen zwei
-- Fenster die Leiste, dadbod-ui findet kein freies Fenster mehr und öffnet die
-- nächste Abfrage in einem neuen Split: die Leiste nimmt das halbe Bild ein.
-- Das zweite Leisten-Fenster (ohne winfixwidth, das hat nur die echte Leiste)
-- bekommt deshalb einen leeren Puffer.
vim.api.nvim_create_autocmd("BufWinEnter", {
  callback = function(ev)
    if vim.bo[ev.buf].filetype ~= "dbui" then
      return
    end
    vim.schedule(function()
      for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
        if vim.api.nvim_win_get_buf(win) == ev.buf and not vim.wo[win].winfixwidth then
          vim.api.nvim_win_call(win, function()
            vim.cmd("enew")
            vim.bo.bufhidden = "wipe"
          end)
        end
      end
    end)
  end,
})

-- Datenbank-Leiste: Das Ergebnis öffnet unten über die ganze Breite. Schliesst
-- man das Abfrage-Fenster, wird die Leiste darüber ganz breit. Die nächste
-- Abfrage kommt dann in eine neue Spalte rechts, und Leiste plus Ergebnis
-- teilen sich die linke Hälfte. Danach Ergebnis wieder ganz nach unten
-- (wincmd J, Höhe wie vom Plugin: previewheight) und Leiste auf ihre Breite.
vim.api.nvim_create_autocmd("BufWinEnter", {
  callback = function()
    vim.schedule(function()
      local leiste, ergebnis, andere
      for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
        if vim.api.nvim_win_get_config(win).relative == "" then
          local ft = vim.bo[vim.api.nvim_win_get_buf(win)].filetype
          if ft == "dbui" and vim.wo[win].winfixwidth then
            leiste = win
          elseif ft == "dbout" and vim.wo[win].previewwindow then
            ergebnis = win
          else
            andere = win
          end
        end
      end
      local breite = vim.g.db_ui_winwidth or 40
      if not (leiste and ergebnis and andere) or vim.api.nvim_win_get_width(leiste) <= breite then
        return
      end
      vim.api.nvim_win_call(ergebnis, function()
        vim.cmd("wincmd J")
      end)
      vim.api.nvim_win_set_height(ergebnis, vim.o.previewheight)
      vim.api.nvim_win_set_width(leiste, breite)
    end)
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
