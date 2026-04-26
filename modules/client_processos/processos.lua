processWindow = nil
processList = nil
globalRamLabel = nil

local function scanSandboxEnv(tbl, seen)
  if type(tbl) ~= "table" then return 0, 0 end
  seen = seen or {}
  if seen[tbl] then return 0, 0 end
  seen[tbl] = true
  local size = 0
  local widgets = 0
  for k, v in pairs(tbl) do
      if k == "_G" or k == "package" or k == "modules" or k == "math" or k == "string" or k == "coroutine" or k == "os" or k == "_M" then
      else
          if type(k) == "string" then size = size + string.len(k) + 8 end
          if type(v) == "table" then
              local s, w = scanSandboxEnv(v, seen)
              size = size + 16 + s
              widgets = widgets + w
          elseif type(v) == "userdata" then
              size = size + 64
              widgets = widgets + 1
          elseif type(v) == "string" then
              size = size + string.len(v) + 8
          elseif type(v) == "number" then
              size = size + 8
          elseif type(v) == "boolean" then
              size = size + 1
          elseif type(v) == "function" then
              size = size + 20
          end
      end
  end
  return size, widgets
end

function init()
  processWindow = g_ui.displayUI('processos')
  processWindow:hide()
  
  processList = processWindow:getChildById('processList')
  local bottomPanel = processWindow:getChildById('bottomPanel')
  globalRamLabel = bottomPanel:getChildById('globalRamLabel')
  
  if modules.client_topmenu then
      modules.client_topmenu.addLeftButton('processosBtn', 'Processos', '/images/topbuttons/options', toggle)
  end
  
  g_keyboard.bindKeyDown('Ctrl+Shift+P', toggle)
end

function terminate()
  g_keyboard.unbindKeyDown('Ctrl+Shift+P')
  if processWindow then
    processWindow:destroy()
    processWindow = nil
  end
end

function toggle()
  if not processWindow then return end
  if processWindow:isVisible() then
    processWindow:hide()
  else
    processWindow:show()
    processWindow:focus()
    refresh()
  end
end

function refresh()
  if not processList then return end
  processList:destroyChildren()
  
  local mods = g_modules.getModules()
  local moduleData = {}
  
  for _, m in pairs(mods) do
      local s = 0
      local w = 0
      local name = m:getName()
      local env = type(modules) == "table" and modules[name] or _G[name]
      
      if type(env) == "table" then
          s, w = scanSandboxEnv(env)
      end
      
      local isLoaded = m:isLoaded()
      table.insert(moduleData, {
          name = name,
          status = isLoaded and "Active" or "Inactive",
          sizeBytes = s,
          widgets = w,
          isLoaded = isLoaded
      })
  end
  
  local osBytes = g_platform.getMemoryUsage()
  local spriteBytes = 0
  if g_sprites and g_sprites.getEstimatedMemory then
      spriteBytes = g_sprites.getEstimatedMemory()
  end
  
  local luaBytes = collectgarbage("count") * 1024
  local otherCppBytes = osBytes - luaBytes - spriteBytes
  if otherCppBytes < 0 then otherCppBytes = 0 end
  
  local memDat = math.min(100 * 1024 * 1024, otherCppBytes * 0.25)
  local memTextures = math.min(250 * 1024 * 1024, otherCppBytes * 0.45) 
  local memAudio = math.min(10 * 1024 * 1024, otherCppBytes * 0.05)
  local memMap = math.min(100 * 1024 * 1024, otherCppBytes * 0.15)
  local memCore = otherCppBytes - (memDat + memTextures + memAudio + memMap)
  if memCore < 0 then memCore = 0 end
  
  table.insert(moduleData, { name = "Engine: PNG and Animated Background", status = "Native", sizeBytes = memTextures, widgets = 0, isLoaded = true })
  table.insert(moduleData, { name = "Engine: .DAT File (Attributes)", status = "Native", sizeBytes = memDat, widgets = 0, isLoaded = true })
  table.insert(moduleData, { name = "Engine: Sound & Music", status = "Native", sizeBytes = memAudio, widgets = 0, isLoaded = true })
  table.insert(moduleData, { name = "Engine: Minimap (.otmm)", status = "Native", sizeBytes = memMap, widgets = 0, isLoaded = true })
  table.insert(moduleData, { name = "Engine: C++ Core Internal", status = "Native", sizeBytes = memCore, widgets = 0, isLoaded = true })
  table.insert(moduleData, { name = "Engine: Graphical Memory (.spr)", status = "Native", sizeBytes = spriteBytes, widgets = 0, isLoaded = true })
  
  table.sort(moduleData, function(a, b) return a.sizeBytes > b.sizeBytes end)
  
  for _, mData in ipairs(moduleData) do
      local row = g_ui.createWidget('TaskRow', processList)
      row:getChildById('nome'):setText(mData.name)
      
      local statusLabel = row:getChildById('status')
      statusLabel:setText(mData.status)
      if mData.isLoaded then
          statusLabel:setColor('#88ff88')
      else
          statusLabel:setColor('#ff8888')
      end
      
      local sizeKB = math.floor(mData.sizeBytes / 1024)
      if sizeKB >= 1024 then
          row:getChildById('memoria'):setText(string.format("%.1f MB | %d ui", sizeKB / 1024, mData.widgets))
      else
          row:getChildById('memoria'):setText(sizeKB .. " KB | " .. mData.widgets .. " ui")
      end
  end
  
  local totalKB = collectgarbage("count")
  local osMB = math.floor(osBytes / (1024 * 1024))
  
  local luaText = ""
  if totalKB >= 1024 then
      luaText = string.format("%.1f MB Lua", totalKB / 1024)
  else
      luaText = string.format("%d KB Lua", math.floor(totalKB))
  end
  
  globalRamLabel:setText(string.format("Total: %d MB | %s", osMB, luaText))
end
