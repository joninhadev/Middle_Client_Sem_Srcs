Icons = {}
Icons[PlayerStates.Poison] = { tooltip = tr('You are poisoned'), path = '/images/game/states/poisoned', id = 'condition_poisoned' }
Icons[PlayerStates.Burn] = { tooltip = tr('You are burning'), path = '/images/game/states/burning', id = 'condition_burning' }
Icons[PlayerStates.Energy] = { tooltip = tr('You are electrified'), path = '/images/game/states/electrified', id = 'condition_electrified' }
Icons[PlayerStates.Drunk] = { tooltip = tr('You are drunk'), path = '/images/game/states/drunk', id = 'condition_drunk' }
Icons[PlayerStates.ManaShield] = { tooltip = tr('You are protected by a magic shield'), path = '/images/game/states/magic_shield', id = 'condition_magic_shield' }
Icons[PlayerStates.Paralyze] = { tooltip = tr('You are paralysed'), path = '/images/game/states/slowed', id = 'condition_slowed' }
Icons[PlayerStates.Haste] = { tooltip = tr('You are hasted'), path = '/images/game/states/haste', id = 'condition_haste' }
Icons[PlayerStates.Swords] = { tooltip = tr('You may not logout during a fight'), path = '/images/game/states/logout_block', id = 'condition_logout_block' }
Icons[PlayerStates.Drowning] = { tooltip = tr('You are drowning'), path = '/images/game/states/drowning', id = 'condition_drowning' }
Icons[PlayerStates.Freezing] = { tooltip = tr('You are freezing'), path = '/images/game/states/freezing', id = 'condition_freezing' }
Icons[PlayerStates.Dazzled] = { tooltip = tr('You are dazzled'), path = '/images/game/states/dazzled', id = 'condition_dazzled' }
Icons[PlayerStates.Cursed] = { tooltip = tr('You are cursed'), path = '/images/game/states/cursed', id = 'condition_cursed' }
Icons[PlayerStates.PartyBuff] = { tooltip = tr('You are strengthened'), path = '/images/game/states/strengthened', id = 'condition_strengthened' }
Icons[PlayerStates.PzBlock] = { tooltip = tr('You may not logout or enter a protection zone'), path = '/images/game/states/protection_zone_block', id = 'condition_protection_zone_block' }
Icons[PlayerStates.Pz] = { tooltip = tr('You are within a protection zone'), path = '/images/game/states/protection_zone', id = 'condition_protection_zone' }
Icons[PlayerStates.Bleeding] = { tooltip = tr('You are bleeding'), path = '/images/game/states/bleeding', id = 'condition_bleeding' }
Icons[PlayerStates.Hungry] = { tooltip = tr('You are hungry'), path = '/images/game/states/hungry', id = 'condition_hungry' }

healthInfoWindow = nil
healthBar = nil
manaBar = nil
healthLabel = nil
manaLabel = nil
experienceBar = nil
healthTooltip = 'Your character health is %d out of %d.'
manaTooltip = 'Your character mana is %d out of %d.'
experienceTooltip = 'You have %d%% to advance to level %d.'

overlay = nil
healthCircleFront = nil
manaCircleFront = nil
healthCircle = nil
manaCircle = nil
topHealthBar = nil
topManaBar = nil

barMaxWidth = 115

function init()
  connect(LocalPlayer, { onHealthChange = onHealthChange,
                         onManaChange = onManaChange,
                         onLevelChange = onLevelChange,
                         onStatesChange = onStatesChange })

  connect(g_game, { onGameEnd = offline })

  healthInfoWindow = g_ui.loadUI('healthinfo', modules.game_interface.getRightPanel())
  healthInfoWindow:disableResize()
  
  if not healthInfoWindow.forceOpen then
    healthInfoWindow:open()
  end

  healthBar = healthInfoWindow:recursiveGetChildById('healthBar')
  manaBar = healthInfoWindow:recursiveGetChildById('manaBar')
  healthLabel = healthInfoWindow:recursiveGetChildById('healthLabel')
  manaLabel = healthInfoWindow:recursiveGetChildById('manaLabel')
  experienceBar = healthInfoWindow:recursiveGetChildById('experienceBar')

  overlay = g_ui.createWidget('HealthOverlay', modules.game_interface.getMapPanel())  
  healthCircleFront = overlay:getChildById('healthCircleFront')
  manaCircleFront = overlay:getChildById('manaCircleFront')
  healthCircle = overlay:getChildById('healthCircle')
  manaCircle = overlay:getChildById('manaCircle')
  topHealthBar = overlay:getChildById('topHealthBar')
  topManaBar = overlay:getChildById('topManaBar')
  
  connect(overlay, { onGeometryChange = onOverlayGeometryChange })
  
  -- load condition icons
  for k,v in pairs(Icons) do
    g_textures.preload(v.path)
  end

  if g_game.isOnline() then
    local localPlayer = g_game.getLocalPlayer()
    onHealthChange(localPlayer, localPlayer:getHealth(), localPlayer:getMaxHealth())
    onManaChange(localPlayer, localPlayer:getMana(), localPlayer:getMaxMana())
    onLevelChange(localPlayer, localPlayer:getLevel(), localPlayer:getLevelPercent())
    onStatesChange(localPlayer, localPlayer:getStates(), 0)
  end

  -- Initial setup
  healthInfoWindow:setup()
  
  -- Force height for the borderless look
  healthInfoWindow:setHeight(38) 
  
  if g_app.isMobile() then
    healthInfoWindow:close()
  end
  
  -- Aggressively remove window buttons and frames that might persist from the base class
  local elementsToKill = { 'closeButton', 'minimizeButton', 'lockButton', 'miniwindowTopBar', 'bottomResizeBorder', 'miniwindowScrollBar' }
  for _, id in ipairs(elementsToKill) do
    local widget = healthInfoWindow:recursiveGetChildById(id)
    if widget then
      widget:destroy()
    end
  end
end

function terminate()
  disconnect(LocalPlayer, { onHealthChange = onHealthChange,
                            onManaChange = onManaChange,
                            onLevelChange = onLevelChange,
                            onStatesChange = onStatesChange })

  disconnect(g_game, { onGameEnd = offline })
  disconnect(overlay, { onGeometryChange = onOverlayGeometryChange })
  
  healthInfoWindow:destroy()
  overlay:destroy()
end

function toggle()
  -- icon removed, toggle disabled
  -- healthInfoWindow:open()
end

function toggleIcon(bitChanged)
  local content = healthInfoWindow:recursiveGetChildById('conditionPanel')
  if not content then return end

  local icon = content:getChildById(Icons[bitChanged].id)
  if icon then
    icon:destroy()
  else
    icon = loadIcon(bitChanged, content)
    icon:setParent(content)
  end
end

function loadIcon(bitChanged, content)
  local icon = g_ui.createWidget('ConditionWidget', content)
  icon:setId(Icons[bitChanged].id)
  icon:setImageSource(Icons[bitChanged].path)
  icon:setTooltip(Icons[bitChanged].tooltip)
  return icon
end

function offline()
  local content = healthInfoWindow:recursiveGetChildById('conditionPanel')
  if content then
    content:destroyChildren()
  end
end

-- hooked events
function onMiniWindowClose()
  -- icon removed
end

function onHealthChange(localPlayer, health, maxHealth)
  if health > maxHealth then
    maxHealth = health
  end

  if healthLabel then
    healthLabel:setText(comma_value(health))
  end
  
  if healthBar then
    healthBar:setTooltip(tr(healthTooltip, health, maxHealth))
    
    -- Manual clipping update
    local percent = 1
    if maxHealth > 0 then
      percent = math.max(0, math.min(1, health / maxHealth))
    end
    -- Use barMaxWidth
    local newWidth = math.floor(barMaxWidth * percent)
    
    healthBar:setWidth(newWidth)
    local textureClipWidth = math.floor(90 * percent)
    healthBar:setImageClip({ x = 0, y = 11, width = textureClipWidth, height = 11 })
  end

  if topHealthBar then
    if topHealthBar.setValue then
        topHealthBar:setText(comma_value(health) .. ' / ' .. comma_value(maxHealth))
        topHealthBar:setTooltip(tr(healthTooltip, health, maxHealth))
        topHealthBar:setValue(health, 0, maxHealth)
    end
  end

  local healthPercent = math.floor(g_game.getLocalPlayer():getHealthPercent())
  local Yhppc = math.floor(208 * (1 - (healthPercent / 100)))
  local rect = { x = 0, y = Yhppc, width = 63, height = 208 - Yhppc + 1 }
  
  if healthCircleFront then
    healthCircleFront:setImageClip(rect)
    healthCircleFront:setImageRect(rect)

    if healthPercent > 92 then
      healthCircleFront:setImageColor("#00BC00FF")
    elseif healthPercent > 60 then
      healthCircleFront:setImageColor("#50A150FF")
    elseif healthPercent > 30 then
      healthCircleFront:setImageColor("#A1A100FF")
    elseif healthPercent > 8 then
      healthCircleFront:setImageColor("#BF0A0AFF")
    elseif healthPercent > 3 then
      healthCircleFront:setImageColor("#910F0FFF")
    else
      healthCircleFront:setImageColor("#850C0CFF")
    end
  end
end

function onManaChange(localPlayer, mana, maxMana)
  if mana > maxMana then
    maxMana = mana
  end
  
  if manaLabel then
    manaLabel:setText(comma_value(mana))
  end

  if manaBar then
    manaBar:setTooltip(tr(manaTooltip, mana, maxMana))
    
    local percent = 1
    if maxMana > 0 then
      percent = math.max(0, math.min(1, mana / maxMana))
    end
    
    local newWidth = math.floor(barMaxWidth * percent)
    manaBar:setWidth(newWidth)
    
    local textureClipWidth = math.floor(90 * percent)
    manaBar:setImageClip({ x = 0, y = 22, width = textureClipWidth, height = 11 })
  end

  if topManaBar then
    if topManaBar.setValue then
        topManaBar:setText(comma_value(mana) .. ' / ' .. comma_value(maxMana))
        topManaBar:setTooltip(tr(manaTooltip, mana, maxMana))
        topManaBar:setValue(mana, 0, maxMana)
    end
  end

  local Ymppc = math.floor(208 * (1 - (math.floor((maxMana - (maxMana - mana)) * 100 / maxMana) / 100)))
  local rect = { x = 0, y = Ymppc, width = 63, height = 208 - Ymppc + 1 }
  
  if manaCircleFront then
    manaCircleFront:setImageClip(rect)
    manaCircleFront:setImageRect(rect)
  end
end

function onLevelChange(localPlayer, value, percent)
  if experienceBar and experienceBar.setPercent then
    experienceBar:setText(percent .. '%')
    experienceBar:setTooltip(tr(experienceTooltip, percent, value+1))
    experienceBar:setPercent(percent)
  end
end

function onStatesChange(localPlayer, now, old)
  if now == old then return end

  local bitsChanged = bit32.bxor(now, old)
  for i = 1, 32 do
    local pow = math.pow(2, i-1)
    if pow > bitsChanged then break end
    local bitChanged = bit32.band(bitsChanged, pow)
    if bitChanged ~= 0 then
      toggleIcon(bitChanged)
    end
  end
end

function onOverlayGeometryChange() 
  if not overlay then return end
  if g_app.isMobile() then
    topHealthBar:setMarginTop(35)
    topManaBar:setMarginTop(35)
    local width = overlay:getWidth() 
    local margin = width / 3 + 10
    topHealthBar:setMarginLeft(margin)
    topManaBar:setMarginRight(margin)    
    return
  end

  local classic = g_settings.getBoolean("classicView")
  local minMargin = 40
  if classic then
    topHealthBar:setMarginTop(15)
    topManaBar:setMarginTop(15)
  else
    if overlay:getParent() then
      topHealthBar:setMarginTop(45 - overlay:getParent():getMarginTop())
      topManaBar:setMarginTop(45 - overlay:getParent():getMarginTop())  
    end
    minMargin = 200
  end

  local height = overlay:getHeight()
  local width = overlay:getWidth()
     
  topHealthBar:setMarginLeft(math.max(minMargin, (width - height + 50) / 2 + 2))
  topManaBar:setMarginRight(math.max(minMargin, (width - height + 50) / 2 + 2))
end