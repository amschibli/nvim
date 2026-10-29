-- Datenbank-Leiste (dadbod-ui): eigene Abfragen bei jeder Tabelle.
-- Sie zeigen immer das ganze Schema der Tabelle, also egal welche Tabelle man aufklappt.
-- Bewusst kein `init` im Plugin-Eintrag: das würde das `init` von LazyVim ersetzen
-- (Speicherort der Verbindungen usw.), und die Verbindungen wären weg.
vim.g.db_ui_table_helpers = {
  postgresql = {
    -- Alle Tabellen mit ihren Spalten, Schlüssel markiert
    ["Schema: Tabellen"] = [[
SELECT c.table_name  AS tabelle,
       c.column_name AS spalte,
       c.data_type   AS typ,
       CASE WHEN c.is_nullable = 'NO' THEN 'NOT NULL' ELSE '' END AS pflicht,
       string_agg(DISTINCT CASE tc.constraint_type
                             WHEN 'PRIMARY KEY' THEN 'PK'
                             WHEN 'FOREIGN KEY' THEN 'FK'
                             WHEN 'UNIQUE'      THEN 'UNIQUE' END, ', ') AS schluessel
FROM information_schema.columns c
LEFT JOIN information_schema.key_column_usage kcu
       ON kcu.table_schema = c.table_schema
      AND kcu.table_name   = c.table_name
      AND kcu.column_name  = c.column_name
LEFT JOIN information_schema.table_constraints tc
       ON tc.constraint_schema = kcu.constraint_schema
      AND tc.constraint_name   = kcu.constraint_name
WHERE c.table_schema = '{schema}'
GROUP BY c.table_name, c.column_name, c.data_type, c.is_nullable, c.ordinal_position
ORDER BY c.table_name, c.ordinal_position;]],
    -- Alle Fremdschlüssel: welche Spalte zeigt auf welche Tabelle
    ["Schema: Beziehungen"] = [[
SELECT con.conrelid::regclass  AS tabelle,
       von.attname             AS spalte,
       '->'                    AS " ",
       con.confrelid::regclass AS verweist_auf,
       nach.attname            AS ziel_spalte,
       CASE con.confdeltype WHEN 'c' THEN 'CASCADE' WHEN 'n' THEN 'SET NULL'
                            WHEN 'd' THEN 'SET DEFAULT' WHEN 'r' THEN 'RESTRICT'
                            ELSE 'NO ACTION' END AS on_delete,
       con.conname             AS constraint_name
FROM pg_constraint con
CROSS JOIN LATERAL unnest(con.conkey, con.confkey) AS k(von_nr, nach_nr)
JOIN pg_attribute von  ON von.attrelid  = con.conrelid  AND von.attnum  = k.von_nr
JOIN pg_attribute nach ON nach.attrelid = con.confrelid AND nach.attnum = k.nach_nr
WHERE con.contype = 'f'
  AND con.connamespace = '{schema}'::regnamespace
ORDER BY 1, 2;]],
  },
}

return {}
