--!nonstrict
-- Fetches opencode quota every 5 minutes and publishes to shared state.
-- Uses the opencode-go API key from ~/.pi/agent/auth.json (absolute path).

local function fetchQuota()
  -- Prefer the cached file written by the systemd timer (more reliable than
  -- reading the auth key directly from the plugin sandbox). The timer runs
  -- opencode-quota-fetch every 5m and writes ~/.cache/opencode-quota.json.
  local cacheText = noctalia.readFile("/home/vageesh/.cache/opencode-quota.json")
  if cacheText then
    -- Try to parse the cached JSON
    local body = cacheText
    local function extract(field)
      local p = string.find(body, '"' .. field .. '"%s*:%s*{[^}]*"percent"%s*:%s*(%d+)')
      if p then
        local n = string.match(body, '"percent"%s*:%s*(%d+)', p)
        return tonumber(n) or 0
      end
      return 0
    end
    local function extractReset(field)
      local p = string.find(body, '"' .. field .. '"%s*:%s*{')
      if p then
        local s = string.find(body, '"resetsAt"%s*:%s*"', p)
        if s then
          local q1 = string.find(body, '"', s + 10)
          local q2 = string.find(body, '"', q1 + 1)
          if q1 and q2 then
            return string.sub(body, q1 + 1, q2 - 1)
          end
        end
      end
      return ""
    end
    local quota = {
      rolling = extract("rolling"),
      weekly = extract("weekly"),
      monthly = extract("monthly"),
      rollingReset = extractReset("rolling"),
      weeklyReset = extractReset("weekly"),
      monthlyReset = extractReset("monthly"),
    }
    noctalia.state.set("quota", quota)
    return
  end

  -- Fallback: try direct HTTP if cache not available (needs key)
  local authText = noctalia.readFile("/home/vageesh/.pi/agent/auth.json")
  local key = nil
  if authText then
    local s, e = string.find(authText, '"opencode-go"%s*:%s*%{%s*"type"%s*:%s*"api_key"%s*,%s*"key"%s*:%s*"')
    if s then
      local k1 = string.find(authText, '"', e + 1)
      local k2 = string.find(authText, '"', k1 + 1)
      if k1 and k2 then
        key = string.sub(authText, k1 + 1, k2 - 1)
      end
    end
  end

  if not key or key == "" then
    noctalia.state.set("quota", { rolling = 0, weekly = 0, monthly = 0, error = "no key" })
    return
  end

  noctalia.http({
    url = "https://opencode.ai/zen/go/v1/usage",
    headers = { "Authorization: Bearer " .. key },
  }, function(res)
    if res.ok and res.body then
      -- Parse the JSON response: {"usage":{"rolling":{"percent":1,...},"weekly":{...},"monthly":{...}}}
      local body = res.body
      local function extract(field)
        local p = string.find(body, '"' .. field .. '"%s*:%s*{[^}]*"percent"%s*:%s*(%d+)')
        if p then
          local s = string.find(body, '"percent"%s*:%s*(%d+)', p)
          if s then
            local n = string.match(body, '"percent"%s*:%s*(%d+)', p)
            return tonumber(n) or 0
          end
        end
        return 0
      end
      local function extractReset(field)
        local p = string.find(body, '"' .. field .. '"%s*:%s*{')
        if p then
          local s = string.find(body, '"resetsAt"%s*:%s*"', p)
          if s then
            local q1 = string.find(body, '"', s + 10)
            local q2 = string.find(body, '"', q1 + 1)
            if q1 and q2 then
              return string.sub(body, q1 + 1, q2 - 1)
            end
          end
        end
        return ""
      end
      local quota = {
        rolling = extract("rolling"),
        weekly = extract("weekly"),
        monthly = extract("monthly"),
        rollingReset = extractReset("rolling"),
        weeklyReset = extractReset("weekly"),
        monthlyReset = extractReset("monthly"),
      }
      noctalia.state.set("quota", quota)
    else
      noctalia.state.set("quota", { rolling = 0, weekly = 0, monthly = 0, error = "fetch failed" })
    end
  end)
end

function update()
  noctalia.setUpdateInterval(300000) -- 5 minutes
  fetchQuota()
end

-- also fetch immediately on start
fetchQuota()
