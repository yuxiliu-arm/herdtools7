local logging = require("logging")

--- find first match of pattern and capture all groups according to arity
--- @param s string
--- @param pattern string
--- @param arity integer
local function matchMacro(s, pattern, arity)
  local i, j = string.find(s, pattern)
  local groups = {}
  local captured = 0
  if i ~= nil then
    -- j is '{' after "\name"
    local l = j + 1
    local stack = 1
    for r = l, string.len(s) do
      if captured >= arity or l >= #s then
        break
      end
      local c = string.sub(s, r, r)
      -- logging.temp("c", c)
      -- logging.temp("stack", stack)
      if c == "{" then
        if stack == 0 then
          l = r + 1
        end
        stack = stack + 1
      elseif c == "}" then
        stack = stack - 1
        if stack == 0 then
          -- logging.temp("found", r)
          table.insert(groups, string.sub(s, l, r - 1))
          captured = captured + 1
          j = r
        end
      end
    end
    -- logging.temp("groups", groups)
  end
  return i, j, groups
end

local function matchMacros(s, name, arity)
  local pattern = "\\" .. name .. "{"
  -- logging.temp("pattern", pattern)
  local res = {}
  local rest = s
  local cur = 0
  while true do
    -- logging.temp("rest", rest)
    if rest == "" then
      break
    end
    local i, j, groups = matchMacro(rest, pattern, arity)
    if not i or not j then
      break
    end
    -- logging.temp("i", i)
    -- logging.temp("j", j)
    -- logging.temp("groups", groups)
    -- logging.temp("matched", string.sub(rest, i, j))
    -- logging.temp("matched", string.sub(s, i + cur, j + cur))
    -- logging.temp("cur", cur)
    table.insert(res, { i + cur, j + cur, groups })
    cur = cur + j
    -- logging.temp("cur'", cur)
    rest = string.sub(rest, j + 1)
    -- logging.temp("rest", rest)
  end
  -- logging.temp("res", res)
  return res
end

--- Substitute a macro \name with arity by applying f to each matched argument
--- @param s string
--- @param name string
--- @param arity integer
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
    local i, j, groups = matchMacro(caption, "\\label{", 1);
    -- logging.temp("label", label)
    if i ~= nil and j ~= nil then
      elem.attributes.caption = string.sub(caption, 0, i - 1)
      elem.identifier = groups[1]
      -- logging.temp("updated", elem)
    end
  end
  return elem
end

--- somehow pandoc doubly expands "hyperlink" in tables
--- recursively expand content
local function subHyperlink(s)
  return subMacros(s, "hyperlink", 2, function(groups)
    local content = subHyperlink(groups[2])
    return "\\href{#" .. groups[1] .. "}{" .. content .. "}"
  end);
end

-- Convert inline math's \hyperlink to \href
-- , Math InlineMath "\\hyperlink{def-triangleq}{\\triangleq}"
function Math(elem)
  local res = elem.text
  -- logging.temp("text", elem.text)
  res = subHyperlink(res)
  res = subMacros(res, "hypertarget", 2, function(groups)
    return "{" .. groups[2] .. "\\label{" .. groups[1] .. "}}"
  end)
  -- logging.temp("res", res)
  elem.text = res
  -- subMacros(s)
  return elem
end
