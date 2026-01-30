local CODE = 107

-- Adicionei a tabela de ícones aqui
local ICON_PATHS = {
  ["Physical Protection"] = "/images/ui/prot_physical",
  ["Energy Protection"]   = "/images/ui/prot_energy",
  ["Earth Protection"]    = "/images/ui/prot_earth",
  ["Fire Protection"]     = "/images/ui/prot_fire",
  ["Life Drain Protection"] = "/images/ui/prot_lifedrain",
  ["Mana Drain Protection"] = "/images/ui/prot_manadrain",
  ["Healing Protection"]  = "/images/ui/prot_healing",
  ["Drown Protection"]    = "/images/ui/prot_drown",
  ["Ice Protection"]      = "/images/ui/prot_ice",
  ["Holy Protection"]     = "/images/ui/prot_holy",
  ["Death Protection"]    = "/images/ui/prot_death",
  ["Default"]             = "/images/ui/prot_default"
}

local IInventorySlotStyles = {
  [InventorySlotHead] = "HeadSlot",
  [InventorySlotNeck] = "NeckSlot",
  [InventorySlotBack] = "BackSlot",
  [InventorySlotBody] = "BodySlot",
  [InventorySlotRight] = "RightSlot",
  [InventorySlotLeft] = "LeftSlot",
  [InventorySlotLeg] = "LegSlot",
  [InventorySlotFeet] = "FeetSlot",
  [InventorySlotFinger] = "FingerSlot",
  [InventorySlotAmmo] = "AmmoSlot",
}

local inspectWindow = nil

function init()
  connect(g_game, { onGameStart = create, onGameEnd = destroy })
  ProtocolGame.registerExtendedOpcode(CODE, onExtendedOpcode)
  if g_game.isOnline() then
    create()
  end
end

function terminate()
  disconnect(g_game, { onGameStart = create, onGameEnd = destroy })
  ProtocolGame.unregisterExtendedOpcode(CODE, onExtendedOpcode)
  destroy()
end

function create()
  inspectWindow = g_ui.displayUI("inspect")
  inspectWindow:hide()
end

function destroy()
  if inspectWindow then
    inspectWindow:destroy()
    inspectWindow = nil
  end
end

function show()
  if not inspectWindow then return end
  inspectWindow:show()
  inspectWindow:raise()
  inspectWindow:focus()
end

function hide()
  if not inspectWindow then return end
  inspectWindow:hide()
end

function toggle()
  if not inspectWindow then return end
  if inspectWindow:isVisible() then
    return hide()
  end
  show()
end

function onExtendedOpcode(protocol, code, buffer)
  local json_status, json_data = pcall(function() return json.decode(buffer) end)

  if not json_status then
    g_logger.error("[Inspect] JSON error: " .. buffer)
    return false
  end

  local action = json_data.action
  local data = json_data.data

  if action == "stats" then
    addStats(data)
  elseif action == "item" then
    addItem(data.slot, data.item or data.itemId, data.tier, data.count)
  end
end

function inspect(creature)
  if creature then
    local protocolGame = g_game.getProtocolGame()
    if protocolGame then
      protocolGame:sendExtendedOpcode(CODE, json.encode({action = "inspect", data = creature:getName()}))
    end

    local outfitCreatureBox = inspectWindow:recursiveGetChildById("outfitInspectBox")
    if outfitCreatureBox then
        outfitCreatureBox:setCreature(creature)
    end
    
    show() -- Garante que abre a janela
  end
end

-- Helper local caso não seja global
function comma_value(n)
	local left,num,right = string.match(n,'^([^%d]*%d)(%d*)(.-)$')
	return left..(num:reverse():gsub('(%d%d%d)','%1,'):reverse())..right
end

function addStats(data)
  -- Atualiza textos simples (Name, Guild, etc)
  for key, value in pairs(data) do
    local w = inspectWindow:recursiveGetChildById(key)
    if w then
      w:setText(type(value) == "number" and comma_value(value) or value)
    end
  end

  -- Reputations
  if data.repDwarfRank then
    local element = inspectWindow:recursiveGetChildById('repDwarf')
    if element then
      element.repDwarfName:setText(data.repDwarfName or "---")
      element.repDwarfRank:setText(data.repDwarfRank.text or "0")
      element.repDwarfRank:setColor(data.repDwarfRank.color or "#ffffff")
      element.repDwarfBar:setPercent(math.floor(data.repDwarfValue or 0))
      element.repDwarfBar:setBackgroundColor(data.repDwarfRank.color or "#ffffff")
      element.repDwarfBar:setTooltip(tr("%s points to Exalted", 100 - (data.repDwarfValue or 0)))
    end
  end

  local healthBar = inspectWindow:recursiveGetChildById("healthBar")
  if healthBar then
      healthBar:setText(data.health .. "/" .. data.maxHealth)
      healthBar:setValue(data.health, 0, data.maxHealth)
  end
  
  local manaBar = inspectWindow:recursiveGetChildById("manaBar")
  if manaBar then
      manaBar:setText(data.mana .. "/" .. data.maxMana)
      manaBar:setValue(data.mana, 0, data.maxMana)
  end

  for i = 1, #data.skills do
    local skill = data.skills[i]
    local w = inspectWindow:recursiveGetChildById("skill" .. i)
    if w then
      local valueWidget = w:getChildById("value")
      valueWidget:setText(skill.total)
      if skill.bonus > 0 then
        valueWidget:setColor("#008b00")
        w:setTooltip(skill.total - skill.bonus .. " +" .. skill.bonus)
      else
        valueWidget:setColor("#bbbbbb")
        w:removeTooltip()
      end
      local percentWidget = w:getChildById("percent")
      percentWidget:setPercent(math.floor(skill.percent))
      percentWidget:setTooltip(tr("%s percent to go", 100 - skill.percent))
    end
  end

  -- OTHERS / STATS (Protections)
  -- Reset all first
  for i = 1, 10 do
     local w = inspectWindow:recursiveGetChildById("stat" .. i)
     if w then w:setVisible(false) end
  end

  if data.stats then
    for i = 1, #data.stats do
      local stat = data.stats[i]
      local w = inspectWindow:recursiveGetChildById("stat" .. i)
      if w then
        w:setVisible(true)
        
        -- >>> ICON UPDATE (AQUI ESTÁ A MÁGICA) <<<
        local iconWidget = w:getChildById("icon")
        if iconWidget then
            local imagePath = ICON_PATHS[stat.name] or ICON_PATHS["Default"]
            iconWidget:setImageSource(imagePath)
        end
        -- >>> FIM ICON UPDATE <<<

        -- Update NAME
        local nameWidget = w:getChildById("name")
        if nameWidget then
            nameWidget:setText(stat.name)
        end

        -- Update VALUE
        local valueWidget = w:getChildById("value")
        if valueWidget then
            valueWidget:setText(stat.value .. "%")
        end

        -- Update BAR
        local percentWidget = w:getChildById("percent")
        if percentWidget then
            percentWidget:setValue(stat.value, 0, 100)
            percentWidget:setTooltip(stat.value .. "% / 100%")
            
            -- Cores opcionais para ficar bonito
            if stat.name == "Fire Protection" then percentWidget:setBackgroundColor('#FF4444')
            elseif stat.name == "Ice Protection" then percentWidget:setBackgroundColor('#4444FF')
            elseif stat.name == "Earth Protection" then percentWidget:setBackgroundColor('#44FF44')
            elseif stat.name == "Energy Protection" then percentWidget:setBackgroundColor('#AA44FF')
            elseif stat.name == "Death Protection" then percentWidget:setBackgroundColor('#555555')
            elseif stat.name == "Holy Protection" then percentWidget:setBackgroundColor('#FFFF55')
            else percentWidget:setBackgroundColor('#00AA00') end
        end
      end
    end
  end
end

function addItem(slot, item, tier, count)
  local inventoryPanel = inspectWindow:getChildById("inventoryPanel")
  if not inventoryPanel then return end
  
  local itemWidget = inventoryPanel:getChildById("slot" .. slot)
  if not itemWidget then return end

  if item then
    itemWidget:setItemId(item)
    if count and count > 1 then
      itemWidget:setItemCount(count)
    end
    itemWidget:setStyle("InventoryItem")

     local tierWidget = itemWidget:getChildById('tierId')
        
     if not tierWidget then
         tierWidget = g_ui.createWidget('UIWidget', itemWidget)
         tierWidget:setId('tierId')
         tierWidget:addAnchor(AnchorTop, 'parent', AnchorTop)
         tierWidget:addAnchor(AnchorRight, 'parent', AnchorRight)
         tierWidget:setMarginTop(1)
         tierWidget:setMarginRight(1)
         tierWidget:setSize({width = 9, height = 8})
         tierWidget:setPhantom(true)
         tierWidget:setVisible(false)
     end
     
     if tier and tier > 0 and tier <= 10 then
         tierWidget:setImageSource('/images/ui/tier/object-tier-' .. tier .. '.png')
         tierWidget:setVisible(true)
     else
         tierWidget:setVisible(false)
     end
  else
    itemWidget:setItem(nil)
    itemWidget:setStyle(IInventorySlotStyles[slot])

    local tierWidget = itemWidget:getChildById('tierId')
    if tierWidget then
        tierWidget:setVisible(false)
    end
  end
end