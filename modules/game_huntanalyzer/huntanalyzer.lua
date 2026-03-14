local damageWindow = nil
local partyWindow = nil
local bossCooldownsWindow = nil
local dpsGraph = nil
local xpGraph = nil
local xpMobGraph = nil
local dpsDealtGraph = nil
local topDpsD = 0
local topDpsR = 0
local expWindow = nil
local analyzerButton = nil
local lootedItems = {}
local lootedItemsParty = {}
local currentLootView = "individual"
local killedCreatures = {}
local creatureOutfit = nil

local allTypes = {"ph", "ea", "fi", "ic", "en", "de", "ho", "ld", "md", "dr"}

DAMAGETRACKER_OPCODE = 52
KILLTRACKER_OPCODE = 53
BOSS_COOLDOWNS_OPCODE = 54

function init()
  ProtocolGame.registerExtendedOpcode(DAMAGETRACKER_OPCODE, onExtendedOpcode)
  ProtocolGame.registerExtendedOpcode(KILLTRACKER_OPCODE, onKillTrackerExtendedOpcode)
  ProtocolGame.registerExtendedOpcode(BOSS_COOLDOWNS_OPCODE, onBossCooldownsInfo)

  connect(LocalPlayer, {
	onUpdateKillTracker = onUpdateKillTracker,
  })
  
  connect(g_game, {
    onGameStart = refresh,
    onGameEnd = offline
  })

  mainWindow = g_ui.loadUI('mainWindow', modules.game_interface.getRightPanel())
  expWindow = g_ui.loadUI('expAnalyzer', modules.game_interface.getRightPanel())
  dropWindow = g_ui.loadUI('dropTracker', modules.game_interface.getRightPanel())
  dropWindow.onClose = dropWindow:hide()
  trackWindow = g_ui.loadUI('killTracker', modules.game_interface.getRightPanel())
  damageWindow = g_ui.loadUI('damageAnalyzer', modules.game_interface.getRightPanel())
  partyWindow = g_ui.loadUI('partyAnalyzer', modules.game_interface.getRightPanel())
  bossCooldownsWindow = g_ui.loadUI('bossCooldowns', modules.game_interface.getRightPanel())
  
  damageWindow:hide()
  mainWindow:hide()
  dropWindow:hide()
  trackWindow:hide()
  expWindow:hide()
  partyWindow:hide()
  bossCooldownsWindow:hide()
  g_keyboard.bindKeyDown('Ctrl+H', toggle)
  analyzerButton =  modules.client_topmenu.addRightGameToggleButton('analyzerButton', tr('Analyzer (Ctrl+H)'), '/images/topbuttons/analyzers', toggle)
  analyzerButton:setOn(mainWindow:isVisible())

  local scrollbarDamageAnalyzer = damageWindow:getChildById('miniwindowScrollBar')
  scrollbarDamageAnalyzer:mergeStyle({ ['$!on'] = { }})
  
  local scrollbarPartyAnalyzer = partyWindow:getChildById('miniwindowScrollBar')
  scrollbarPartyAnalyzer:mergeStyle({ ['$!on'] = { }})
  
  expWindow:setup()
  dropWindow:setup()
  trackWindow:setup()
  mainWindow:setup()
  damageWindow:setup()
  partyWindow:setup()
  bossCooldownsWindow:setup()
  
  lootedItemsLabel = dropWindow:recursiveGetChildById("lootedItemsLabel")
  lootedItemsLabel:setHeight(30)
  killedMonstersLabel = trackWindow:recursiveGetChildById("monsterLabel")
  killedMonstersLabel:setHeight(30)

  dpsGraph = g_ui.createWidget("AnalyzerGraph", damageWindow.contentsPanel)
  dpsDealtGraph = g_ui.createWidget("AnalyzerGraph", damageWindow.contentsPanel)
  xpGraph = g_ui.createWidget("AnalyzerGraph", expWindow.contentsPanel)
  xpMobGraph = g_ui.createWidget("AnalyzerGraph", expWindow.contentsPanel)
end

--//########## REAL MAGIC ##########//--
expHUpdateEvent = 0
expHVar = {
	originalExpAmount = 0,
	lastExpAmount = 0,
	historyIndex = 0,
	sessionStart = 0,
}
expHistory = {0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0}



function showExpWindow()
	if not expWindow:isVisible() then
		expWindow:show()
		updateanalyzerWindow()
	else
		expWindow:hide()
	end
end

function showDropWindow()
	if not dropWindow:isVisible() then
		dropWindow:show()
	else
		dropWindow:hide()
	end
end
function showKillWindow()
	if not trackWindow:isVisible() then
		trackWindow:show()
	else
		trackWindow:hide()
	end
end

function showDamageWindow()
	damageWindow:setBorderWidth(2)
	damageWindow:setBorderColor("#FFFFFF")
	scheduleEvent(function() 
	  if damageWindow then
		damageWindow:setBorderWidth(0)
	  end
	end, 300)
	
	if not damageWindow:isVisible() then
	  damageWindow:show()
	else
	  damageWindow:hide()
	end
  end

function showPartyWindow()
    -- white border flash effect
    partyWindow:setBorderWidth(2)
    partyWindow:setBorderColor("#FFFFFF")
    scheduleEvent(function() 
      if partyWindow then
        partyWindow:setBorderWidth(0)
      end
    end, 300)
	
	if not partyWindow:isVisible() then
		partyWindow:show()
	else
		partyWindow:hide()
	end
end

function showBossCooldownsWindow()
    -- white border flash effect
    bossCooldownsWindow:setBorderWidth(2)
    bossCooldownsWindow:setBorderColor("#FFFFFF")
    scheduleEvent(function() 
      if bossCooldownsWindow then
        bossCooldownsWindow:setBorderWidth(0)
      end
    end, 300)
	
	if not bossCooldownsWindow:isVisible() then
		bossCooldownsWindow:show()
        requestBossCooldowns()
	else
		bossCooldownsWindow:hide()
	end
end

function requestBossCooldowns()
    local protocolGame = g_game.getProtocolGame()
    if protocolGame then
        protocolGame:sendExtendedOpcode(BOSS_COOLDOWNS_OPCODE, "")
    end
end

function normalizeOutfit(outfit)
  if outfit.lookType then
    outfit.type = outfit.lookType
    outfit.head = outfit.lookHead
    outfit.body = outfit.lookBody
    outfit.legs = outfit.lookLegs
    outfit.feet = outfit.lookFeet
    outfit.addons = outfit.lookAddons
    outfit.mount = outfit.lookMount
  end
  return outfit
end

function onBossCooldownsInfo(protocol, opcode, buffer)
    local status, data = pcall(function() return json.decode(buffer) end)
    if not status or not data then return end

    local contentsPanel = bossCooldownsWindow:getChildById('contentsPanel')
    if not contentsPanel then return end
    
    local bossList = contentsPanel:getChildById('bossList')
    if not bossList then return end
    
    bossList:destroyChildren()
    -- Force width to ensure visibility in verticalBox
    bossList:setWidth(contentsPanel:getWidth() - 12) 

    -- Ordena por tempo restante (menor primeiro) ou nome
    table.sort(data, function(a,b) return a.remaining < b.remaining end)
    
    if #data == 0 then
        local label = g_ui.createWidget('Label', bossList)
        label:setText("None")
        bossList:setHeight(20)
    else
        bossList:setHeight(#data * 50) -- 48 + 2 margin
    end

    for _, boss in ipairs(data) do
        local widget = g_ui.createWidget('BossWidget', bossList)
        widget:setWidth(bossList:getWidth()) -- Ensure widget fills list
        widget:setId(boss.name)
        
        local creature = widget:getChildById('creature')
        creature:setOutfit(normalizeOutfit(boss.outfit))
        creature:setAnimate(true)
        
        local nameLabel = widget:getChildById('name')
        nameLabel:setText(boss.name)
        
        local timerLabel = widget:getChildById('timer')
        if boss.remaining > 0 then
            local hours = math.floor(boss.remaining / 3600)
            local mins = math.floor((boss.remaining % 3600) / 60)
            timerLabel:setText(string.format("Cooldown: %dh %dm", hours, mins))
            timerLabel:setColor('#ff5555') -- Vermelho
        else
            timerLabel:setText("Disponvel")
            timerLabel:setColor('#55ff55') -- Verde
        end
    end
end

function resetSessionAll()
  resetLootedItems()
  resetKilledMonsters()
  resetPartyAnalyzer()
  resetDamageAnalyzer()

  updateanalyzerWindow()
  startFreshanalyzerWindow()

  killedCreatures = {}
  lootedItems = {}
  lootedItemsParty = {}

  -- RESET INDIVIDUAL ANALYZER
  setSkillValue('lootCtx', "0")
  setSkillColor('lootCtx', "#edebeb")

  setSkillValue('supplyCtx', "-0")
  setSkillColor('supplyCtx', "#ff5555")

  local balWidget = expWindow:recursiveGetChildById('balanceCtx')
  if balWidget then
    local val = balWidget:getChildById('value')
    if val then
      val:setText("0")
      val:setColor("#AFAFAF")
    end
  end

  -- RESET PARTY HEADER
  local headerPanel = partyWindow:recursiveGetChildById("headerPanel")
  if headerPanel then

    local lootCtx = headerPanel:getChildById("lootCtx")
    if lootCtx and lootCtx:getChildById("value") then
      lootCtx:getChildById("value"):setText("0")
    end

    local supplyCtx = headerPanel:getChildById("supplyCtx")
    if supplyCtx and supplyCtx:getChildById("value") then
      local val = supplyCtx:getChildById("value")
      val:setText("-0")
      val:setColor("#ff5555")
    end

    local balanceCtx = headerPanel:getChildById("balanceCtx")
    if balanceCtx and balanceCtx:getChildById("value") then
      local val = balanceCtx:getChildById("value")
      val:setText("0")
      val:setColor("#AFAFAF")
    end
  end

	if dpsGraph then dpsGraph:clear() end
	if xpGraph then xpGraph:clear() end
	if xpMobGraph then xpMobGraph:clear() end
	if dpsDealtGraph then dpsDealtGraph:clear() end

	if not xpGraph and not xpMobGraph then
      xpGraph:createGraph()
      xpMobGraph:createGraph()
	end
	
	if not dpsGraph and not dpsDealtGraph then
	  dpsGraph:createGraph()
	  dpsDealtGraph:createGraph()
	end	

	if not dropWindow:isVisible() then
		dropWindow:show()
	end
	if not trackWindow:isVisible() then
		trackWindow:show()
	end
	if not expWindow:isVisible() then
		expWindow:show()
		updateanalyzerWindow()
	end
	if not damageWindow:isVisible() then
		damageWindow:show()
	end
	if not partyWindow:isVisible() then
		partyWindow:show()
	end
	if not bossCooldownsWindow:isVisible() then
		bossCooldownsWindow:show()
	end
end

function resetKillTracker()
	resetKilledMonsters()
	killedCreatures = {}
end



function zerarHistory()
	for zero = 1,60 do
		expHistory[zero] = 0
	end
end

function startFreshanalyzerWindow()
	resetExpH()
	if expHUpdateEvent ~= 0 then
		removeEvent(expHUpdateEvent)
	end
	
end

function updateanalyzerWindow()
	expHUpdateEvent = scheduleEvent(updateanalyzerWindow, 5000)
	local player = g_game.getLocalPlayer()
	if not player then return end --Wont go future if there's no player
  
	local currentExp = player:getExperience()
	if expHVar.lastExpAmount == 0 then
		expHVar.lastExpAmount = currentExp
	end
	if expHVar.originalExpAmount == 0 then
		expHVar.originalExpAmount = currentExp
	end
	local expDiff = math.floor(currentExp-expHVar.lastExpAmount)
	updateExpHistory(expDiff)
	expHVar.lastExpAmount = currentExp
	
	local _expGained = math.floor(currentExp-expHVar.originalExpAmount)
	
	local _expHistory = getExpGained()
	if _expHistory <= 0 and (expHVar.sessionStart > 0 or _expGained > 0) then --No Exp gained last 5 min, lets stop
		resetExpH()
		return false
	end
	
	local _session = 0
	local _start = expHVar.sessionStart
	if _start > 0 and _expGained > 0 then
		_session = math.floor(g_clock.seconds()-_start)
	end

	local totalKills = 0
	local avgMobExp = 0
	for _, data in pairs(killedCreatures) do
		totalKills = totalKills + data.amount
	end
	
	local string_totalKills = number_format(totalKills)
	local avgMobExp = _expGained / totalKills
	local avgExp = 0
	local string_avgMobExp = 0
	if avgMobExp and avgMobExp > 0 then
		avgExp = math.floor(math.abs(avgMobExp))
		string_avgMobExp = number_format(avgExp) 
	end
	
	setSkillValue('killedmobs', string_totalKills)
	setSkillValue('avgMobExp', string_avgMobExp)
	
	local string_session = getTimeFormat(_session)
	local string_expGain = number_format(_expGained)
	-----------------------------------------------------
	local _getExpHour = getExpPerHour(_expHistory, _session)
	local string_expph = number_format(_getExpHour)
	-----------------------------------------------------

	local _lvl = player:getLevel()
	local _nextLevelExp = getExperienceForLevel(_lvl+1)
	local _expToNextLevel = math.floor(_nextLevelExp-currentExp)
	
	local string_exptolevel = number_format(_expToNextLevel)
	
	local _timeToNextLevel = getNextLevelTime(_expToNextLevel, _getExpHour)
	local string_timetolevel = getTimeFormat(_timeToNextLevel)
	
	setSkillValue('session',		string_session)
	setSkillValue('expph',			string_expph)
	setSkillValue('expgained',		string_expGain)
	setSkillValue('exptolevel',		string_exptolevel)
	setSkillValue('timetolevel',	string_timetolevel)

	if xpGraph:getGraphsCount() == 0 then
		xpGraph:createGraph()
		xpGraph:setTitle("XP/h")
		xpGraph:setLineWidth(1, 1)
		xpGraph:setLineColor(1,"#00FF00")
	end
		xpGraph:addValue(1, _getExpHour / 1000)
		
	if xpMobGraph:getGraphsCount() == 0 then
		xpMobGraph:createGraph()
		xpMobGraph:setTitle("XP/mob")
		xpMobGraph:setLineWidth(1, 1)
		xpMobGraph:setLineColor(1,"#FF0000")
	end
		xpMobGraph:addValue(1, avgExp)
end


function getNextLevelTime(_expToNextLevel, _getExpHour)
	if _getExpHour <= 0 then
		return 0
	end
	local _expperSec = (_getExpHour/3600)
	local _secToNextLevel = math.ceil(_expToNextLevel/_expperSec)
	return _secToNextLevel
end

function getExperienceForLevel(lv)
	lv = lv - 1
	return ((50 * lv * lv * lv) - (150 * lv * lv) + (400 * lv)) / 3
end

function getNumber(msg)
	b, e = string.find(msg, "%d+")
	
	if b == nil or e == nil then
		count = 0
	else
		count = tonumber(string.sub(msg, b, e))
	end	
	return count
end

function number_format(amount)
  local formatted = amount
  while true do
    formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", '%1,%2')
    if (k==0) then
      break
    end
  end
  return formatted
end

function getExpPerHour(_expHistory, _session)
	if _session < 10 then
		_session = 10
	elseif _session > 300 then
		_session = 300
	end
	
	local _expSec = _expHistory/_session
	local _expH = math.floor(_expSec*3600)
	if _expH <= 0 then
		_expH = 0
	end
	return getNumber(_expH)
end

function getTimeFormat(_secs)
	local _hour = math.floor(_secs/3600)
	_secs = math.floor(_secs-(_hour*3600))
	local _min = math.floor(_secs/60)
	
	if _hour <= 0 then
		_hour = "00"
	elseif _hour <= 9 then
		_hour = "0".. _hour
	end
	if _min <= 0 then
		_min = "00"
	elseif _min <= 9 then
		_min = "0".. _min
	end
	return _hour ..":".. _min
end

function updateExpHistory(dif)
	if dif > 0 then
		if expHVar.sessionStart == 0 then
			expHVar.sessionStart = g_clock.seconds()
		end
	end
	
	local _index = expHVar.historyIndex
	expHistory[_index] = dif
	_index = _index+1
	if _index < 0 or _index > 59 then
		_index = 0
	end
	expHVar.historyIndex = _index
end

function getExpGained()
	local totalExp = 0
	for key,value in pairs(expHistory) do
		totalExp = totalExp + value
	end
	return totalExp
end

function resetExpH()
	expHVar.originalExpAmount = 0
	expHVar.lastExpAmount = 0
	expHVar.historyIndex = 0
	expHVar.sessionStart = 0

	setSkillValue('session',		"00:00")
	setSkillValue('expph',			0)			setSkillColor('expph',			'#6eff8d')
	setSkillValue('expgained',		0)			setSkillColor('expgained',		'#edebeb')
	setSkillValue('exptolevel',		0)			setSkillColor('exptolevel',		'#edebeb')
	setSkillValue('timetolevel',	"00:00")	setSkillColor('timetolevel',	'#edebeb')

	if xpGraph then xpGraph:clear() end
	if xpMobGraph then xpMobGraph:clear() end

	if not xpGraph and not xpMobGraph then
      xpGraph:createGraph()
      xpMobGraph:createGraph()
	end

	zerarHistory()
end
--//########## REAL MAGIC ##########//--

function terminate()
  disconnect(LocalPlayer, {
	onExperienceChange = onExperienceChange
  })
  disconnect(g_game, {
    onGameStart = refresh,
    onGameEnd = offline
  })

  startFreshanalyzerWindow()
  resetLootedItems()
  resetKilledMonsters()
  resetDamageAnalyzer()
  
  pcall(function() ProtocolGame.unregisterExtendedOpcode(DAMAGETRACKER_OPCODE) end)
  pcall(function() ProtocolGame.unregisterExtendedOpcode(KILLTRACKER_OPCODE) end)
  pcall(function() ProtocolGame.unregisterExtendedOpcode(BOSS_COOLDOWNS_OPCODE) end)

  g_keyboard.unbindKeyDown('Ctrl+J')
  mainWindow:destroy()
  expWindow:destroy()
  dropWindow:destroy()
  trackWindow:destroy()
  bossCooldownsWindow:destroy()
  analyzerButton:destroy()
end

function expForLevel(level)
  return math.floor((50*level*level*level)/3 - 100*level*level + (850*level)/3 - 200)
end

function expToAdvance(currentLevel, currentExp)
  return expForLevel(currentLevel+1) - currentExp
end

function comma_value(n)
	local left,num,right = string.match(n,'^([^%d]*%d)(%d*)(.-)$')
	return left..(num:reverse():gsub('(%d%d%d)','%1,'):reverse())..right
end

function resetLootedItems()
local numberOfChilds = lootedItemsLabel:getChildCount()
for i = 1, numberOfChilds do
	lootedItemsLabel:destroyChildren(i)
end
	lootedItemsLabel:setHeight(30)
	return 
end

function resetKilledMonsters()
	local numberOfChilds = killedMonstersLabel:getChildCount()
	for i = 1, numberOfChilds do
		killedMonstersLabel:destroyChildren(i)
	end
	killedMonstersLabel:setHeight(30)
	return 
end

function setSkillValue(id, value)
	local skill = expWindow:recursiveGetChildById(id)
	local widget = skill:getChildById('value')
	widget:setText(value)
  end
  
function setSkillColor(id, value)
	local skill = expWindow:recursiveGetChildById(id)
	local widget = skill:getChildById('value')
	widget:setColor(value)
end

function setDamageColor(id, damageValue)
    local skill = damageWindow:recursiveGetChildById(id)
    local widget = skill:getChildById('damageValue')
    widget:setColor(damageValue)
end

function setMemberColor(id, value)
    local widget = partyWindow:getChildById('damageValueLabel')
    widget:setColor(value)
end
  
-- Chamado pelo protocolo quando o pacote 0xD1 (KillTracker)  recebido (OTG: parse em Lua).
function injectKillTracker(monsterName, lookType, lookHead, lookBody, lookLegs, lookFeet, addons, items, isParty)
	if not monsterName then return end
	if not killedCreatures[monsterName] then
		killedCreatures[monsterName] = { amount = 0, lookType = lookType, lookHead = lookHead, lookBody = lookBody, lookLegs = lookLegs, lookFeet = lookFeet, addons = addons }
	end
	killedCreatures[monsterName].amount = killedCreatures[monsterName].amount + 1
	local targetLootTable = isParty and lootedItemsParty or lootedItems
	if items then
		for _, data in pairs(items) do
			local itemName = data[1]
			local item = data[2]
			local serverId = data[3]
			local clientId = data[4]
			if item and item.getCount and serverId then
				if not targetLootTable[serverId] then
					targetLootTable[serverId] = { amount = 0, name = itemName or "?", clientId = clientId }
				else
					targetLootTable[serverId].clientId = targetLootTable[serverId].clientId or clientId
				end
				targetLootTable[serverId].amount = targetLootTable[serverId].amount + item:getCount()
			end
		end
	end
	local dataToUpdate = currentLootView == "party" and lootedItemsParty or lootedItems
	updateDropTracker(dataToUpdate)
	updateKillTracker(killedCreatures)
end

function onUpdateKillTracker(localPlayer, monsterName,lookType,lookHead,lookBody,lookLegs,lookFeet,addons, corpse,items)
	if not killedCreatures[monsterName] then
	killedCreatures[monsterName] = {amount = 0, lookType = lookType, lookHead = lookHead, lookBody = lookBody, lookLegs = lookLegs, lookFeet = lookFeet, addons = addons}
	end
	killedCreatures[monsterName].amount = killedCreatures[monsterName].amount + 1
	for _, data in pairs(items) do
	local itemName = data[1]	
	local item = data[2]
        -- Check if the item ID exists in the lootedItems table
        if not lootedItems[item:getId()] then
            -- If the item ID doesn't exist, initialize its amount to 0
            lootedItems[item:getId()] = { amount = 0 , name = itemName}
        end
        -- Increment the amount of the looted item
        lootedItems[item:getId()].amount = lootedItems[item:getId()].amount + item:getCount()

    end

	local dataToUpdate = currentLootView == "party" and lootedItemsParty or lootedItems
	updateDropTracker(dataToUpdate)
	updateKillTracker(killedCreatures)
end

function copyKillToClipboard()
	if not killedCreatures or killedCreatures == nil then
	  return
	end
	local creatureNames = {}
	for name, kills in pairs(killedCreatures) do

        table.insert(creatureNames, string.lower(name) .. " (" .. kills.amount .. ")")
    end
	table.sort(creatureNames)  -- Sorts alphabetically by default.
  
	local text = table.concat(creatureNames, ", ")
	if text and text ~= "" then
	  g_window.setClipboardText("Kills Session: "..text)
	end
end

function copyLootToClipboard()
	local targetTable = currentLootView == "party" and lootedItemsParty or lootedItems
    if not targetTable or next(targetTable) == nil then
        return
    end
    local maxChars = 250
    local prefix = "Loot Session: "
    local suffix = " [max text exceeded]"
    local availableChars = maxChars - #suffix  -- Reserve space for the suffix
    local loot = {}
    local currentLength = #prefix
    local textExceeded = false 

    for itemId, data in pairs(targetTable) do
        local count = data.amount
        if count >= 1000 then
            count = math.floor(count / 1000) .. "k" 
        end

        local entry = data.name .. " (" .. count .. ")"
        if currentLength + #entry + 2 <= availableChars then  -- +2 for ", " separator
            table.insert(loot, entry)
            currentLength = currentLength + #entry + 2
        else
            textExceeded = true 
            break  -- Stop adding more entries if the next one would exceed the limit of max chars
        end
    end
    local text = table.concat(loot, ", ")
    if text ~= "" then
        if textExceeded then
            text = text .. suffix
        end
        g_window.setClipboardText(prefix .. text)
    end
end

function updateKillTracker()
    local numberOfLines = 0
    for k, v in pairs(killedCreatures) do
        local creatureSprite = killedMonstersLabel:getChildById("monster"..k)
        if not creatureSprite then
            creatureSprite = g_ui.createWidget("Creature", killedMonstersLabel)
            creatureSprite:setId("monster"..k)
            creatureSprite:setTooltip(k)
        end

        local creatureName = killedMonstersLabel:getChildById("name"..k)
        if not creatureName then
            creatureName = g_ui.createWidget("MonsterNameLabel", killedMonstersLabel)
            creatureName:setId("name"..k)
            creatureName:addAnchor(AnchorLeft, "monster"..k, AnchorRight)
            creatureName:addAnchor(AnchorTop, "monster"..k, AnchorTop)
            creatureName:setMarginLeft(5)
        end

        local creatureCount = killedMonstersLabel:getChildById("count"..k)
        if not creatureCount then
            creatureCount = g_ui.createWidget("CreatureCountLabel", killedMonstersLabel)
            creatureCount:setId("count"..k)
            creatureCount:addAnchor(AnchorBottom,"monster"..k, AnchorBottom)
            creatureCount:addAnchor(AnchorLeft,"monster"..k, AnchorRight)
            creatureCount:setMarginLeft(5)
        end

        creatureCount:setText("Kills: "..v.amount)
        creatureName:setText(k)
        creatureSprite:setMarginTop(numberOfLines * 34 + 17)

        local creature = Creature.create()
        local outfit = {type = v.lookType, head = v.lookHead, body = v.lookBody, legs = v.lookLegs, feet = v.lookFeet, addons = v.addons}
        creature:setOutfit(outfit)


        creatureSprite:setCreature(creature)
        numberOfLines = numberOfLines + 1
    end
    killedMonstersLabel:setHeight(numberOfLines * 34 + 60)
end


function updateDropTracker(data)
    if dropWindow:isVisible() then
        local items = 0
        for k, v in pairs(data) do
            local itemSprite = lootedItemsLabel:getChildById("image"..k)
            if not itemSprite then
                itemSprite = g_ui.createWidget("ItemSprite", lootedItemsLabel)
                itemSprite:setId("image"..k)
                -- Armazena o itemId e itemName no widget para uso no handler
                itemSprite.itemId = k
                itemSprite.itemName = v.name
                itemSprite.serverId = k
                -- Guarda a funo original do onMouseRelease
                itemSprite.originalOnMouseRelease = UIItem.onMouseRelease
                -- Adiciona handler de clique direito para criar menu de contexto
                itemSprite.onMouseRelease = function(self, mousePosition, mouseButton)
                    -- Clique direito para criar menu de contexto customizado
                    if mouseButton == MouseRightButton and self:containsPoint(mousePosition) then
                        local localPlayer = g_game.getLocalPlayer()
                        if not localPlayer or not self.itemId then
                            return false
                        end
                        
                        -- Cria um menu de contexto simplificado
                        local menu = g_ui.createWidget("PopupMenu")
                        menu:setGameMenu(true)
                        
                        -- Adiciona opo Open auto loot list
                        menu:addOption(tr('Open auto loot list'), function() 
                            modules.game_interface.openAutolootWindow() 
                        end)
                        
                        menu:addSeparator()
                        
                        -- Adiciona ou Remove da lista de autoloot
                        if localPlayer:isInAutoLootList(self.itemId) then
                            menu:addOption(tr('Remove from auto loot list'), function() 
                                localPlayer:removeAutoLoot(self.itemId, self.itemName or "") 
                            end)
                        else
                            menu:addOption(tr('Add to auto loot list'), function() 
                                localPlayer:addAutoLoot(self.itemId, self.itemName or "") 
                            end)
                        end
                        
                        -- Mostra o menu na posio do mouse
                        menu:display(mousePosition)
                        return true
                    end
                    -- Para outros cliques, chama o comportamento padro
                    if self.originalOnMouseRelease then
                        return self.originalOnMouseRelease(self, mousePosition, mouseButton)
                    end
                    return false
                end
            else
                -- Atualiza o itemId e itemName caso o widget j exista
                itemSprite.itemId = k
                itemSprite.itemName = v.name
                itemSprite.serverId = k
            end
            -- k = serverId (chave e autoloot). Sprite usa clientId para cone correto (dragon ham etc).
            itemSprite:setItemId((v.clientId ~= nil) and v.clientId or k)
            itemSprite:setMarginTop(items * 34 + 17)
            itemSprite:setMarginLeft(5)

            local count = v.amount
            if count >= 1000 then
                count = (count / 1000) .."k"
            end

            local itemLabel = lootedItemsLabel:getChildById("itemLabel"..k)
            if not itemLabel then
                itemLabel = g_ui.createWidget("ItemNameLabel", lootedItemsLabel)
                itemLabel:setId("itemLabel"..k)
                itemLabel:addAnchor(AnchorLeft, "image"..k, AnchorRight)
                itemLabel:addAnchor(AnchorTop, "image"..k, AnchorTop)
                itemLabel:setMarginLeft(5)
            end
            itemLabel:setText(v.name)

            local lootLabel = lootedItemsLabel:getChildById("lootLabel"..k)
            if not lootLabel then
                lootLabel = g_ui.createWidget("LootLabel", lootedItemsLabel)
                lootLabel:setId("lootLabel"..k)
                lootLabel:addAnchor(AnchorBottom, "image"..k, AnchorBottom)
                lootLabel:addAnchor(AnchorLeft, "image"..k, AnchorRight)
                lootLabel:setMarginLeft(5)
            end
            lootLabel:setText("x" .. count)

            items = items + 1
        end
        lootedItemsLabel:setHeight((items * 33 + 60) + 20)
    end
end

function resetDropTracker()
	resetLootedItems()
	lootedItems = {}
	lootedItemsParty = {}
end

function setLootView(view)
	currentLootView = view
	local data = currentLootView == "party" and lootedItemsParty or lootedItems
	updateDropTracker(data)
end

function hideZeroDamageTypes()
  local window = modules.game_interface.getRootPanel():recursiveGetChildById("damageWindow")
  
  for _, damageType in ipairs(allTypes) do
    local widget = window:recursiveGetChildById(damageType)
    if widget then
	  widget:setVisible(false)
    end
  end
end

function refresh()
	local player = g_game.getLocalPlayer()
	if not player then return end
	resetExpH()

    hideZeroDamageTypes()
    resetDamageAnalyzer()
	resetPartyAnalyzer()
    startFreshanalyzerWindow()
    totalKills = 0
    killedCreatures = {}
end

function offline()
	startFreshanalyzerWindow()
	resetLootedItems()
	lootedItems = {}
	lootedItemsParty = {}
	resetKilledMonsters()
    hideZeroDamageTypes()
    resetDamageAnalyzer()
    resetPartyAnalyzer()
    totalKills = 0
	killedCreatures = {}
end

function onKillTrackerExtendedOpcode(protocol, opcode, buffer)
	local ok, data = pcall(json.decode, buffer)
	if not ok or type(data) ~= "table" or data.type ~= "kill" then return end
	local monsterName = data.name
	if not monsterName then return end
	local lookType = data.lookType or 19
	local lookHead = data.lookHead or 0
	local lookBody = data.lookBody or 0
	local lookLegs = data.lookLegs or 0
	local lookFeet = data.lookFeet or 0
	local addons = data.addons or 0
	local items = {}
	local isParty = data.isParty or false
	for _, it in ipairs(data.items or {}) do
		local clientId = it.clientId or it.id
		local serverId = it.serverId
		local count = it.count or 1
		local name = it.name or "?"
		if not serverId then
			-- fallback: server antigo sem serverId; usa clientId como chave
			serverId = clientId
		end
		local item = Item.create(clientId, count)
		if item then
			table.insert(items, { name, item, serverId, clientId })
		end
	end
	injectKillTracker(monsterName, lookType, lookHead, lookBody, lookLegs, lookFeet, addons, items, isParty)
end

function toggle()
  mainWindow:setOn(not mainWindow:isVisible())
  if mainWindow:isVisible() then
	mainWindow:close()
  else
	mainWindow:open()
  end
end

function onMiniWindowClose()
    analyzerButton:setOn(false)
end

function onExtendedOpcode(protocol, opcode, buffer)
  local ok, data = pcall(json.decode, buffer)
  if not ok or type(data) ~= "table" or data.type ~= "dmg" then return end
  local window = modules.game_interface.getRootPanel():recursiveGetChildById("damageWindow")
  if not window then return end
  local vals = data.vls or {}
  local total = 0
  local dealt = 0
  for _, t in ipairs(allTypes) do
    local val = vals[t] or 0
    if val > 0 then
      total = total + val
    end
  end

  for _, t in ipairs(allTypes) do
      local w = window:recursiveGetChildById(t)
      local lbl = w and w:recursiveGetChildById("damageValue")
      local icon = w and w:recursiveGetChildById("icon")
      local d = vals[t] or 0
      local pct = total > 0 and (d / total * 100) or 0
  
      if d <= 0 then
        if w then w:setVisible(false) end
      else
        if w then w:setVisible(true) end
          if lbl then lbl:setText(("%s (%.1f%%)"):format(number_format(d), pct)) end
        if icon then icon:setVisible(true) end
      end
  end
  
  do
    local w   = window:recursiveGetChildById("totalDamage")
    local lbl = w and w:recursiveGetChildById("damageValue")
    if lbl then lbl:setText(number_format(total)) end
  end
  
  local dpsReceived = data.dpsR or 0
  do
    local w   = window:recursiveGetChildById("dps")
    local lbl = w and w:recursiveGetChildById("damageValue")
    if lbl then lbl:setText(number_format(dpsReceived)) end
  end

  local w   = window:recursiveGetChildById("topDpsRcv")
  local lbl = w and w:recursiveGetChildById("damageValue")
  if lbl and topDpsR < dpsReceived then
	topDpsR = dpsReceived
	lbl:setText(number_format(topDpsR))
  end
  
  if dpsGraph:getGraphsCount() == 0 then
  	dpsGraph:createGraph()
  	dpsGraph:setTitle("DPS (R)")
  	dpsGraph:setLineWidth(1, 1)
  	dpsGraph:setLineColor(1,"#FF00FF")
  end
  dpsGraph:addValue(1, dpsReceived)
	  
  local w   = window:recursiveGetChildById("dltDmg")
  local lbl = w and w:recursiveGetChildById("damageValue")
  if lbl then
    lbl:setText(number_format(data.dmgD))
  end
	
  local dpsDealt = data.dpsD or 0
  local w   = window:recursiveGetChildById("dpsDlt")
  local lbl = w and w:recursiveGetChildById("damageValue")
  if lbl then
    lbl:setText(number_format(dpsDealt))
  end

  local w   = window:recursiveGetChildById("topDpsDlt")
  local lbl = w and w:recursiveGetChildById("damageValue")
  if lbl and topDpsD < dpsDealt then
	topDpsD = dpsDealt
	lbl:setText(number_format(topDpsD))
  end

	if dpsDealtGraph:getGraphsCount() == 0 then
		dpsDealtGraph:createGraph()
		dpsDealtGraph:setTitle("DPS (D)")
		dpsDealtGraph:setLineWidth(1, 1)
		dpsDealtGraph:setLineColor(1,"#FF00FF")
	end
	dpsDealtGraph:addValue(1, dpsDealt)

  --PARTY ANALYZER
    local party = data.pty
    local window = modules.game_interface.getRootPanel():recursiveGetChildById("partyWindow")
    if not window then return end
    
    local contentsPanel = window:recursiveGetChildById("contentsPanel")
    if not contentsPanel then return end

    for _, child in pairs(contentsPanel:getChildren()) do
        if child:getId() ~= "headerPanel" and child:getId() ~= "headerSeparator" then
            child:destroy()
        end
    end
	
    local totalLoot = 0
    local totalWaste = 0

    if type(party) == "table" then
      for i, member in ipairs(party) do
        totalLoot = totalLoot + (member.loot or 0)
        totalWaste = totalWaste + (member.waste or 0)

        local partyPanel = g_ui.createWidget("MemberPanel", contentsPanel)
        if partyPanel then

          local nameLabel = g_ui.createWidget("MemberNameLabel", partyPanel)
          nameLabel:setText(member.nm or "-")
    	  if member.le == tonumber(1) then
            nameLabel:setColor("yellow")
            local leaderShield = g_ui.createWidget("Shield", partyPanel)
            leaderShield:setImageSource("/images/game/shields/shield_yellow")
            leaderShield:setTooltip("Party Leader")
    	  else
    	    nameLabel:setColor("white")
    	    local memberShield = g_ui.createWidget("Shield", partyPanel)
    	  end

    	  local rTypeIcon = g_ui.createWidget("TypeIcon", partyPanel)
		  rTypeIcon:setImageSource("/images/game/elements/damage")
		  
    	  local rTypeLabel = g_ui.createWidget("TypeLabel", partyPanel)
    	  rTypeLabel:setText("Received:")

          local receivedDamageLabel = g_ui.createWidget("DamageValueLabel", partyPanel)
          receivedDamageLabel:setText(number_format(member.re or 0))
    	  receivedDamageLabel:setColor("#edebeb")
    	  receivedDamageLabel:setTextAlign(AlignRight)

    	  local dTypeIcon = g_ui.createWidget("TypeIcon", partyPanel)
		  dTypeIcon:setImageSource("/images/game/elements/damage_green")
    	  dTypeIcon:setMarginTop(23)
		  
          local dTypeLabel = g_ui.createWidget("TypeLabel", partyPanel)
    	  dTypeLabel:setText("Dealt:")
    	  dTypeLabel:setMarginTop(22)
		  
          local dealtDamageLabel = g_ui.createWidget("DamageValueLabel", partyPanel)
          dealtDamageLabel:setText(number_format(member.de or 0))
    	  dealtDamageLabel:setColor("#edebeb")
    	  dealtDamageLabel:setTextAlign(AlignRight)
          dealtDamageLabel:setMarginTop(17)  
          
    	  local separator = g_ui.createWidget("Separator", partyPanel)
        end
      end
    end

    -- Update Top Panel Summary
    local headerPanel = window:recursiveGetChildById("headerPanel")
    if headerPanel then
      local sessionCtx = headerPanel:getChildById("sessionCtx")
      if sessionCtx then
        local val = sessionCtx:getChildById("value")
        if val then
          -- Get session time from expHVar.sessionStart 
          local _session = 0
          if expHVar.sessionStart > 0 then
            _session = math.floor(g_clock.seconds() - expHVar.sessionStart)
          end
          val:setText(getTimeFormat(_session))
        end
      end

      local lootCtx = headerPanel:getChildById("lootCtx")
      if lootCtx then
        local val = lootCtx:getChildById("value")
        if val then val:setText(number_format(totalLoot)) end
      end

	local supplyCtx = headerPanel:getChildById("supplyCtx")
	if supplyCtx then
	  local val = supplyCtx:getChildById("value")
	  if val then
		val:setText("-" .. number_format(totalWaste))
		val:setColor("#ff5555")
	  end
	end

      local balanceCtx = headerPanel:getChildById("balanceCtx")
      if balanceCtx then
        local val = balanceCtx:getChildById("value")
        if val then
          local bal = totalLoot - totalWaste
          val:setText(number_format(bal))
          val:setColor(bal >= 0 and "#55ff55" or "#ff5555")
        end
      end
    end

    -- Update Individual Stats in Exp Analyzer
    local localPlayer = g_game.getLocalPlayer()
    if localPlayer then
      local pLoot = data.loot or 0
      local pWaste = data.waste or 0
      
      local pBalance = pLoot - pWaste
	setSkillValue('lootCtx', number_format(pLoot))

	setSkillValue('supplyCtx', "-" .. number_format(pWaste))
	setSkillColor('supplyCtx', "#ff5555")
      
      local balWidget = expWindow:recursiveGetChildById('balanceCtx')
      if balWidget then
        local val = balWidget:getChildById('value')
        if val then
          val:setText(number_format(pBalance))
          val:setColor(pBalance >= 0 and "#55ff55" or "#ff5555")
        end
      end
    end
  end
  
function resetDamageAnalyzer()
  local window = modules.game_interface.getRootPanel():recursiveGetChildById("damageWindow")
  if not window then return end

  for _, dmgType in ipairs(allTypes) do
    local dmgWidget = window:recursiveGetChildById(dmgType)
    if dmgWidget then
      local valueLabel = dmgWidget:recursiveGetChildById("damageValue")
      if valueLabel then
        valueLabel:setText("0 (0.0%)")
      end
    end
  end
  
	setDamageColor('totalDamage',	'#edebeb')
	setDamageColor('dps',	'#edebeb')
	setDamageColor('topDpsRcv',	'#edebeb')
	setDamageColor('ph',	'#edebeb')
	setDamageColor('ea',	'#edebeb')
	setDamageColor('fi',	'#edebeb')
	setDamageColor('ic',	'#edebeb')
	setDamageColor('en',	'#edebeb')
	setDamageColor('de',	'#edebeb')
	setDamageColor('ho',	'#edebeb')
	setDamageColor('ld',	'#edebeb')
	setDamageColor('md',	'#edebeb')
	setDamageColor('dr',	'#edebeb')
	setDamageColor('dltDmg',	'#edebeb')
	setDamageColor('dpsDlt',	'#edebeb')
	setDamageColor('topDpsDlt',	'#edebeb')
  
  if dpsGraph then
  	  dpsGraph:clear()
    end
  
    if dpsDealtGraph then
  	  dpsDealtGraph:clear()
   end
    
  local totalBtn = window:recursiveGetChildById("totalDamage")
  if totalBtn then
    local valueLabel = totalBtn:recursiveGetChildById("damageValue")
    if valueLabel then
  	valueLabel:setText("0")
    end
  end
  
  local dpsRecBtn = window:recursiveGetChildById("dps")
  if dpsRecBtn then
    local valueLabel = dpsRecBtn:recursiveGetChildById("damageValue")
    if valueLabel then
  	valueLabel:setText("0")
    end
  end
  
  local topDpsRecBtn = window:recursiveGetChildById("topDpsRcv")
  if topDpsRecBtn then
    local valueLabel = topDpsRecBtn:recursiveGetChildById("damageValue")
    if valueLabel then
      valueLabel:setText("0")
    end
  end
  
  local dealtBtn = window:recursiveGetChildById("dltDmg")
  if dealtBtn then
    local valueLabel = dealtBtn:recursiveGetChildById("damageValue")
    if valueLabel then
      valueLabel:setText("0")
    end
  end
  
  local dpsDealtBtn = window:recursiveGetChildById("dpsDlt")
  if dpsDealtBtn then
    local valueLabel = dpsDealtBtn:recursiveGetChildById("damageValue")
    if valueLabel then
      valueLabel:setText("0")
    end
  end
  
  local topDpsDealtBtn = window:recursiveGetChildById("topDpsDlt")
  if topDpsDealtBtn then
    local valueLabel = topDpsDealtBtn:recursiveGetChildById("damageValue")
    if valueLabel then
      valueLabel:setText("0")
    end
  end
  
  sendOpcode({topic = "resetD"})
end

function resetPartyAnalyzer()
  sendOpcode({topic = "resetP"})
  local window = modules.game_interface.getRootPanel():recursiveGetChildById("partyWindow")
  if not window then return end

  local contentsPanel = window:recursiveGetChildById("contentsPanel")
  if contentsPanel then
    for _, child in pairs(contentsPanel:getChildren()) do
        if child:getId() ~= "headerPanel" and child:getId() ~= "headerSeparator" then
            child:destroy()
        end
    end
  end

  local headerPanel = window:recursiveGetChildById("headerPanel")
  if headerPanel then
    local sessionCtx = headerPanel:getChildById("sessionCtx")
    if sessionCtx and sessionCtx:getChildById("value") then sessionCtx:getChildById("value"):setText("00:00") end
    
    local lootCtx = headerPanel:getChildById("lootCtx")
    if lootCtx and lootCtx:getChildById("value") then lootCtx:getChildById("value"):setText("0") end
    
    local supplyCtx = headerPanel:getChildById("supplyCtx")
    if supplyCtx and supplyCtx:getChildById("value") then supplyCtx:getChildById("value"):setText("0") end
    
    local balanceCtx = headerPanel:getChildById("balanceCtx")
    if balanceCtx and balanceCtx:getChildById("value") then
      local val = balanceCtx:getChildById("value")
      val:setText("0")
      val:setColor("#AFAFAF")
    end
  end
end

function sendOpcode(data)
  local protocolGame = g_game.getProtocolGame()
  if protocolGame then
	  protocolGame:sendExtendedJSONOpcode(DAMAGETRACKER_OPCODE, data)
  end
end
  
function onAnalyzerClose()
  if analyzerButton then
    analyzerButton:setOn(false)
  end
end
