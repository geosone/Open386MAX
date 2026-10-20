-- pandoc filter for the LaTeX/PDF of docs/specs:  a code block
-- (registers, tables, diagrams, code) or a list of registers (div "regs")
-- starts on a new page when the rest of the page can't hold it, so it is
-- never split (unless it is longer than a page); a heading right before
-- it goes along.

local function needspace(lines)
  return pandoc.RawBlock('latex',
    string.format('\\needspace{%d\\baselineskip}', math.min(lines, 50)))
end

-- printed lines of a block that must stay in one piece, or nil
local function keeplines(b)
  if b.t == 'CodeBlock' then
    local _, n = b.text:gsub('\n', '')
    return n + 2
  end
  if b.t == 'Div' and b.classes:includes('regs') then
    -- about 95 characters per printed line, a blank line between entries
    local lines = 0
    for _, p in ipairs(b.content) do
      lines = lines + math.ceil(#pandoc.utils.stringify(p) / 95) + 1
    end
    return lines
  end
end

function Blocks(blocks)
  local out = pandoc.Blocks({})
  for i, b in ipairs(blocks) do
    local n = keeplines(b)
    if n then
      if #out > 0 and out[#out].t == 'Header' then
        local h = table.remove(out)
        out:insert(needspace(n + 3))
        out:insert(h)
      else
        out:insert(needspace(n))
      end
    end
    if b.t == 'Div' and b.classes:includes('regs') then
      out:extend(b.content)
    else
      out:insert(b)
    end
  end
  return out
end
