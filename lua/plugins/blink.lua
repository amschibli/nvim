-- Autovervollständigung (blink.cmp): Vorschlag mit Tab übernehmen.
-- "super-tab": Tab übernimmt, wenn die Liste offen ist, sonst springt es in
-- Vorlagen weiter oder rückt normal ein. Enter übernimmt weiterhin auch.
-- Nur `opts` setzen: LazyVim führt die Tabellen zusammen.
return {
  {
    "saghen/blink.cmp",
    opts = {
      keymap = {
        preset = "super-tab",
        ["<CR>"] = { "accept", "fallback" },
      },
    },
  },
}
