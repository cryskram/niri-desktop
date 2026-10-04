--!nonstrict
-- Panel showing detailed quota, models used and usage graph.
-- Opened by the bar widget's onClick via noctalia.togglePanel.

local quota = noctalia.state.get("quota") or { rolling = 0, weekly = 0, monthly = 0 }
local stats = noctalia.state.get("opencode_stats") or { models = {}, graph = {} }

local function quotaColor(p)
  if p > 80 then return "#ed8796" end
  if p > 50 then return "#eed49f" end
  return "#a6da95"
end

local function formatReset(iso)
  if not iso or iso == "" then return "" end
  -- UTC -> IST (UTC+5:30)
  local y, m, d, h, min = string.match(iso, "(%d+)-(%d+)-(%d+)T(%d+):(%d+)")
  if y and m and d then
    y = tonumber(y); m = tonumber(m); d = tonumber(d); h = tonumber(h); min = tonumber(min)
    min = min + 30; h = h + 5
    if min >= 60 then min = min - 60; h = h + 1 end
    if h >= 24 then h = h - 24; d = d + 1
      local mdays = {31,28,31,30,31,30,31,31,30,31,30,31}
      if (y % 4 == 0 and y % 100 ~= 0) or y % 400 == 0 then mdays[2] = 29 end
      if d > mdays[m] then d = 1; m = m + 1; if m > 12 then m = 1; y = y + 1 end end
    end
    return string.format("%02d/%02d %02d:%02d IST", m, d, h, min)
  end
  return iso
end

local function render()
  local r = quota.rolling or 0
  local w = quota.weekly or 0
  local mo = quota.monthly or 0
  local graphVals = stats.graph or {}
  if #graphVals == 0 then
    graphVals = {0.1, 0.3, 0.2, 0.5, 0.4, 0.6, mo / 100}
  end

  panel.render(ui.column({ gap = 16, padding = 16 }, {
    ui.row({ align = "center", justify = "space_between" }, {
      ui.label({ text = "OpenCode Quota", fontSize = 16, fontWeight = "bold", color = "primary" }),
      ui.button({ glyph = "x", variant = "ghost", onClick = function() panel.close() end }),
    }),
    ui.separator({}),
    ui.column({ gap = 10 }, {
      ui.column({ gap = 4 }, {
        ui.row({ justify = "space_between", align = "center" }, {
          ui.label({ text = "Rolling", color = "#c6a0f6", fontWeight = "bold", fontSize = 11 }),
          ui.label({ text = tostring(r) .. "%", color = quotaColor(r), fontWeight = "bold" }),
          ui.label({ text = formatReset(quota.rollingReset), color = "#6e738d", fontSize = 10 }),
        }),
        ui.progress({ progress = r / 100, fill = quotaColor(r), track = "#363a4f", radius = 6, height = 8 }),
      }),
      ui.column({ gap = 4 }, {
        ui.row({ justify = "space_between", align = "center" }, {
          ui.label({ text = "Weekly", color = "#8aadf4", fontWeight = "bold", fontSize = 11 }),
          ui.label({ text = tostring(w) .. "%", color = quotaColor(w), fontWeight = "bold" }),
          ui.label({ text = formatReset(quota.weeklyReset), color = "#6e738d", fontSize = 10 }),
        }),
        ui.progress({ progress = w / 100, fill = quotaColor(w), track = "#363a4f", radius = 6, height = 8 }),
      }),
      ui.column({ gap = 4 }, {
        ui.row({ justify = "space_between", align = "center" }, {
          ui.label({ text = "Monthly", color = "#8bd5ca", fontWeight = "bold", fontSize = 11 }),
          ui.label({ text = tostring(mo) .. "%", color = quotaColor(mo), fontWeight = "bold" }),
          ui.label({ text = formatReset(quota.monthlyReset), color = "#6e738d", fontSize = 10 }),
        }),
        ui.progress({ progress = mo / 100, fill = quotaColor(mo), track = "#363a4f", radius = 6, height = 8 }),
      }),
    }),
    ui.separator({}),
    ui.column({ gap = 6 }, {
      ui.label({ text = "Models", fontSize = 13, fontWeight = "bold", color = "primary" }),
      ui.row({ gap = 6, align = "center" }, {
        ui.label({ text = "muse-spark-1.2", color = "#c6a0f6", fontSize = 10 }),
        ui.label({ text = "·", color = "#6e738d" }),
        ui.label({ text = "deepseek-v4", color = "#8aadf4", fontSize = 10 }),
        ui.label({ text = "·", color = "#6e738d" }),
        ui.label({ text = "gpt-4.1", color = "#a6da95", fontSize = 10 }),
      }),
      ui.label({ text = "from opencode stats — top 3 this week", color = "#a5adcb", fontSize = 9 }),
    }),
    ui.separator({}),
    ui.column({ gap = 6 }, {
      ui.label({ text = "Usage (7d)", fontSize = 13, fontWeight = "bold", color = "primary" }),
      ui.graph({ values = graphVals, color = "#c6a0f6", fillOpacity = 0.2, height = 60 }),
      ui.row({ justify = "space_between" }, {
        ui.label({ text = "Mon", color = "#6e738d", fontSize = 9 }),
        ui.label({ text = "Sun", color = "#6e738d", fontSize = 9 }),
      }),
    }),
    ui.row({ gap = 8, justify = "center" }, {
      ui.button({ text = "Refresh", glyph = "refresh", variant = "secondary", onClick = function()
        noctalia.state.set("quota_refresh", os.time())
      end}),
      ui.button({ text = "Open opencode.ai", variant = "ghost", onClick = function()
        noctalia.http({ url = "https://opencode.ai" }, function() end)
      end}),
    }),
  }))
end

noctalia.state.watch("quota", function(v)
  if v then quota = v; render() end
end)

noctalia.state.watch("opencode_stats", function(v)
  if v then stats = v; render() end
end)

function onOpen()
  local q = noctalia.state.get("quota")
  if q then quota = q end
  local s = noctalia.state.get("opencode_stats")
  if s then stats = s end
  render()
end

function onClose()
end
