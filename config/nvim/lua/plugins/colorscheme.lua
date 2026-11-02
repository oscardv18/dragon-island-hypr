return {
  {
    "olimorris/onedarkpro.nvim",
    lazy = false,
    priority = 1000,
    opts = {
      -- Keep One Dark's color roles, with a brighter, more saturated palette.
      colors = {
        onedark_vivid = {
          bg = "#1E2127",
          fg = "#E6EDF3",
          red = "#FF5370",
          green = "#A3F06C",
          yellow = "#FFD866",
          blue = "#40BFFF",
          purple = "#C678FF",
          cyan = "#29E0D3",
          orange = "#FFAB57",
        },
      },
      styles = {
        comments = "italic",
        keywords = "bold",
      },
      highlights = {
        NormalNC = { bg = "NONE", extend = true },
        NormalFloat = { bg = "NONE", extend = true },
        FloatBorder = { bg = "NONE", extend = true },
        SnacksNormal = { bg = "NONE", extend = true },
        SnacksNormalNC = { bg = "NONE", extend = true },
        SnacksPickerNormal = { bg = "NONE", extend = true },
        SnacksPickerBorder = { bg = "NONE", extend = true },
        Comment = { fg = "#929DB3", italic = true },
        LineNr = { fg = "#748099" },
        CursorLineNr = { fg = "${yellow}", bold = true },
      },
      options = {
        transparency = true,
        lualine_transparency = true,
        cursorline = true,
        terminal_colors = true,
      },
    },
  },
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "onedark_vivid",
    },
  },
}
