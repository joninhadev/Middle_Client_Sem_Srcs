rewardWindow = nil
rewardButton = nil
selectedRewardIndex = nil

-- Configuration for the rewards
-- id: Item ID (e.g., 2060 for Exercise Weapon)
-- count: Charges/Amount
-- Using 2060 as requested example. You can change these IDs to other exercise weapons.
-- id: Server ID
-- clientId: Client ID (Sprite ID) - Optional, use if Server ID doesn't match sprite
local rewards = {
  { id = 33082, clientId = 28552, count = 1000, name = "Exercise Sword" },
  { id = 33083, clientId = 28553, count = 1000, name = "Exercise Axe" },
  { id = 33084, clientId = 28554, count = 1000, name = "Exercise Club" },
  { id = 33085, clientId = 28555, count = 1000, name = "Exercise Bow" }, 
  { id = 33086, clientId = 28556, count = 1000, name = "Exercise Rod" },
  { id = 33087, clientId = 28557, count = 1000, name = "Exercise Wand" }
}

local OpcodeID = 50
local isRewardAvailable = false

function init()
  connect(g_game, { onGameStart = online,
                    onGameEnd = offline })

  ProtocolGame.registerExtendedOpcode(OpcodeID, onExtendedOpcode)
  
  rewardWindow = g_ui.displayUI('game_reward')
  rewardWindow:hide()

  -- Create Notification Icon (Floating Button)
  rewardNotification = g_ui.createWidget('UIWidget', modules.game_interface.getMapPanel())
  rewardNotification:setImageSource('/modules/game_reward/images/reward')
  rewardNotification:setSize({width = 64, height = 64})
  -- Use addAnchor (standard OTClient API)
  rewardNotification:addAnchor(AnchorTop, 'parent', AnchorTop)
  rewardNotification:addAnchor(AnchorHorizontalCenter, 'parent', AnchorHorizontalCenter)
  rewardNotification:setMarginTop(100)
  -- rewardNotification:setMarginRight(10) -- Removed right margin
  rewardNotification:hide()
  
  rewardNotification.onClick = function()
      toggle() -- Use toggle to handle open/close and image state
  end
  
  -- Delay loading rewards until game start or manual toggle to ensure UI is ready
  scheduleEvent(loadRewards, 100) 
end

function terminate()
  disconnect(g_game, { onGameStart = online,
                       onGameEnd = offline })
                       
  ProtocolGame.unregisterExtendedOpcode(OpcodeID)

  if rewardWindow then
    rewardWindow:destroy()
    rewardWindow = nil
  end

  if rewardNotification then
    rewardNotification:destroy()
    rewardNotification = nil
  end

  if rewardButton then
      rewardButton:destroy()
      rewardButton = nil
  end
end

function online()
end

function offline()
  if rewardWindow then
    rewardWindow:hide()
  end
  if rewardNotification then
      rewardNotification:hide()
  end
end

function onExtendedOpcode(protocol, code, buffer)
  if code ~= OpcodeID then return end
  local json_status, json_data = pcall(function() return json.decode(buffer) end)
  if not json_status then return end

  local action = json_data.action -- 'open' or 'close' or 'disable'

  if action == 'open' then
    isRewardAvailable = true -- Flag that reward is ready
    if rewardNotification then
      rewardNotification:show()
      rewardNotification:setImageSource('/modules/game_reward/images/reward.png') -- Default closed/available icon
    end
    -- Window remains hidden until clicked
    if rewardWindow and rewardWindow:isVisible() then
        -- If it was visible for some reason, update icon to open? No, 'open' usually means initialize.
        -- Let's stick to hidden window, visible notification.
        rewardWindow:hide() 
    end
  elseif action == 'close' then
    -- Server wants to close window (maybe timed out or other logic)
    if rewardWindow and rewardWindow:isVisible() then
      rewardWindow:hide()
    end
    -- If purely 'close', revert notification to available icon
    if isRewardAvailable and rewardNotification then
        rewardNotification:show()
        rewardNotification:setImageSource('/modules/game_reward/images/reward.png')
    end
  elseif action == 'disable' then
    isRewardAvailable = false
    if rewardWindow then
      rewardWindow:hide()
    end
    if rewardNotification then
      rewardNotification:hide()
    end
  end
end

function toggle()
  if rewardWindow:isVisible() then
    rewardWindow:hide()
    -- Window Closed: Revert to 'reward.png' if available
    if isRewardAvailable and rewardNotification then
        rewardNotification:show()
        rewardNotification:setImageSource('/modules/game_reward/images/reward.png')
    end
  else
    if isRewardAvailable then
        -- Window Open: Change to 'reward_open.png'
        if rewardNotification then
            rewardNotification:show()
            rewardNotification:setImageSource('/modules/game_reward/images/reward_open.png')
        end
        rewardWindow:show()
        rewardWindow:focus()
        loadRewards()
    end
  end
end

function loadRewards()
  if not rewardWindow then return end
  local rewardList = rewardWindow:getChildById('rewardList')
  if not rewardList then return end
  
  rewardList:destroyChildren()
  selectedRewardIndex = nil -- Reset selection

  for i, reward in ipairs(rewards) do
    local widget = g_ui.createWidget('RewardItemWidget', rewardList)
    widget:setId('reward' .. i)
    widget:setTooltip(reward.name)

    -- Item Display
    -- Since RewardItemWidget < UIItem, we can use setItem directly on it.
    -- The background image defined in OTUI will be drawn. 
    -- UIItem usually draws item on top.
    
    local displayId = reward.clientId or reward.id
    local item = Item.create(displayId)
    
    if item then
      widget:setItem(item)
    else
      widget:setItemId(displayId)
    end

    widget:setItemCount(reward.count)
    widget:setShowCount(true)
    widget:setVirtual(true)
    
    -- Selection logic: we need to highlight it.
    -- Default border is image-border (texture border), not style border.
    -- We can change style border? Or add a selection overlay?
    -- Let's try setting BorderWidth on the widget itself as before.
    widget:setBorderWidth(0) -- Start with no extra border (image-border handles the background look)
                             -- Wait, image-border in OTUI slices the image.
                             -- setBorderWidth adds a solid line border.
                             
    widget.onClick = function() selectReward(i) end
    
    -- Add check icon
    local checkIcon = g_ui.createWidget('UIWidget', widget)
    checkIcon:setId('checkIcon')
    checkIcon:setImageSource('/modules/game_reward/images/yes.png')
    checkIcon:setSize({width = 12, height = 12})
    checkIcon:addAnchor(AnchorBottom, 'parent', AnchorBottom)
    checkIcon:addAnchor(AnchorRight, 'parent', AnchorRight)
    checkIcon:setMarginBottom(2)
    checkIcon:setMarginRight(2)
    checkIcon:setPhantom(true) -- Pass clicks through
    checkIcon:hide()
  end
end

function selectReward(index)
  selectedRewardIndex = index
  local rewardList = rewardWindow:getChildById('rewardList')
  if not rewardList then return end
  
  -- Update visuals
  for i = 1, #rewards do
    local widget = rewardList:getChildById('reward' .. i)
    if widget then
      local checkIcon = widget:getChildById('checkIcon')
      
      if i == index then
        widget:setBorderWidth(2)
        widget:setBorderColor('#95ffb0ff') -- Highlight selected
        if checkIcon then checkIcon:show() end
      else
        widget:setBorderWidth(1)
        widget:setBorderColor('alpha')
        if checkIcon then checkIcon:hide() end
      end
    end
  end
end

function claimReward()
  if not selectedRewardIndex then
    -- Show error or feedback that no reward is selected
    local infoLabel = rewardWindow:getChildById('infoLabel')
    if infoLabel then
      infoLabel:setText(tr('Por favor, selecione uma recompensa primeiro.'))
      infoLabel:setColor('red')
      scheduleEvent(function() 
        if infoLabel then 
          infoLabel:setText(tr('Selecione a recompensa:')) 
          infoLabel:setColor('white') 
        end 
      end, 2000)
    end
    return
  end
  
  local selectedReward = rewards[selectedRewardIndex]
  local protocolGame = g_game.getProtocolGame()
  if protocolGame then
     protocolGame:sendExtendedOpcode(OpcodeID, json.encode({action = 'claim', id = selectedReward.id}))
  end

  rewardWindow:hide()
end
