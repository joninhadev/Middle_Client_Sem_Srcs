local lookupWindow
local lookupButton
local searchInput
local resultList
local OPCODE_LOOT_LOOKUP = 51

local currentMonsters = {}
local currentPage = 1
local ITEMS_PER_PAGE = 12
local isSearching = false

local function normalizeOutfit(outfit)
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

local function showPage(page)
  if not resultList then return end
  resultList:destroyChildren()

  currentPage = page
  local totalPages = math.max(1, math.ceil(#currentMonsters / ITEMS_PER_PAGE))

  local pageLabel = lookupWindow:recursiveGetChildById('pageLabel')
  if pageLabel then
    pageLabel:setText(currentPage .. '/' .. totalPages)
  end

  local prevButton = lookupWindow:recursiveGetChildById('prevButton')
  if prevButton then
    prevButton:setEnabled(currentPage > 1)
  end

  local nextButton = lookupWindow:recursiveGetChildById('nextButton')
  if nextButton then
    nextButton:setEnabled(currentPage < totalPages)
  end

  local startIndex = (currentPage - 1) * ITEMS_PER_PAGE + 1
  local endIndex = math.min(startIndex + ITEMS_PER_PAGE - 1, #currentMonsters)

  if #currentMonsters == 0 then
    local label = g_ui.createWidget('Label', resultList)
    label:setText("Nenhum monstro encontrado.")
    label:setTextAlign(AlignCenter)
    label:setColor('#AAAAAA')
    return
  end

  for i = startIndex, endIndex do
    local monsterData = currentMonsters[i]
    if monsterData then
      local box = g_ui.createWidget('LootCreatureBox', resultList)

      local creatureWidget = box:getChildById('creature')
      creatureWidget:setOutfit(normalizeOutfit(monsterData.outfit))
      creatureWidget:setAnimate(true)

      local nameLabel = box:getChildById('name')
      nameLabel:setText(monsterData.name)

      box:setTooltip(monsterData.name)
    end
  end
end

local function onReceiveLootData(protocol, opcode, buffer)
  if opcode ~= OPCODE_LOOT_LOOKUP then
    return
  end
  
  if not isSearching then
    return
  end

  local status, data = pcall(function() return json.decode(buffer) end)
  if not status or not data or type(data) ~= 'table' then
    return
  end

  isSearching = false

  if resultList then resultList:destroyChildren() end

  if data.error then
    local label = g_ui.createWidget('Label', resultList)
    label:setText(data.error)
    currentMonsters = {}
  else
    currentMonsters = data.monsters or {}
    showPage(1)
  end
end

function init()
  connect(g_game, { onGameStart = create,
                    onGameEnd = destroy })

  ProtocolGame.registerExtendedOpcode(OPCODE_LOOT_LOOKUP, onReceiveLootData)

  if g_game.isOnline() then
    create()
  end
end

function terminate()
  disconnect(g_game, { onGameStart = create,
                       onGameEnd = destroy })

  ProtocolGame.unregisterExtendedOpcode(OPCODE_LOOT_LOOKUP)

  destroy()
end

function sendSearch()
  if not searchInput then return end
  local searchText = searchInput:getText()
  if searchText:len() > 0 then
    local protocolGame = g_game.getProtocolGame()
    if protocolGame then
      isSearching = true
      local jsonRequest = json.encode({action = 'search', data = searchText})
      protocolGame:sendExtendedOpcode(OPCODE_LOOT_LOOKUP, jsonRequest)
    end
  end
end

function toggle()
  if not lookupWindow then
    return
  end

  if lookupWindow:isVisible() then
    lookupWindow:hide()
  else
    lookupWindow:show()
    lookupWindow:raise()
    lookupWindow:focus()
  end
end

function create()
  if lookupWindow then
    return
  end

  lookupWindow = g_ui.displayUI('loot_lookup')
  lookupWindow.onEscape = toggle
  lookupWindow:hide()

  searchInput = lookupWindow:recursiveGetChildById('searchInput')
  resultList = lookupWindow:recursiveGetChildById('resultList')
  
  local searchButton = lookupWindow:recursiveGetChildById('searchButton')
  searchButton.onClick = sendSearch

  local prevButton = lookupWindow:recursiveGetChildById('prevButton')
  prevButton.onClick = function() showPage(currentPage - 1) end

  local nextButton = lookupWindow:recursiveGetChildById('nextButton')
  nextButton.onClick = function() showPage(currentPage + 1) end

  searchInput.onKeyPress = function(self, keyCode, keyboardModifiers)
    if keyCode == KeyEnter or keyCode == KeyKpEnter then
      sendSearch()
      return true
    end
    return false
  end
  
  local closeButton = lookupWindow:recursiveGetChildById('closeButton')
  closeButton.onClick = toggle

  if modules.client_topmenu then
    lookupButton = modules.client_topmenu.addLeftGameButton('lootLookupButton', tr('Search Drop'), '/images/topbuttons/search', toggle)
  end
end

function destroy()
  if lookupWindow then
    lookupWindow:destroy()
    lookupWindow = nil
  end

  if lookupButton then
    lookupButton:destroy()
    lookupButton = nil
  end
end


