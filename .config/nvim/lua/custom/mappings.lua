 local M = {}

 M.general = {
   -- Normal mode key bindings.
   n = {
     -- ["<C-J>"] = { ":bprev<CR>" },
     -- ["<C-K>"] = { ":bnext<CR>" },
     ["<Leader>ds"] = { "<Plug>(go-def-split)" },
     ["<Leader>dv"] = { "<Plug>(go-def-vertical)" },
   },
 }

 return M
