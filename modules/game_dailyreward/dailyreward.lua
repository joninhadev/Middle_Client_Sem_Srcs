dailyRewardWindow = nil
freeRewardsPanel = nil
premiumRewardsPanel = nil
claimButton = nil
statusLabel = nil
timerLabel = nil

local OPCODE_DAILY_REWARD = 118
local countdownEvent = nil
local timeRemaining = 0
local claimablePanels = {}

function init()
  connect(g_game, { onGameEnd = hide })
  connect(g_game, { onTextMessage = onTextMessage })
  ProtocolGame.registerExtendedOpcode(OPCODE_DAILY_REWARD, onExtendedOpcode)

  dailyRewardWindow = g_ui.displayUI('dailyreward')
  dailyRewardWindow:hide()
  
  freeRewardsPanel = dailyRewardWindow:getChildById('freeRewardsPanel')
  premiumRewardsPanel = dailyRewardWindow:getChildById('premiumRewardsPanel')
  claimButton = dailyRewardWindow:getChildById('claimButton')
  statusLabel = dailyRewardWindow:getChildById('statusLabel')
  timerLabel = dailyRewardWindow:getChildById('timerLabel')
end

function terminate()
  disconnect(g_game, { onGameEnd = hide })
  disconnect(g_game, { onTextMessage = onTextMessage })
  ProtocolGame.unregisterExtendedOpcode(OPCODE_DAILY_REWARD, onExtendedOpcode)
  
  if countdownEvent then
    removeEvent(countdownEvent)
    countdownEvent = nil
  end
  
  dailyRewardWindow:destroy()
end

function show()
  dailyRewardWindow:show()
  dailyRewardWindow:raise()
  dailyRewardWindow:focus()
end

function hide()
  dailyRewardWindow:hide()
end

function formatTime(seconds)
  local h = math.floor(seconds / 3600)
  local m = math.floor((seconds % 3600) / 60)
  local s = seconds % 60
  return string.format("%02d:%02d:%02d", h, m, s)
end

function updateTimer()
  if timeRemaining > 0 then
    timeRemaining = timeRemaining - 1
    timerLabel:setText("Time left for next reward: " .. formatTime(timeRemaining))
    countdownEvent = scheduleEvent(updateTimer, 1000)
  else
    timerLabel:setText("You can claim your reward now!")
    countdownEvent = nil
    -- Optional: If window is open and timer reaches 0, maybe enable button? 
    -- But we need server states. Often it's enough to ask them to reopen.
  end
end

function onExtendedOpcode(protocol, code, buffer)
  if code ~= OPCODE_DAILY_REWARD then return end
  
  local status, data = pcall(function() return json.decode(buffer) end)
  if not status or not data then return end
  
  if data.action == "open" or data.action == "update" then
    updateUI(data.currentDay, data.canClaim, data.isPremium, data.rewards, data.timeRemaining)
    if data.action == "open" then
      show()
    end
  end
end

function updateUI(currentDay, canClaim, isPremium, rewardsData, remainingTime)
  if not dailyRewardWindow then return end
  
  local accountStatus = isPremium and "Premium Account" or "Free Account"
  statusLabel:setText("Account Status: " .. accountStatus .. " | Current Streak: Day " .. currentDay)
  statusLabel:setColor(isPremium and '#00ff00' or '#cccccc')
  
  timeRemaining = remainingTime or 0
  if countdownEvent then
    removeEvent(countdownEvent)
    countdownEvent = nil
  end
  
  if canClaim then
    timerLabel:setText("You can claim your reward now!")
  else
    updateTimer()
  end
  
  claimablePanels = {}
  claimButton:setEnabled(false)
  
  freeRewardsPanel:destroyChildren()
  premiumRewardsPanel:destroyChildren()
  
  -- Create Free row
  for day = 1, 7 do
    local panel = g_ui.createWidget('DayPanel', freeRewardsPanel)
    panel:getChildById('dayLabel'):setText(string.format("Dia %02d", day))
    
    local reward = rewardsData.free and rewardsData.free[day]
    if reward then
      panel:getChildById('rewardItem'):setItemId(reward.clientId)
      panel:getChildById('rewardItem'):setItemCount(reward.count)
      panel:getChildById('rewardItem'):setTooltip("Free Reward: " .. reward.count .. "x")
    end
    
    setupPanelVisuals(panel, day, currentDay, canClaim, true)
  end
  
  -- Create Premium row
  for day = 1, 7 do
    local panel = g_ui.createWidget('DayPanel', premiumRewardsPanel)
    panel:getChildById('dayLabel'):setText(string.format("Dia %02d", day))
    if not isPremium then
      panel:getChildById('dayLabel'):setColor('#ff5555')
    end
    
    local reward = rewardsData.premium and rewardsData.premium[day]
    if reward then
      panel:getChildById('rewardItem'):setItemId(reward.clientId)
      panel:getChildById('rewardItem'):setItemCount(reward.count)
      panel:getChildById('rewardItem'):setTooltip("Premium Reward: " .. reward.count .. "x")
    end
    
    setupPanelVisuals(panel, day, currentDay, canClaim, isPremium)
    
  end
end

function setupPanelVisuals(panel, day, currentDay, canClaim, isActiveTree)
  local checkLabel = panel:getChildById('checkLabel')
  local rewardItem = panel:getChildById('rewardItem')
  
  panel:setBorderWidth(0)
  panel:setOpacity(1.0)
  checkLabel:setVisible(true)
  panel.isClaimable = false

  if not isActiveTree then
    checkLabel:setImageSource('/game_dailyreward/images/icon-lock-red')
    checkLabel:setWidth(12)
    checkLabel:setHeight(12)
    return
  end

  if day < currentDay then
    checkLabel:setImageSource('/game_dailyreward/images/icon-dailyrewarddone')
    checkLabel:setWidth(12)
    checkLabel:setHeight(12)
    rewardItem:setTooltip("Já foi coletada")
  elseif day == currentDay then
    if canClaim then
      checkLabel:setVisible(false)
      if isActiveTree then
        panel.isClaimable = true
        table.insert(claimablePanels, panel)
      end
    else
      checkLabel:setImageSource('/game_dailyreward/images/icon-lock-red')
      checkLabel:setWidth(12)
      checkLabel:setHeight(12)
    end
  else
    checkLabel:setImageSource('/game_dailyreward/images/icon-lock-red')
    checkLabel:setWidth(12)
    checkLabel:setHeight(12)
  end
end

function claimReward()
  if not g_game.isOnline() then return end
  
  local msg = {
    action = "claim"
  }
  
  g_game.getProtocolGame():sendExtendedOpcode(OPCODE_DAILY_REWARD, json.encode(msg))
  claimButton:setEnabled(false)
end

function onTextMessage(mode, text)
  if not dailyRewardWindow:isVisible() then return end
  -- Any text message updates that might be relevant can be handled here.
end

function onDayPanelClick(panel)
  if panel.isClaimable then
    for _, p in ipairs(claimablePanels) do
      p:setBorderWidth(1)
      p:setBorderColor('#ffd700')
    end
    claimButton:setEnabled(true)
  end
end
