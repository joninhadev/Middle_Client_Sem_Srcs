local OPCODE = 61
local window, creatureBarHP, creatureHP, creatureName = nil
local focusedBoss = 0
local focusedMob = 0

bossBarEnabled = true

local bossNames = {
  "Emperium",
}

local function checkBossName(name)
  if not name then return false end
  for _, bossName in ipairs(bossNames) do
    if string.lower(name) == string.lower(bossName) then
      return true
    end
  end
  return false
end

local function isOnlyCreature(creature)
  if not creature then return false end

  if creature.isPlayer and creature:isPlayer() then
    return false
  end
  return true
end

function init()
  connect(g_game, {
    onGameStart = create,
    onGameEnd = destroy,
    onAttackingCreatureChange = onAttackingCreatureChange,
    onAppear = onCreatureAppear,
    onDisappear = onCreatureDisappear
  })
  connect(Creature, {
    onHealthPercentChange = onHealthPercentChange,
    onSpecialPercentChange = onSpecialPercentChange,
    onAppear = onCreatureAppear,
    onDisappear = onCreatureDisappear
  })

  if g_game.isOnline() then
    create()
  end
end

function terminate()
  disconnect(g_game, {
    onGameStart = create,
    onGameEnd = destroy,
    onAttackingCreatureChange = onAttackingCreatureChange,
    onAppear = onCreatureAppear,
    onDisappear = onCreatureDisappear
  })
  disconnect(Creature, {
    onHealthPercentChange = onHealthPercentChange,
    onSpecialPercentChange = onSpecialPercentChange,
    onAppear = onCreatureAppear,
    onDisappear = onCreatureDisappear
  })
  destroy()
end

function create()
  if window then
    return
  end

  window = g_ui.loadUI("bossbar", modules.game_interface.getMapPanel())
  window:hide()

  creatureBarHP = window:recursiveGetChildById("creatureBarHP")
  creatureName = window:recursiveGetChildById("creatureName")
  creatureHP = window:recursiveGetChildById("creatureHP")
  creatureSpecial = window:recursiveGetChildById("special")
end

function destroy()
  if window then
    window:destroy()

    window = nil
    creatureBarHP = nil
    creatureHP = nil
    creatureOutfit = nil
    creatureName = nil
    creatureSpecial = nil
    focusedBoss = 0
    focusedMob = 0
  end
end

function onExtendedOpcode(protocol, code, buffer)
  if not g_game.isOnline() then
    return
  end

  local json_status, json_data = pcall(function()
    return json.decode(buffer)
  end)

  if not json_status then
    g_logger.error("[Boss Bar] JSON error: " .. data)
    return false
  end

  if json_data.action == "show" then
    show(json_data.data)
  elseif json_data.action == "hide" then
    hide()
  end
end

function show(data)
  focusedBoss = data.cid
  creatureName:setText(data.name)
  creatureHP:setText(data.health .. "%")
  creatureSpecial:setPercent(data.health)
  window:show()
end

function hide()
  focusedBoss = 0
  focusedMob = 0
  window:hide()
end

function setEnabled(value)
  bossBarEnabled = value
end

function onAttackingCreatureChange(creature, oldCreature)
  if not bossBarEnabled then
    return hide()
  end

  if focusedBoss ~= 0 then
    return
  end

  if creature and isOnlyCreature(creature) and checkBossName(creature:getName()) then
    creatureName:setText(creature:getName())
    creatureHP:setText(creature:getHealthPercent() .. "%")
    creatureSpecial:setPercent(creature:getHealthPercent())
    focusedMob = creature:getId()
    window:show()
  else
    hide()
  end
end

function onCreatureAppear(creature)
  if not bossBarEnabled then
    return
  end

  if focusedBoss ~= 0 then
    return
  end

  if creature and isOnlyCreature(creature) and checkBossName(creature:getName()) then
    creatureName:setText(creature:getName())
    creatureHP:setText(creature:getHealthPercent() .. "%")
    creatureSpecial:setPercent(creature:getHealthPercent())
    focusedMob = creature:getId()
    window:show()
  end
end

function onCreatureDisappear(creature)
  if bossBarEnabled and (creature:getId() == focusedMob or creature:getId() == focusedBoss) then
    hide()
  end
end

function onHealthPercentChange(creature, health)
  if not bossBarEnabled then
    return hide()
  end

  if focusedBoss == creature:getId() or focusedMob == creature:getId() then
    creatureHP:setText(health .. "%")
    creatureSpecial:setPercent(health)
  end
end

function onSpecialPercentChange(creature, special)
  if special > 0 then
    if not creatureSpecial:isVisible() then
      creatureSpecial:setVisible(true)
    end
    creatureSpecial:setPercent(special)
  else
    creatureSpecial:setVisible(false)
  end
end
