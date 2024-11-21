local logging = require("logging")

local function matchMacro(s, pattern)
  local i, j = string.find(s, pattern)
  local groups = nil
  if i then
    groups = { string.match(string.sub(s, i, j), pattern) }
    -- logging.temp("groups", groups)
  end
  return i, j, groups
end

local function matchMacros(s, name, arity)
  local pattern = "\\" .. name
  for _ = 1, arity do
    pattern = pattern .. "{(.*)}";
  end
  -- logging.temp("pattern", pattern)
  local res = {}
  local rest = s
  local cur = 0
  while true do
    if rest == "" then
      break
    end
    local i, j, groups = matchMacro(rest, pattern)
    if not i or not j then
      break
    end
    table.insert(res, { i + cur, j + cur, groups })
    cur = cur + j + 1
    rest = string.sub(rest, j + 1)
  end
  return res
end

--- Substitute a macro \name with arity by applying f to each matched argument
--- @param s string
--- @param name string
--- @param arity number
--- @param f fun(groups: string[]): string
--- @return string
local function subMacros(s, name, arity, f)
  local res = ""
  local cur = 0
  -- logging.temp("name", name)
  for _, t in pairs(matchMacros(s, name, arity)) do
    local i, j, groups = t[1], t[2], t[3]
    -- logging.temp("before", string.sub(s, cur, i - 1))
    -- logging.temp("matched", string.sub(s, i, j))
    -- logging.temp("after", string.sub(s, j + 1))
    res = res .. string.sub(s, cur, i - 1) .. f(groups)
    -- logging.temp("here", cur)
    cur = j + 1
  end
  res = res .. string.sub(s, cur)
  return res
end

-- Extract listing labels
-- , Div
--     ( "" , [ "center" ] , [] )
--     [ CodeBlock
--         ( ""
--         , []
--         , [ ( "caption"
--             , "Example specification 1\\label{fi:spec1}"
--             )
--           ]
--         )
--         "var R0: bits(4) = '0001';"
--     ]
-- ]
function CodeBlock(elem)
  local caption = elem.attributes.caption;
  if caption ~= nil then
    -- logging.temp("caption", elem.attributes.caption)
    local i, j = string.find(caption, "\\label{.*}");
    -- logging.temp("label", label)
    if i ~= nil and j ~= nil then
      local label = string.sub(caption, i + 7, j - 1);
      elem.attributes.caption = string.sub(caption, 0, i - 1)
      elem.identifier = label
      -- logging.temp("updated", elem)
    end
  end
  return elem
end

-- Convert inline math's \hyperlink to \href
-- , Math InlineMath "\\hyperlink{def-triangleq}{\\triangleq}"
function Math(elem)
  -- logging.temp("text", elem.text)
  local res = subMacros(elem.text, "hyperlink", 2, function(groups)
    return "\\href{#" .. groups[1] .. "}{" .. groups[2] .. "}"
  end);
  -- logging.temp("res", res)
  elem.text = res
  -- subMacros(s)
  return elem
end
