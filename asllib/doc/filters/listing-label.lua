local logging = require("logging")
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
--         "var R0: bits(4) = '0001';\nvar R1: bits(4) = '0010';\nvar R2: bits(4);\n\nfunc MyOR{M}(x: bits(M), y: bits(M)) => bits(M)\nbegin\n    return x OR y;\nend;\n\nfunc reset()\nbegin\n    R2 = MyOR(R0, R1);\nend;"
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
