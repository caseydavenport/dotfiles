 local M = {}

 M.general = {
   -- Normal mode key bindings.
   n = {
     ["<Leader>ds"] = { "<Plug>(go-def-split)" },
     ["<Leader>dv"] = { "<Plug>(go-def-vertical)" },
     ["<Leader>gi"] = { "<Plug>(go-implements)" },
     ["<Leader>T"] = { ":TestNearest" },

     -- Override NvChad terminal toggles, free Alt+h for tmux navigation.
     ["<A-h>"] = { "<cmd>TmuxNavigateLeft<cr>", "Navigate left" },
     ["<A-v>"] = { "<cmd>TmuxNavigateRight<cr>", "Navigate right" },
     ["<A-t>"] = { function() require("nvterm.terminal").toggle("horizontal") end, "Toggle terminal" },
   },
   t = {
     ["<A-h>"] = { "<cmd>TmuxNavigateLeft<cr>", "Navigate left" },
     ["<A-v>"] = { "<cmd>TmuxNavigateRight<cr>", "Navigate right" },
     ["<A-t>"] = { function() require("nvterm.terminal").toggle("horizontal") end, "Toggle terminal" },
   },
 }

 return M
