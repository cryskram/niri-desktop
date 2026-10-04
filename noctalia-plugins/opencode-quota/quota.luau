--!nonstrict
-- Bar pill showing opencode quota (rolling/weekly/monthly)
-- Watches shared state from fetcher service, renders as a capsule.

local quota = noctalia.state.get("quota") or { rolling = 0, weekly = 0, monthly = 0 }

local function quotaColor(p)
  if p > 80 then return "#ed8796" end
  if p > 50 then return "#eed49f" end
  return "#a6da95"
end

local function formatReset(iso)
  if not iso or iso == "" then return "" end
  -- iso is like "2026-10-04T19:00:21.000Z" — parse and show relative or date
  -- For simplicity, just show the date part
  local y, m, d, h, min = string.match(iso, "(%d+)-(%d+)-(%d+)T(%d+):(%d+)")
  if y and m and d then
    return m .. "/" .. d .. " " .. h .. ":" .. min
  end
  return iso
end

local function render()
  local isVert = barWidget.isVertical()
  local r = quota.rolling or 0
  local w = quota.weekly or 0
  local mo = quota.monthly or 0

  if isVert then
    -- Vertical: compact single column, just rolling + tiny weekly/monthly below
    barWidget.render(ui.column({ gap = 2, align = "center" }, {
      ui.glyph({ name = "cloud", size = 14, color = quotaColor(r) }),
      ui.label({ text = tostring(r) .. "%", color = quotaColor(r), fontWeight = "bold", fontSize = 11 }),
      ui.label({ text = tostring(w) .. "·" .. tostring(mo), color = "#a5adcb", fontSize = 8 }),
    }))
  else
    barWidget.render(ui.row({ gap = 4, align = "center" }, {
      ui.glyph({ name = "cloud", size = 12, color = quotaColor(r) }),
      ui.label({ text = tostring(r) .. "%", color = quotaColor(r), fontWeight = "bold", fontSize = 11 }),
      ui.label({ text = "· " .. tostring(w) .. "% · " .. tostring(mo) .. "%", color = "#a5adcb", fontSize = 9 }),
    }))
  end
end

noctalia.state.watch("quota", function(value)
  if value then
    quota = value
    render()
  end
end)

function update()
  noctalia.setUpdateInterval(60000)
  -- refresh from state in case service hasn't run yet
  local q = noctalia.state.get("quota")
  if q then
    quota = q
  end
  render()
end

function onClick()
  noctalia.togglePanel("local/opencode-quota:details")
end

function onRightClick()
  onClick()
end
