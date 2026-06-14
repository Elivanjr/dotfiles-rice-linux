return {
  "nvim-tree/nvim-tree.lua",
  dependencies = {
    "nvim-tree/nvim-web-devicons",
  },

  config = function()
    -- desabilita netrw
    vim.g.loaded_netrw = 1
    vim.g.loaded_netrwPlugin = 1

    -- cores true color
    vim.opt.termguicolors = true

    require("nvim-tree").setup({
      view = {
        width = 30,
      },

      renderer = {
        group_empty = true,
      },

      filters = {
        dotfiles = false,
      },
    })

    -- atalho
    vim.keymap.set("n", "<leader>e", ":NvimTreeToggle<CR>")
  end,
}
