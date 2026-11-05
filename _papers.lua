-- {{< papers papers.bib >}}
-- Builds the papers list on the Research page from a BibTeX file.
--
-- Each entry shows:
--   Title (bold)
--   With co-authors (gray; your own name is left out)
--   Journal or "Preprint", plus the arXiv ID (gray, links in blue)
--   Blurb from the `abstract` field (italic)
--
-- Fields used: title, author, year, journal, doi, url, eprint, abstract.
-- Papers are sorted newest year first; same-year papers keep their order in the file.

local MY_FAMILY_NAME = "Amit"

local function str(x)
  if x == nil then return nil end
  return pandoc.utils.stringify(x)
end

-- "With A", "With A and B", "With A, B, and C"
local function coauthor_line(authors)
  local names = {}
  for _, a in ipairs(authors or {}) do
    if str(a.family) ~= MY_FAMILY_NAME then
      table.insert(names, (str(a.given) and (str(a.given) .. " ") or "") .. str(a.family))
    end
  end
  if #names == 0 then return nil end
  local list
  if #names == 1 then
    list = names[1]
  elseif #names == 2 then
    list = names[1] .. " and " .. names[2]
  else
    list = table.concat(names, ", ", 1, #names - 1) .. ", and " .. names[#names]
  end
  return "With " .. list
end

-- arXiv ID, from the arxiv.org link Pandoc builds out of `eprint` (or from `url`)
local function arxiv_id(ref)
  return (str(ref.url) or ""):match("arxiv%.org/abs/([^%s/]+)")
end

local function venue_line(ref)
  local parts = pandoc.Inlines{}
  local journal = str(ref["container-title"])
  if journal then
    local doi = str(ref.doi)
    if doi then
      parts:insert(pandoc.Link(journal, "https://doi.org/" .. doi))
    else
      parts:insert(pandoc.Str(journal))
    end
  else
    parts:insert(pandoc.Str("Preprint"))
  end
  local id = arxiv_id(ref)
  if id then
    parts:extend{ pandoc.Str(","), pandoc.Space(),
                  pandoc.Link("arXiv:" .. id, "https://arxiv.org/abs/" .. id) }
  end
  return parts
end

local function year_of(ref)
  return tonumber((str(ref.issued) or ""):match("%d%d%d%d")) or 0
end

return {
  ["papers"] = function(args)
    local file = args[1] and str(args[1]) or "papers.bib"
    local path = quarto.project.directory .. "/" .. file
    local f = io.open(path, "r")
    if not f then
      return pandoc.Para(pandoc.Str("[papers: could not open " .. file .. "]"))
    end
    local text = f:read("a")
    f:close()

    -- Pandoc normally lowercases BibTeX titles; an extra pair of braces keeps them as written.
    text = text:gsub("(%f[%w]title%s*=%s*)(%b{})", "%1{%2}")

    local refs = pandoc.read(text, "bibtex").meta.references or {}
    local list = {}
    for i, r in ipairs(refs) do list[#list + 1] = { ref = r, i = i } end
    table.sort(list, function(a, b)
      local ya, yb = year_of(a.ref), year_of(b.ref)
      if ya ~= yb then return ya > yb end
      return a.i < b.i
    end)

    local blocks = pandoc.Blocks{}
    for _, item in ipairs(list) do
      local r = item.ref
      local entry = pandoc.Blocks{}
      entry:insert(pandoc.Div(pandoc.Plain(pandoc.Strong(r.title)), { class = "paper-title" }))
      local with = coauthor_line(r.author)
      if with then
        entry:insert(pandoc.Div(pandoc.Plain(pandoc.Str(with)), { class = "paper-authors" }))
      end
      entry:insert(pandoc.Div(pandoc.Plain(venue_line(r)), { class = "paper-venue" }))
      if r.abstract then
        entry:insert(pandoc.Div(pandoc.Plain(pandoc.Emph(r.abstract)), { class = "paper-blurb" }))
      end
      blocks:insert(pandoc.Div(entry, { class = "paper" }))
    end
    return blocks
  end
}
