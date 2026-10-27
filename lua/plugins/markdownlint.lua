-- markdownlint immer mit ~/.markdownlint-cli2.yaml (dort: MD013 Zeilenlänge aus)
local config = vim.fn.expand("~/.markdownlint-cli2.yaml")

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
