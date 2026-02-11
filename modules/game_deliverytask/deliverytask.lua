deliveryTaskWindow = nil
deliveryTaskButton = nil
tasksTabBar = nil
contentPanel = nil
local rewardWindow = nil


-- Task Configuration
-- Server ID to Client ID mapping
-- Server ID to Client ID mapping
-- MOVED TO SERVER (delivery_task.lua). Client now uses the ID sent by server.
-- Keeping this empty/commented to avoid confusion.
local ItemIdMapping = {
  -- [2160] = 3043, 
  -- ... (Managed by server)
}

local function getClientId(serverId)
  return ItemIdMapping[serverId] or serverId
end

local tasksConfig = {
  kill = {
    {name = "Rat", amount = {easy=10, medium=20, hard=30}, outfitId = 21},
    {name = "Rotworm", amount = {easy=15, medium=30, hard=45}, outfitId = 26},
    {name = "Wolf", amount = {easy=10, medium=25, hard=40}, outfitId = 27},
    {name = "Troll", amount = {easy=10, medium=25, hard=40}, outfitId = 15},
    {name = "Bear", amount = {easy=10, medium=20, hard=30}, outfitId = 16},
    {name = "Rabbit", amount = {easy=5, medium=10, hard=15}, outfitId = 117},
    {name = "Skeleton", amount = {easy=20, medium=40, hard=60}, outfitId = 33},
    {name = "Minotaur", amount = {easy=20, medium=40, hard=60}, outfitId = 25},
    {name = "Orc", amount = {easy=20, medium=40, hard=60}, outfitId = 6},
    {name = "Cyclops", amount = {easy=10, medium=20, hard=30}, outfitId = 22},
    {name = "Dragon", amount = {easy=5, medium=10, hard=15}, outfitId = 34},
    {name = "Demon", amount = {easy=2, medium=5, hard=10}, outfitId = 35},
    {name = "Giant Spider", amount = {easy=5, medium=10, hard=15}, outfitId = 38},
    {name = "Hero", amount = {easy=2, medium=5, hard=10}, outfitId = 73},
    {name = "Behemoth", amount = {easy=2, medium=5, hard=10}, outfitId = 55},
    {name = "Warlock", amount = {easy=2, medium=5, hard=10}, outfitId = 130},
    {name = "Hydra", amount = {easy=3, medium=7, hard=12}, outfitId = 129},
    {name = "Dragon Lord", amount = {easy=3, medium=7, hard=12}, outfitId = 39},
    {name = "Black Knight", amount = {easy=1, medium=3, hard=5}, outfitId = 131},
    {name = "Necromancer", amount = {easy=5, medium=10, hard=15}, outfitId = 209}
  },
  delivery = {
    {id = 2148, name = "Gold Coin", amount = {easy=100, medium=500, hard=1000}},
    {id = 2152, name = "Platinum Coin", amount = {easy=10, medium=50, hard=100}},
    {id = 2160, name = "Crystal Coin", amount = {easy=1, medium=5, hard=10}},
    {id = 2671, name = "Ham", amount = {easy=10, medium=20, hard=30}},
    {id = 2666, name = "Meat", amount = {easy=10, medium=20, hard=30}},
    {id = 2463, name = "Plate Armor", amount = {easy=1, medium=2, hard=3}},
    {id = 2457, name = "Steel Helmet", amount = {easy=1, medium=2, hard=3}},
    {id = 2509, name = "Steel Shield", amount = {easy=1, medium=2, hard=3}},
    {id = 2195, name = "Boots of Haste", amount = {easy=1, medium=1, hard=1}},
    {id = 2498, name = "Royal Helmet", amount = {easy=1, medium=1, hard=1}},
    {id = 2472, name = "Magic Plate Armor", amount = {easy=1, medium=1, hard=1}},
    {id = 2514, name = "Mastermind Shield", amount = {easy=1, medium=1, hard=1}},
    {id = 2173, name = "Amulet of Loss", amount = {easy=1, medium=1, hard=1}},
    {id = 2400, name = "Magic Sword", amount = {easy=1, medium=1, hard=1}},
    {id = 2421, name = "Thunder Hammer", amount = {easy=1, medium=1, hard=1}},
    {id = 2522, name = "Great Shield", amount = {easy=1, medium=1, hard=1}},
    {id = 2492, name = "Dragon Scale Mail", amount = {easy=1, medium=1, hard=1}}
  }
}
    
local activeTasks = {
  kill = {},
  delivery = {}
}

local dummy2 = nil
local updateEvent = nil

local function updateTimer()
    if updateEvent then 
        removeEvent(updateEvent) 
        updateEvent = nil
    end
    
    if not deliveryTaskWindow or not deliveryTaskWindow:isVisible() then return end
    
    local nextReset = activeTasks.nextReset or 0
    local now = os.time()
    local diff = math.max(0, nextReset - now)
    
    local days = math.floor(diff / 86400)
    local hours = math.floor((diff % 86400) / 3600)
    
    local label = deliveryTaskWindow:getChildById('timerLabel')
    if label then
        label:setText(tr('Reset: %dd %02dh', days, hours))
    end
    
    updateEvent = scheduleEvent(updateTimer, 60000)
end

local function onExtendedOpcode(protocol, code, buffer)
  if code ~= 204 then return end
  local status, data = pcall(function() return json.decode(buffer) end)
  if not status then 
     return 
  end
  
  if data.activeKills then
      activeTasks.kill = data.activeKills
      activeTasks.delivery = data.activeDeliveries
      activeTasks.storage = data.storage or {}
      activeTasks.nextReset = data.nextReset
      refreshTasks()
      updateTimer()
  end
end



function init()


  connect(g_game, { onGameStart = online,
                    onGameEnd = offline })

  
  deliveryTaskWindow = g_ui.displayUI('deliverytask')
  deliveryTaskWindow:hide()
  
  rewardWindow = g_ui.createWidget('RewardWindow', deliveryTaskWindow)
  rewardWindow:hide()

  deliveryTaskButton = modules.client_topmenu.addLeftGameButton('deliveryTaskButton', tr('Tarefas de Entrega'), '/images/topbuttons/questlog', toggle)
  
  tasksTabBar = deliveryTaskWindow:getChildById('tasksTabBar')
  contentPanel = deliveryTaskWindow:getChildById('contentPanel')
  
  -- Use a holder panel for tabs so tasksTabBar doesn't control the window itself (circular ref)
  local holderPanel = g_ui.createWidget('Panel', deliveryTaskWindow)
  holderPanel:setVisible(false)
  holderPanel:setHeight(0) 
  
  -- Dummies are children of holderPanel (via addTab logic usually adding to contentWidget)
  -- Actually addTab adds to contentWidget.
  
  dummy1 = g_ui.createWidget('UIWidget') 
  dummy1:setPhantom(true)
  dummy2 = g_ui.createWidget('UIWidget')
  dummy2:setPhantom(true)
  
  tasksTabBar:setContentWidget(holderPanel)
  -- Manual wiring of OTUI tabs
  tasksTabBar.tabs = {} 
  
  local tab1 = deliveryTaskWindow:recursiveGetChildById('tabMatar')
  local tab2 = deliveryTaskWindow:recursiveGetChildById('tabEntregar')
  
  -- Setup Tab 1 (Matar)
  tab1.tabPanel = dummy1
  dummy1.isTab = true
  tab1.tabBar = tasksTabBar
  table.insert(tasksTabBar.tabs, tab1)
  tab1.onClick = function() tasksTabBar:selectTab(tab1) end
  
  -- Setup Tab 2 (Entregar)
  tab2.tabPanel = dummy2
  dummy2.isTab = true
  tab2.tabBar = tasksTabBar
  table.insert(tasksTabBar.tabs, tab2)
  tab2.onClick = function() tasksTabBar:selectTab(tab2) end
  
  connect(tasksTabBar, { onTabChange = onTabChange })

  -- Default selection
  tasksTabBar:selectTab(tab1)
  
  -- Register Extended Opcode
  if g_game.isOnline() then
    -- We call online() below, which handles opcode registration.
  end
  
  -- Keep local generation as fallback provided? 
  -- Actually, let's rely on server response mostly. But keep generate for "offline" or initial.
  generateDailyTasks()

  if g_game.isOnline() then
    online()
  end
end

function terminate()
  disconnect(g_game, { onGameStart = online,
                       onGameEnd = offline })

  if g_game.isOnline() then
     g_game.getProtocolGame():unregisterExtendedOpcode(204)
  end

  if tasksTabBar then
    disconnect(tasksTabBar, { onTabChange = onTabChange })
  end
  
  -- No manual destruction of children to avoid race conditions. 
  -- deliveryTaskWindow destruction will handle tasksTabBar, holderPanel and dummies.
  
  if rewardWindow then
    rewardWindow:destroy()
    rewardWindow = nil
  end

  if deliveryTaskWindow then
    deliveryTaskWindow:destroy()
    deliveryTaskWindow = nil
  end

  if deliveryTaskButton then
    deliveryTaskButton:destroy()
    deliveryTaskButton = nil
  end
end

function online()
  if g_game.isOnline() then
    local protocol = g_game.getProtocolGame()
    if protocol then
        -- Safety: Unregister first (use . notation as per original working code)
        pcall(function() protocol.unregisterExtendedOpcode(204) end)
        
        -- Register with . notation (static helper style)
        protocol.registerExtendedOpcode(204, onExtendedOpcode)
        
        sendOpcode({action = "fetch"})
    end
  end
end

function offline()
  if deliveryTaskWindow then
    deliveryTaskWindow:hide()
  end
end

function sendOpcode(data)
  if not g_game.isOnline() then return end
  local protocol = g_game.getProtocolGame()
  if protocol then
    protocol:sendExtendedOpcode(204, json.encode(data))
  end
end



function toggle()
  if not deliveryTaskWindow then return end
  
  if deliveryTaskWindow:isVisible() then
    deliveryTaskWindow:hide()
  else
    deliveryTaskWindow:show()
    deliveryTaskWindow:raise()
    deliveryTaskWindow:focus()
    -- Fetch latest on show
    sendOpcode({action = "fetch"})
    refreshTasks(tasksTabBar:getCurrentTab())
  end
end

function onTabChange(tabBar, tab)
  for _, t in pairs(tabBar.tabs) do
    if t == tab then
      t:setImageSource('/modules/game_deliverytask/images/activepage.png')
    else
      t:setImageSource('/modules/game_deliverytask/images/page.png')
    end
  end
  refreshTasks(tab)
end

function getDifficulty()
  local player = g_game.getLocalPlayer()
  if not player then return "easy" end
  local level = player:getLevel()
  
  if level <= 50 then return "easy"
  elseif level <= 150 then return "medium"
  else return "hard" end
end

function generateDailyTasks()
  -- Use date-based seed to match server logic (in case of offline/fallback)
  math.randomseed(tonumber(os.date("%Y%m%d")))

  -- Fallback logic kept, but mostly we start empty or wait for server
  -- Can keep original logic here for offline testing
  activeTasks.kill = {}
  activeTasks.delivery = {}
  -- ... (Logic could be kept but simplified for brevity of this tool call if I want to save space, but I'll keep it)
  
  -- Shuffle and pick 4
  local killPool = {}
  for _, v in ipairs(tasksConfig.kill) do table.insert(killPool, v) end
  
  for i = 1, 4 do
    if #killPool == 0 then break end
    local idx = math.random(#killPool)
    table.insert(activeTasks.kill, killPool[idx])
    table.remove(killPool, idx)
  end
  
  local deliveryPool = {}
  for _, v in ipairs(tasksConfig.delivery) do table.insert(deliveryPool, v) end
  
  for i = 1, 4 do
    if #deliveryPool == 0 then break end
    local idx = math.random(#deliveryPool)
    table.insert(activeTasks.delivery, deliveryPool[idx])
    table.remove(deliveryPool, idx)
  end
  
  activeTasks.storage = nil -- Local mode
end

function showReward(task)
    if not task or not task.reward then return end
    if not rewardWindow then return end
    
    local itemWidget = rewardWindow:getChildById('rewardItem')
    local countLabel = rewardWindow:getChildById('rewardCount')
    
    -- Use clientId from server if available, else map locally
    local clientId = task.reward.clientId or getClientId(task.reward.id)
    if itemWidget then itemWidget:setItemId(clientId) end
    
    local name = ""
    local thingType = g_things.getThingType(clientId, ThingCategoryItem)
    if thingType and thingType.getName then 
        name = thingType:getName() 
    end
    
    local xpText = ""
    if task.reward.xp and task.reward.xp > 0 then
        xpText = task.reward.xp .. " experi�ncia"
    end
    
    if countLabel then countLabel:setText(task.reward.count .. "x " .. name) end
    
    local xpLabel = rewardWindow:getChildById('xpLabel')
    if xpLabel then xpLabel:setText(xpText) end
    
    rewardWindow:show()
    rewardWindow:raise()
    rewardWindow:focus()
end

function refreshTasks(tab)
  if not contentPanel then return end
  contentPanel:destroyChildren()
  
  local currentTab = tab or tasksTabBar:getCurrentTab()
  if not currentTab then return end
  
  local difficulty = getDifficulty()
  local tabId = currentTab:getId()
  
  local completed = 0
  local total = 0
  
  if tabId == 'tabMatar' then
    total = #activeTasks.kill
    for i, task in ipairs(activeTasks.kill) do
      local amount = type(task.amount) == 'table' and (task.amount[difficulty] or 10) or task.amount
      local progress = -1
      if activeTasks.storage and activeTasks.storage.kill then
         progress = activeTasks.storage.kill[i] or -1
         -- Check completion for stats
         if progress >= (amount + 50) then completed = completed + 1 end
      end
      addTaskWidget(task.name, amount, nil, true, i, task.outfitId, progress, task.reward) 
    end
  else
    total = #activeTasks.delivery
    for i, task in ipairs(activeTasks.delivery) do
      local amount = type(task.amount) == 'table' and (task.amount[difficulty] or 1) or task.amount
      local progress = -1
      if activeTasks.storage and activeTasks.storage.delivery then
         progress = activeTasks.storage.delivery[i] or -1
         -- Check completion for stats
         if progress == -1 then completed = completed + 1 end
      end
      -- Use clientId from server if available, else id
      local displayId = task.clientId or task.id
      addTaskWidget(task.name, amount, displayId, false, i, nil, progress, task.reward)
    end
  end
  
  local percent = 0
  if total > 0 then percent = math.floor((completed / total) * 100) end
  
  local bar = deliveryTaskWindow:getChildById('overallProgress')
  if bar then
      bar:setPercent(percent)
      local label = bar:getChildById('overallProgressText')
      if label then
          label:setText(tr('Progresso: %d/%d (%d%%)', completed, total, percent))
      end
  end
end

function addTaskWidget(name, amount, itemId, isCreature, index, outfitId, progress, reward)
  local widget = g_ui.createWidget('TaskWidget', contentPanel)
  widget:setId('taskEntry' .. index)
  
  widget:getChildById('taskLabel'):setText(name)
  
  local statusText = ""
  local button = widget:getChildById('actionButton')
  local progressBg = widget:getChildById('progressBg')
  local progressBar = progressBg:getChildById('taskProgress')
  local doneImage = widget:getChildById('doneImage')
  local amountLabel = widget:getChildById('amountLabel')
  
  local rewardItem = widget:getChildById('rewardItem')
  local rewardItemAmount = widget:getChildById('rewardItemAmount')
  local rewardXpIcon = widget:getChildById('rewardXpIcon')
  local rewardXpAmount = widget:getChildById('rewardXpAmount')

  if reward then
      if reward.id and reward.id > 0 then
          -- Use clientId sent by server, or fallback (which will be wrong now if mapping is empty, but server should always send it)
          local clientId = reward.clientId or getClientId(reward.id)
          rewardItem:setItemId(clientId)
          rewardItemAmount:setText(reward.count or 1)
          rewardItem:setVisible(true)
          rewardItemAmount:setVisible(true)
      end

      if reward.xp and reward.xp > 0 then
          rewardXpAmount:setText(reward.xp)
          rewardXpIcon:setVisible(true)
          rewardXpAmount:setVisible(true)
      end
  end

  if isCreature then
      -- Kill Task
      local current = math.max(0, progress) 
      local limit = amount 
      
      if current >= (limit + 50) then
          -- Task Fully Completed and Reward Claimed
          doneImage:setVisible(true)
          button:setVisible(false)
          
          progressBg:setVisible(false) -- Hide Bar
          amountLabel:setVisible(true) -- Show Text Only
          statusText = amount .. "/" .. amount
          progressBg:setMarginBottom(0) -- Move Bar Lower
      else
          doneImage:setVisible(false)
          progressBg:setVisible(true)
          amountLabel:setVisible(true)
          
          local percent = math.min(100, math.floor((current / amount) * 100))
          progressBar:setPercent(percent)
          
          if current >= amount then
              button:setText("Entregar")
              button:setVisible(true)
              button:setEnabled(true)
              statusText = "Completo!"
              progressBg:setMarginBottom(24) -- Raise bar for button
              -- No showReward on click anymore, just deliver
              button.onClick = function() sendOpcode({action = "deliver", type = "kill", index = index}) end
          else
              button:setVisible(false) -- Hide if not complete
              statusText = current .. "/" .. amount
              progressBg:setMarginBottom(0) -- Lower bar
          end
      end
  else
      -- Delivery Task
      if progress == -1 then -- Completed
          doneImage:setVisible(true)
          button:setVisible(false)
          
          progressBg:setVisible(false) -- Hide Bar
          amountLabel:setVisible(true) -- Show Text Only
          statusText = amount .. "/" .. amount
          progressBg:setMarginBottom(0) -- Maintain layout for label
      else
          -- In Progress (Live Item Count)
          local current = math.max(0, progress)
          
          doneImage:setVisible(false)
          progressBg:setVisible(true)
          amountLabel:setVisible(true)
          
          local percent = math.min(100, math.floor((current / amount) * 100))
          progressBar:setPercent(percent)
          
          if current >= amount then
              button:setText("Entregar")
              button:setVisible(true)
              button:setEnabled(true) 
              statusText = current .. "/" .. amount .. ""
              progressBg:setMarginBottom(24) -- Raise bar for button
              button.onClick = function() sendOpcode({action = "deliver", type = "delivery", index = index}) end
          else
              button:setVisible(false) -- Hide until enough items
              statusText = current .. "/" .. amount 
              progressBg:setMarginBottom(0) -- Lower bar
          end
      end
  end
     
  amountLabel:setText(statusText)
  
  if isCreature then
    local creatureWidget = widget:getChildById('taskCreature')
    creatureWidget:setVisible(true)
    widget:getChildById('taskItem'):setVisible(false)
    
    local typeId = outfitId or 21 
    local outfit = {type = typeId, head = 0, body = 0, legs = 0, feet = 0, addons = 0} 
    creatureWidget:setOutfit(outfit)
    
  else
    local itemWidget = widget:getChildById('taskItem')
    itemWidget:setVisible(true)
    widget:getChildById('taskCreature'):setVisible(false)
    itemWidget:setItemId(getClientId(itemId))
    itemWidget:setVirtual(true)
  end
  
  local taskData = nil
  if isCreature and activeTasks.kill then taskData = activeTasks.kill[index] 
  elseif not isCreature and activeTasks.delivery then taskData = activeTasks.delivery[index] end
  
  if taskData and taskData.reward then
     local slot = widget:getChildById('slotBg')
     if slot then slot.onClick = function() showReward(taskData) end end
     
     if isCreature then
        local w = widget:getChildById('taskCreature')
        if w then w.onClick = function() showReward(taskData) end end
     else
        local w = widget:getChildById('taskItem')
        if w then w.onClick = function() showReward(taskData) end end
     end
  end
end
