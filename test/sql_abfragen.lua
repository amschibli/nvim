-- Test für den SQL-Parser (lua/sql_abfragen.lua), ohne Plugins und Config:
--   nvim -l test/sql_abfragen.lua
-- Ausgabe "OK" oder die Fälle, die nicht stimmen (Exit 1).
local repo = vim.fs.dirname(vim.fs.dirname(vim.fs.normalize(vim.fn.fnamemodify(arg[0], ":p"))))
package.path = repo .. "/lua/?.lua;" .. package.path
local abfragen = require("sql_abfragen").abfragen

-- { Name, Zeilen, erwartet } – erwartet: "{zeile,spalte}-{zeile,spalte}" je
-- Abfrage (Zeile ab 1, Spalte ab 0, Ende = Strichpunkt)
local faelle = {
  { "einfach", { "SELECT 1;" }, "{1,0}-{1,8}" },
  { "mehrzeilig", { "SELECT a,", "       b", "FROM t;", "", "SELECT 2;" }, "{1,0}-{3,6} {5,0}-{5,8}" },
  { "; im Kommentar", { "SELECT 1 -- a;b", "FROM t; /* x; */ SELECT 2;" }, "{1,0}-{2,6} {2,17}-{2,25}" },
  { "; im Text", { "SELECT ';' , \"a;b\" FROM t;" }, "{1,0}-{1,25}" },
  { "$tag$-Text", { "DO $body$ BEGIN PERFORM 1; END $body$;", "SELECT 3;" }, "{1,0}-{1,37} {2,0}-{2,8}" },
  {
    "Transaktion mit SAVEPOINT",
    { "BEGIN;", "UPDATE t SET a = 1;", "SAVEPOINT s1;", "ROLLBACK;" },
    "{1,0}-{1,5} {2,0}-{2,18} {3,0}-{3,12} {4,0}-{4,8}",
  },
  { "letzte ohne ;", { "SELECT 1;", "SELECT 2" }, "{1,0}-{1,8} {2,0}-{2,7}" },
  { "/* */ über Zeilen", { "/* a;", "   b; */ SELECT 1;" }, "{2,9}-{2,17}" },
  { "nur Kommentar", { "", "-- nur kommentar;" }, "" },
}

local fehler = 0
for _, f in ipairs(faelle) do
  local ist = {}
  for _, a in ipairs(abfragen(f[2])) do
    table.insert(ist, ("{%d,%d}-{%d,%d}"):format(a.anfang[1], a.anfang[2], a.ende[1], a.ende[2]))
  end
  ist = table.concat(ist, " ")
  if ist ~= f[3] then
    fehler = fehler + 1
    io.stdout:write(("FEHLER %s: erwartet %q, ist %q\n"):format(f[1], f[3], ist))
  end
end
io.stdout:write(fehler == 0 and ("OK (%d Fälle)\n"):format(#faelle) or ("%d von %d falsch\n"):format(fehler, #faelle))
os.exit(fehler == 0 and 0 or 1)
