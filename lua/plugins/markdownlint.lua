-- markdownlint immer mit .markdownlint-cli2.yaml aus diesem Repo (dort:
-- MD013 Zeilenlänge aus). Liegt im Repo, damit es auf jedem PC mitkommt
local config = vim.fn.stdpath("config") .. "/.markdownlint-cli2.yaml"

return {
  {
    "mfussenegger/nvim-lint",
    opts = {
      linters = {
        ["markdownlint-cli2"] = { prepend_args = { "--config", config } },
      },
    },
  },
  {
    "stevearc/conform.nvim",
    opts = {
      formatters = {
        ["markdownlint-cli2"] = { prepend_args = { "--config", config } },
      },
    },
  },
}
