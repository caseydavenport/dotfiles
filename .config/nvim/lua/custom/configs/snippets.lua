-- Based on documentation for LuaSnip.
-- https://github.com/L3MON4D3/LuaSnip/blob/master/DOC.md
local ls = require("luasnip")
local s = ls.snippet
local t = ls.text_node
local i = ls.insert_node
local sn = ls.snippet_node

-- errRet1 is an error check that returns (nil, err).
local errRet1 =	s("errretnil", {
    t({
      "if err != nil {",
      "  return nil, err",
      "}"
    })
	}
)

-- errRet2 is an error check that builds a new error.
local errRet2 =	s("errretfmt", {
    t({
    "if err != nil {",
    "  return nil, fmt.Errorf(\""}), i(1), t({"\")", "}"}),
  }
)

-- Load all the snippets we want for Golang here.
ls.add_snippets("go", {
  errRet1,
  errRet2,
})
