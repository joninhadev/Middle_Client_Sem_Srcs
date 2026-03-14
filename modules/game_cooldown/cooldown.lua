local ProgressCallback = {
  update = 1,
  finish = 2
}

cooldownWindow = nil
cooldownButton = nil
contentsPanel = nil
cooldownPanel = nil
lastPlayer = nil

cooldown = {}
cooldowns = {}
groupCooldown = {}

function init()
  connect(g_game, { onGameStart = online,
                    onSpellGroupCooldown = onSpellGroupCooldown,
                    onSpellCooldown = onSpellCooldown })

  -- connect to game interface
  local mapPanel
  if modules.game_interface then
    if modules.game_interface.getMapPanel then
      mapPanel = modules.game_interface.getMapPanel()
    elseif modules.game_interface.getRootPanel then
      mapPanel = modules.game_interface.getRootPanel():getChildById('gameMapPanel')
    end
  end
  
  if not mapPanel then
    local root = g_ui.getRootWidget()
    mapPanel = root:recursiveGetChildById('gameMapPanel')
  end
  
  cooldownWindow = g_ui.loadUI('cooldown', mapPanel)
  
  -- no need to move child index as we use anchors on the map panel overlay
  -- mapPanel:moveChildToIndex(cooldownWindow, 1)

  contentsPanel = cooldownWindow -- no longer separate contents panel
  cooldownPanel = cooldownWindow:getChildById('cooldownPanel')

  -- preload cooldown images
  for k,v in pairs(SpelllistSettings) do
    g_textures.preload(v.iconFile)
  end

  if g_game.isOnline() then
    online()
  end
end

function terminate()
  disconnect(g_game, { onGameStart = online,
                       onSpellGroupCooldown = onSpellGroupCooldown,
                       onSpellCooldown = onSpellCooldown })
                       
  for key, val in pairs(cooldowns) do
    removeCooldown(key)
  end
  cooldowns = {}

  if cooldownButton then
    cooldownButton:destroy()
    cooldownButton = nil
  end
  if cooldownWindow then
    cooldownWindow:destroy()
    cooldownWindow = nil
  end
end

function loadIcon(iconId)
  local spell, profile, spellName = Spells.getSpellByIcon(iconId)
  if not spellName then return end
  if not profile then return end

  clientIconId = Spells.getClientId(spellName)
  if not clientIconId then return end

  local icon = cooldownPanel:getChildById(iconId)
  if not icon then
    icon = g_ui.createWidget('SpellIcon')
    icon:setId(iconId)
  end

  local spellSettings = SpelllistSettings[profile]
  if spellSettings then
    icon:setImageSource(spellSettings.iconFile)
    icon:setImageClip(Spells.getImageClip(clientIconId, profile))
  else
    icon = nil
  end
  return icon
end


function online()
  --[[if g_game.getFeature(GameSpellList) then
    cooldownButton:show()
  else
    cooldownButton:hide()
    cooldownWindow:close()
  end]]
 -- cooldownWindow:open() -- panels are visible by default usually? or need show()?

  if not lastPlayer or lastPlayer ~= g_game.getCharacterName() then
    refresh()
    lastPlayer = g_game.getCharacterName()
  end
end

function refresh()
  cooldownPanel:destroyChildren()
end

function removeCooldown(progressRect)
  removeEvent(progressRect.event)
  if progressRect.icon then
    progressRect.icon:destroy()
    progressRect.icon = nil
  end
  cooldowns[progressRect] = nil
  progressRect = nil
end

function turnOffCooldown(progressRect)
  removeEvent(progressRect.event)
  if progressRect.icon then
    progressRect.icon:setOn(false)
    progressRect.icon = nil
  end

  -- create particles
  --[[local particle = g_ui.createWidget('GroupCooldownParticles', progressRect)
  particle:fill('parent')
  scheduleEvent(function() particle:destroy() end, 1000) -- hack until onEffectEnd]]

  cooldowns[progressRect] = nil
  progressRect = nil
end

function initCooldown(progressRect, updateCallback, finishCallback)
  progressRect:setPercent(0)

  progressRect.callback = {}
  progressRect.callback[ProgressCallback.update] = updateCallback
  progressRect.callback[ProgressCallback.finish] = finishCallback

  updateCallback()
end

function updateCooldown(progressRect, duration)
  progressRect:setPercent(progressRect:getPercent() + 10000/duration)

  if progressRect.label then
    local remaining = math.ceil((100 - progressRect:getPercent()) * duration / 100000)
    if remaining > 0 then
      progressRect.label:setText(remaining .. 's')
      progressRect.label:setVisible(true)
    else
      progressRect.label:setVisible(false)
    end
  end

  if progressRect:getPercent() < 100 then
    removeEvent(progressRect.event)

    progressRect.event = scheduleEvent(function() 
      if not progressRect.callback then return end
      progressRect.callback[ProgressCallback.update]() 
    end, 100)
  else
    if progressRect.label then
      progressRect.label:setVisible(false)
    end
    progressRect.callback[ProgressCallback.finish]()
  end
end

function isGroupCooldownIconActive(groupId)
  return groupCooldown[groupId]
end

function isCooldownIconActive(iconId)
  return cooldown[iconId]
end

function onSpellCooldown(iconId, duration)
  local icon = loadIcon(iconId)
  if not icon then
    return
  end
  icon:setParent(cooldownPanel)

  local progressRect = icon:getChildById(iconId)
  if not progressRect then
    progressRect = g_ui.createWidget('SpellProgressRect', icon)
    progressRect:setId(iconId)
    progressRect.icon = icon
    progressRect:fill('parent')
  else
    progressRect:setPercent(0)
  end

  local label = icon:getChildById('spellCooldownLabel')
  if not label then
    label = g_ui.createWidget('SpellCooldownLabel', icon)
    label:setId('spellCooldownLabel')
  end
  progressRect.label = label
  local spell, profile, spellName = Spells.getSpellByIcon(iconId)
  progressRect:setTooltip(spellName)

  local updateFunc = function()
    updateCooldown(progressRect, duration)
  end
  local finishFunc = function()
    removeCooldown(progressRect)
    cooldown[iconId] = false
  end
  initCooldown(progressRect, updateFunc, finishFunc)
  cooldown[iconId] = true
  cooldowns[progressRect] = true
end

function onSpellGroupCooldown(groupId, duration)
  if not SpellGroups[groupId] then return end

  local icon = contentsPanel:getChildById('groupIcon' .. SpellGroups[groupId])
  if not icon then return end
  
  local progressRect = icon:getChildById('progressRect' .. SpellGroups[groupId])
  if icon then
    icon:setOn(true)
    removeEvent(icon.event)
  end

  progressRect.icon = icon
  if progressRect then
    progressRect.label = icon:getChildById('cooldownLabel' .. SpellGroups[groupId])
    removeEvent(progressRect.event)
    local updateFunc = function()
      updateCooldown(progressRect, duration)
    end
    local finishFunc = function()
      turnOffCooldown(progressRect)
      groupCooldown[groupId] = false
    end
    initCooldown(progressRect, updateFunc, finishFunc)
    groupCooldown[groupId] = true
  end
end
