 local M = {}

 M.general = {
   -- Normal mode key bindings.
   n = {
     ["<Leader>ds"] = { "<Plug>(go-def-split)" },
     ["<Leader>dv"] = { "<Plug>(go-def-vertical)" },
     ["<Leader>gi"] = { "<Plug>(go-implements)" },
     ["<Leader>T"] = { ":TestNearest" },

     -- Override NvChad terminal toggles, free Alt+h for tmux navigation.
     -- Override NvChad Alt+h, free it for tmux navigation.
     ["<A-h>"] = { "<cmd>TmuxNavigateLeft<cr>", "Navigate left" },
     -- Terminal toggles.
     ["<A-t>"] = { function() require("nvterm.terminal").toggle("horizontal") end, "Horizontal terminal" },
     ["<A-v>"] = { function() require("nvterm.terminal").toggle("vertical") end, "Vertical terminal" },
   },
   t = {
     ["<A-h>"] = { "<cmd>TmuxNavigateLeft<cr>", "Navigate left" },
     ["<A-t>"] = { function() require("nvterm.terminal").toggle("horizontal") end, "Horizontal terminal" },
     ["<A-v>"] = { function() require("nvterm.terminal").toggle("vertical") end, "Vertical terminal" },
   },
 }

 return M
