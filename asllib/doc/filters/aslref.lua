local logging = require("logging")

--- find first match of pattern and capture all groups according to arity
--- @param s string
--- @param pattern string
--- @param arity integer
--- @return integer|nil, integer|nil, string[]
local function matchMacro(s, pattern, arity)
  local i, j = s:find(pattern)
  local groups = {}
  local captured = 0
  if i ~= nil then
    -- j is '{' after "\name"
    local l = j + 1
    local stack = 1
    for r = l, s:len() do
      if captured >= arity or l >= #s then
        break
      end
      local c = s:sub(r, r)
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
          table.insert(groups, s:sub(l, r - 1))
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
    -- logging.temp("matched", rest:sub(i, j))
    -- logging.temp("matched", s:sub(i + cur, j + cur))
    -- logging.temp("cur", cur)
    table.insert(res, { i + cur, j + cur, groups })
    cur = cur + j
    -- logging.temp("cur'", cur)
    rest = rest:sub(j + 1)
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
    -- logging.temp("before", s:sub(cur, i - 1))
    -- logging.temp("matched", s:sub(i, j))
    -- logging.temp("after", s:sub(j + 1))
    res = res .. s:sub(cur, i - 1) .. f(groups)
    -- logging.temp("here", cur)
    cur = j + 1
  end
  res = res .. s:sub(cur)
  return res
end

--- highlight with tree-sitter
--- @param s string
--- @return string
local function highlightASL(s)
  return "<pre>" .. pandoc.pipe("tree-sitter-asl-highlight", {}, s) .. "</pre>"
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
  local id = nil
  if caption ~= nil then
    -- logging.temp("caption", elem.attributes.caption)
    local i, j, groups = matchMacro(caption, "\\label{", 1);
    -- logging.temp("label", label)
    if i ~= nil and j ~= nil then
      caption = caption:sub(0, i - 1)
      id = groups[1]
      -- logging.temp("updated", elem)
    end
  end
  local highlighted = highlightASL(elem.text)
  if highlighted then
    local contents = { pandoc.RawInline("html", highlighted) }
    local span = pandoc.Span(contents)
    span.attributes.caption = caption
    span.identifier = id
    return { span }
  else
    elem.attributes.caption = caption
    elem.identifier = id
    return elem
  end
end

--- rewrite \ref{A} in math to $\textrm{\href{#A}{A}}$
local function subRef(s)
  return subMacros(s, "ref", 1, function(groups)
    return "\\textrm{\\href{#" .. groups[1] .. "}{" .. groups[1] .. "}}"
  end)
end

--- somehow pandoc doubly expands "hyperlink" in tables
--- recursively expand content
local function subHyperlink(s)
  return subMacros(s, "hyperlink", 2, function(groups)
    local content = subHyperlink(groups[2])
    return "\\href{#" .. groups[1] .. "}{" .. content .. "}"
  end)
end

--- inside `\inferrule` replace `\and` with `\quad`
local function subInferruleAnd(s)
  local res = subMacros(s, "displaylines", 1, function(groups)
    -- logging.temp("before", groups[1])
    local res = groups[1]:gsub("\\and", "\\quad")
    -- logging.temp("after", res)
    return "\\displaylines{" .. res .. "}"
  end)
  return res
end

--- https://stackoverflow.com/a/76640488
local function split(str, sep)
  local res, from = {}, 1
  repeat
    local pos = str:find(sep, from)
    table.insert(res, str:sub(from, pos and pos - 1))
    from = pos and pos + #sep
  until not from
  return res
end


-- Convert inline math's \hyperlink to \href
-- , Math InlineMath "\\hyperlink{def-triangleq}{\\triangleq}"
function Math(elem)
  -- logging.temp("elem", elem)
  local res = elem.text
  -- logging.temp("text", elem.text)
  res = subRef(res)
  res = subHyperlink(res)
  res = subMacros(res, "hypertarget", 2, function(groups)
    return "\\cssId{" .. groups[1] .. "}{" .. groups[2] .. "}"
  end)
  if res:find("prooftree") then
    res = subInferruleAnd(res)
    -- logging.temp("res", res)
    if res:find("\\and%s") then
      -- `\and` must be outside of inferrule
      local elems = {}
      local chunks = split(res, "\\and")
      for i, chunk in pairs(chunks) do
        local text = chunk
        if i ~= #chunks then
          text = text .. "\\end{prooftree}"
        end
        if i ~= 1 then
          text = "\\begin{prooftree}" .. text
        end
        table.insert(elems, pandoc.Math(pandoc.DisplayMath, text))
      end
      -- logging.temp("elems", elems)
      return elems
    else
      elem.text = res
      return elem
    end
  else
    elem.text = res
    -- subMacros(s)
    return elem
  end
end

local function getId(path, idMaps, elem)
  -- logging.temp("elem", elem)
  local attr = elem.attr
  if attr then
    local id = attr.identifier
    if id and id ~= "" then
      idMaps[id] = path
    end
  end
end

local function getMathId(path, idMaps, elem)
  local text = elem.text
  if text then
    for _, t in pairs(matchMacros(text, "cssId", 1)) do
      local id = t[3][1]
      -- logging.temp("cssId", id)
      idMaps[id] = path
    end
  end
end

-- https://github.com/jgm/pandoc-website/pull/50
-- Adds anchor links to headings with IDs.
function Header(h)
  if h.level ~= 1 and h.identifier ~= '' then
    -- an empty link to this header
    local anchor_link = pandoc.Link(
      {},                                            -- content
      '#' .. h.identifier,                           -- href
      '',                                            -- title
      { class = 'anchor', ['aria-hidden'] = 'true' } -- attributes
    )
    h.content:insert(1, anchor_link)
    return h
  end
end

function Pandoc(doc)
  local idMaps = {}
  local chunks = pandoc.structure.split_into_chunks(doc, {
        number_sections = true,
        path_template = "%i.html",
      })
      .chunks
  for _, chunk in pairs(chunks) do
    for _, block in pairs(chunk.contents) do
      local getIdFilter = function(elem) getId(chunk.path, idMaps, elem) end
      local getMathIdFilter = function(elem) getMathId(chunk.path, idMaps, elem) end
      block:walk({ Inline = getIdFilter, Block = getIdFilter, Math = getMathIdFilter })
    end
  end
  -- logging.temp("idMaps", idMaps)
  local fixRef = function(s)
    if s and s ~= "" then
      local content = s:match("#(.*)")
      if content then
        local path = idMaps[content]
        if path then
          return path .. s
        end
      end
    end
    return nil
  end
  local fixed = doc:walk({
    Link = function(elem)
      local newTarget = fixRef(elem.target)
      if newTarget then
        elem.target = newTarget
      end
      return elem
    end,
    Math = function(elem)
      local res = elem.text
      res = subMacros(res, "href", 2, function(groups)
        local newTarget = fixRef(groups[1]) or groups[1]
        return "\\href{" .. newTarget .. "}{" .. groups[2] .. "}"
      end)
      -- logging.temp("res", res)
      elem.text = res
      -- subMacros(s)
      return elem
    end
  })
  return fixed
end
