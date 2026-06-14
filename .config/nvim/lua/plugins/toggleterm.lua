return {
  {
    "akinsho/toggleterm.nvim",
    version = "*",

    config = function()
      require("toggleterm").setup({
        direction = "horizontal",
        size = 8,

        shell = "/usr/bin/zsh",
        start_in_insert = true,
        persist_mode = true,
        insert_mappings = true,

        shade_terminals = false,

        winblend = 10,
      })

      vim.keymap.set("n", "<C-t>", "<cmd>ToggleTerm<CR>")
      vim.keymap.set("t", "<C-t>", [[<C-\><C-n><cmd>ToggleTerm<CR>]])
      vim.keymap.set("t", "<Esc>", [[<C-\><C-n><cmd>ToggleTerm<CR>]])

      vim.api.nvim_set_hl(0, "NormalFloat", { bg = "none" })
      vim.api.nvim_set_hl(0, "FloatBorder", { bg = "none" })
      -- vim.api.nvim_set_hl(0, "Normal", { bg = "none" })
      --vim.api.nvim_set_hl(0, "NormalNC", { bg = "none" })
    end,
  },
}
