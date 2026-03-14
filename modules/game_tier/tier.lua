OPCODE_TIER = 116

tierWindow = nil
tierResultWindow = nil
upgradeBtn = nil
transferBtn = nil
itemList = nil

local itemsData = {}
local selectedIndex = nil

function init()
  connect(g_game, {
    onGameEnd = hide
  })

  tierWindow = g_ui.displayUI('tier')
  tierWindow:hide()
  
  tierResultWindow = g_ui.displayUI('tier_result')
  tierResultWindow:hide()
  
  itemList = tierWindow:recursiveGetChildById('itemList')
  upgradeBtn = tierWindow:recursiveGetChildById('upgradeBtn')
  

  ProtocolGame.registerExtendedOpcode(OPCODE_TIER, onExtendedOpcode)
end

function terminate()
  disconnect(g_game, {
    onGameEnd = hide
  })
  ProtocolGame.unregisterExtendedOpcode(OPCODE_TIER)

  if tierWindow then
    tierWindow:destroy()
  end
  
  if tierResultWindow then
    tierResultWindow:destroy()
  end
  
  tierWindow = nil
  tierResultWindow = nil
  upgradeBtn = nil
  transferBtn = nil
  itemList = nil
end

function toggle()
  if tierWindow:isVisible() then
    hide()
  else
    show()
  end
end

function show()
  if not g_game.isOnline() then return end
  tierWindow:show()
  tierWindow:raise()
  tierWindow:focus()
  
  local protocol = g_game.getProtocolGame()
  if protocol then
    protocol:sendExtendedOpcode(OPCODE_TIER, json.encode({action="fetch"}))
  end
end

function hide()
  if tierWindow then
    tierWindow:hide()
    clearDetails()
  end
end

function onExtendedOpcode(protocol, code, buffer)
  if code ~= OPCODE_TIER then return end
  
  local json_status, json_data = pcall(function() return json.decode(buffer) end)
  if not json_status then return end
  
  if json_data.action == "fetch" then
    updateItemsList(json_data.items, json_data.protectionCount, json_data.protectionClientId)
  elseif json_data.action == "open" then
    show()
  elseif json_data.action == "response" then
    showResultWindow(json_data.success, json_data.message, json_data.oldTier, json_data.newTier, json_data.clientId)
    -- Refresh list
    local p = g_game.getProtocolGame()
    if p then
      p:sendExtendedOpcode(OPCODE_TIER, json.encode({action="fetch"}))
    end
  end
end

function clearDetails()
  local details = tierWindow:recursiveGetChildById('detailsPanel')
  details:getChildById('selectedItem'):setItemId(0)
  details:getChildById('selectedItemName'):setText('Selecione um item da lista')
  
  local c1p = details:recursiveGetChildById('cost1Panel')
  c1p:getChildById('cost1Item'):setItemId(0)
  c1p:getChildById('cost1Label'):setText('- | -')
  
  local c2p = details:recursiveGetChildById('cost2Panel')
  c2p:getChildById('cost2Item'):setItemId(0)
  c2p:getChildById('cost2Label'):setText('- | -')
  
  upgradeBtn:setEnabled(false)

  
  selectedIndex = nil
end

function updateItemsList(items, protectionCount, protectionClientId)
  itemList:destroyChildren()
  itemsData = items
  
  local cb = tierWindow:recursiveGetChildById('protectionCheckBox')
  local pItem = tierWindow:recursiveGetChildById('protectionItem')
  if pItem and protectionClientId then
    pItem:setItemId(protectionClientId)
  end
  
  if cb then
    local count = protectionCount or 0
    cb:setText('Proteger o upgrade')
    if count == 0 then
      cb:setChecked(false)
      cb:setEnabled(false)
    else
      cb:setEnabled(true)
    end
  end
  
  clearDetails()
  
  if not items then return end
  
  for i, itemData in ipairs(items) do
    local itemBox = g_ui.createWidget('TierListLabel', itemList)
    itemBox:setItemId(itemData.clientId or itemData.id)
    
    local tierIcon = itemBox:getChildById('tierId')
    if not tierIcon then
      tierIcon = g_ui.createWidget('UIWidget', itemBox)
      tierIcon:setId('tierId')
      tierIcon:addAnchor(AnchorTop, 'parent', AnchorTop)
      tierIcon:addAnchor(AnchorRight, 'parent', AnchorRight)
      tierIcon:setMarginTop(1)
      tierIcon:setMarginRight(1)
      tierIcon:setSize({width = 9, height = 8})
      tierIcon:setPhantom(true)
    end
    
    if itemData.tier > 0 and itemData.tier <= 10 then
      tierIcon:setImageSource('/images/ui/tier/object-tier-' .. itemData.tier .. '.png')
      tierIcon:setVisible(true)
    else
      tierIcon:setVisible(false)
    end
    
    local countLabel = itemBox:getChildById('countLabel')
    if not countLabel then
      countLabel = g_ui.createWidget('Label', itemBox)
      countLabel:setId('countLabel')
      countLabel:addAnchor(AnchorBottom, 'parent', AnchorBottom)
      countLabel:addAnchor(AnchorRight, 'parent', AnchorRight)
      countLabel:setMarginBottom(1)
      countLabel:setMarginRight(2)
      countLabel:setFont('verdana-11px-rounded')
      countLabel:setColor('#f0f0f0ff')
    end
    
    if itemData.count > 1 then
      countLabel:setText(itemData.count)
      countLabel:setVisible(true)
    else
      countLabel:setVisible(false)
    end
    
    itemBox.itemIndex = i
    itemBox.onMouseRelease = function()
      selectItem(i)
    end
  end
end

function selectItem(index)
  selectedIndex = index
  local data = itemsData[index]
  
  local details = tierWindow:recursiveGetChildById('detailsPanel')
  local selItemWidget = details:getChildById('selectedItem')
  selItemWidget:setItemId(data.clientId or data.id)
  local tierIcon = selItemWidget:getChildById('tierId')
  if not tierIcon then
    tierIcon = g_ui.createWidget('UIWidget', selItemWidget)
    tierIcon:setId('tierId')
    tierIcon:addAnchor(AnchorTop, 'parent', AnchorTop)
    tierIcon:addAnchor(AnchorRight, 'parent', AnchorRight)
    tierIcon:setMarginTop(1)
    tierIcon:setMarginRight(1)
    tierIcon:setSize({width = 9, height = 8})
    tierIcon:setPhantom(true)
  end
  
  if data.tier > 0 and data.tier <= 10 then
    tierIcon:setImageSource('/images/ui/tier/object-tier-' .. data.tier .. '.png')
    tierIcon:setVisible(true)
  else
    tierIcon:setVisible(false)
  end
  local children = itemList:getChildren()
  for _, child in ipairs(children) do
    child:setChecked(child.itemIndex == index)
  end
  
  local formattedName = data.name:gsub("(%a)([%w_']*)", function(first, rest) return first:upper() .. rest:lower() end)
  details:getChildById('selectedItemName'):setText(formattedName .. "\n(Tier " .. data.tier .. ")")
  
  local c1p = details:recursiveGetChildById('cost1Panel')
  c1p:getChildById('cost1Item'):setItemId(data.cost1ClientId or data.cost1Id)
  local c1Label = c1p:getChildById('cost1Label')
  c1Label:setText(data.cost1Owned .. " | " .. data.cost1Needed)
  if data.cost1Owned >= data.cost1Needed then
    c1Label:setColor('#00ff00')
  else
    c1Label:setColor('#ff0000')
  end
  
  local c2p = details:recursiveGetChildById('cost2Panel')
  if data.cost2Id and data.cost2Id > 0 then
    c2p:getChildById('cost2Item'):setItemId(data.cost2ClientId or data.cost2Id)
    local c2Label = c2p:getChildById('cost2Label')
    c2Label:setText(data.cost2Owned .. " | " .. data.cost2Needed)
    if data.cost2Owned >= data.cost2Needed then
      c2Label:setColor('#00ff00')
    else
      c2Label:setColor('#ff0000')
    end
    c2p:show()
  else
    c2p:hide()
  end
  
  local canUpgrade = data.cost1Owned >= data.cost1Needed and (not data.cost2Id or data.cost2Id == 0 or data.cost2Owned >= data.cost2Needed)
  upgradeBtn:setEnabled(canUpgrade)
end

function requestUpgrade()
  if not selectedIndex then return end
  local data = itemsData[selectedIndex]
  
  local cb = tierWindow:recursiveGetChildById('protectionCheckBox')
  local useProtection = cb and cb:isChecked() or false
  
  local protocol = g_game.getProtocolGame()
  if protocol then
    protocol:sendExtendedOpcode(OPCODE_TIER, json.encode({
      action = "upgrade",
      id = data.id,
      tier = data.tier,
      useProtection = useProtection
    }))
    hide()
  end
end

function requestTransfer()
  modules.game_textmessage.displayMessage(MessageModes.Failure, "Funcionalidade ainda não disponível.")
end

function showResultWindow(success, msg, oldTier, newTier, clientId)
  if not tierResultWindow then return end
  
  local resultLabel = tierResultWindow:recursiveGetChildById('resultLabel')
  local itemIcon = tierResultWindow:recursiveGetChildById('itemIcon')
  local tierLabel = tierResultWindow:recursiveGetChildById('tierLabel')
  
  if success then
    resultLabel:setText('Seu item passou de "Tier ' .. (oldTier or 0) .. '" para "Tier ' .. (newTier or 0) .. '"!')
    resultLabel:setColor('#55ff55')
  else
    resultLabel:setText('A forja falhou!\n\n' .. (msg or ''))
    resultLabel:setColor('#ff5555')
  end
  
  if clientId then
    itemIcon:setItemId(clientId)
  end
  
  local t = newTier or oldTier or 0
  
  local tierIcon = itemIcon:getChildById('tierId')
  if not tierIcon then
    tierIcon = g_ui.createWidget('UIWidget', itemIcon)
    tierIcon:setId('tierId')
    tierIcon:addAnchor(AnchorTop, 'parent', AnchorTop)
    tierIcon:addAnchor(AnchorRight, 'parent', AnchorRight)
    tierIcon:setMarginTop(2)
    tierIcon:setMarginRight(2)
    tierIcon:setSize({width = 13, height = 12})
    tierIcon:setPhantom(true)
  end
  
  if t > 0 and t <= 10 then
    tierIcon:setImageSource('/images/ui/tier/object-tier-' .. t .. '.png')
    tierIcon:setVisible(true)
  else
    tierIcon:setVisible(false)
  end
  if t > 0 then
    tierLabel:setText('Tier ' .. t)
    tierLabel:setVisible(true)
  else
    tierLabel:setVisible(false)
  end
  
  -- Espera 1.5 segundos (1500 ms) para a rolagem de dados e o magicEffect passarem
  scheduleEvent(function()
    if tierResultWindow then
      tierResultWindow:show()
      tierResultWindow:raise()
      tierResultWindow:focus()
    end
  end, 1500)
end
