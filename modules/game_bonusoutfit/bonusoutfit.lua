local OUTFIT_BONUS_OPCODE = 115

bonusOutfitWindow = nil
bonusButton = nil
activeLookType = 0
selectedLookType = 0
local currentPage = 1
local totalPages = 1

local categories = {
  --{id = 'all', name = 'Todos os Bônus', match = nil, icon = '/images/icons/all'},
  {id = 'ml', name = 'Magic Level', match = 'ML', icon = '/images/icons/icon_ml'},
  {id = 'health', name = 'Vida', match = 'HP', icon = '/images/icons/icon_hp'},
  {id = 'mana', name = 'Mana', match = 'MP', icon = '/images/icons/icon_mp'},
  {id = 'sword', name = 'Skill [Sword]', match = 'Sword', icon = '/images/icons/skill_sw'},
  {id = 'axe', name = 'Skill [Axe]', match = 'Axe', icon = '/images/icons/skill_ax'},
  {id = 'club', name = 'Skill [Club]', match = 'Club', icon = '/images/icons/skill_cb'},
  {id = 'distance', name = 'Skill [Distance]', match = 'Dist', icon = '/images/icons/skill_ds'},
  {id = 'shield', name = 'Shielding', match = 'Shield', icon = '/images/icons/icon_shield'},
  {id = 'critical', name = 'Critical', match = 'Crit', icon = '/images/icons/icon_crit'},
  {id = 'fire', name = 'Def. Fire', match = 'Fire Prot', icon = '/images/icons/def_fire'},
  {id = 'earth', name = 'Def. Earth', match = 'Earth Prot', icon = '/images/icons/def_earth'},
  {id = 'energy', name = 'Def. Energy', match = 'Energy Prot', icon = '/images/icons/def_energy'},
  {id = 'death', name = 'Def. Death', match = 'Death Prot', icon = '/images/icons/def_death'},
  {id = 'ice', name = 'Def. Ice', match = 'Ice Prot', icon = '/images/icons/def_ice'},
  {id = 'holy', name = 'Def. Holy', match = 'Holy Prot', icon = '/images/icons/def_holy'},
  {id = 'physical', name = 'Def. Física', match = 'Physical Prot', icon = '/images/icons/def_fis'},
  {id = 'speed', name = 'Velocidade', match = 'Speed', icon = '/images/icons/haste'}
}
local currentCategory = 'all'
local allAvailableOutfits = {}

function init()
  connect(g_game, {
    onGameStart = online,
    onGameEnd = offline
  })
  
  ProtocolGame.registerExtendedOpcode(OUTFIT_BONUS_OPCODE, onExtendedOpcode)

  bonusOutfitWindow = g_ui.displayUI('bonusoutfit')
  bonusOutfitWindow:hide()
  
  setupCategories()
  
  if g_game.isOnline() then
    online()
  end
end

function setupCategories()
  local categoryList = bonusOutfitWindow:getChildById('leftPanel'):getChildById('categoryList')
  
  for _, cat in ipairs(categories) do
    local btn = g_ui.createWidget('CategoryButton', categoryList)
    btn:setId(cat.id)
    btn:setText(cat.name)
    if cat.icon then
      btn:setIcon(cat.icon)
    end
    btn.onClick = function()
      currentCategory = cat.id
      for _, child in pairs(categoryList:getChildren()) do
        if child == btn then
          child:setColor('#00FF00')
        else
          child:setColor('#cccccc')
        end
      end
      currentPage = 1
      fetchFromServer()
    end
    
    if cat.id == 'all' then
      btn:setColor('#00FF00')
    else
      btn:setColor('#cccccc')
    end
  end
end

function terminate()
  disconnect(g_game, {
    onGameStart = online,
    onGameEnd = offline
  })
  
  ProtocolGame.unregisterExtendedOpcode(OUTFIT_BONUS_OPCODE, onExtendedOpcode)

  if bonusOutfitWindow then
    bonusOutfitWindow:destroy()
    bonusOutfitWindow = nil
  end
  
  if bonusButton then
    bonusButton:destroy()
    bonusButton = nil
  end
end

function toggle()
  if bonusOutfitWindow:isVisible() then
    bonusOutfitWindow:hide()

  else
    bonusOutfitWindow:show()
    bonusOutfitWindow:raise()
    bonusOutfitWindow:focus()
    currentPage = 1
    fetchFromServer()
  end
end

function online()
end

function offline()
  if bonusOutfitWindow then
    bonusOutfitWindow:hide()
  end
  if bonusButton then

  end
end

function onExtendedOpcode(protocol, opcode, buffer)
  if opcode ~= OUTFIT_BONUS_OPCODE then return end
  local status, json_data = pcall(function() return json.decode(buffer) end)
  if not status or not json_data then return end

  if json_data.action == "init" then
    activeLookType = json_data.active or 0
    currentPage = json_data.currentPage or 1
    totalPages = json_data.totalPages or 1
    updateUI(json_data.available or {})
  end
end

function fetchFromServer()
  if not bonusOutfitWindow then return end

  local bottomPanel = bonusOutfitWindow:getChildById('bottomPanel')
  local filterCheckbox = bottomPanel:getChildById('filterUnlocked')
  local showOnlyUnlocked = filterCheckbox:isChecked()
  
  local activeMatch = "all"
  for _, cat in ipairs(categories) do
    if cat.id == currentCategory then
      activeMatch = cat.match
      break
    end
  end

  local protocolGame = g_game.getProtocolGame()
  if protocolGame then
    protocolGame:sendExtendedOpcode(OUTFIT_BONUS_OPCODE, json.encode({
      action = "fetch",
      page = currentPage,
      category = activeMatch,
      showUnlocked = showOnlyUnlocked
    }))
  end
end

function onFilterChange()
  currentPage = 1
  fetchFromServer()
end

function prevPage()
  if currentPage > 1 then
    currentPage = currentPage - 1
    fetchFromServer()
  end
end

function nextPage()
  if currentPage < totalPages then
    currentPage = currentPage + 1
    fetchFromServer()
  end
end

function updateUI(availableOutfits)
  if not bonusOutfitWindow then return end
  allAvailableOutfits = availableOutfits or {}
  updateFilter()
end

function updateFilter()
  if not bonusOutfitWindow then return end
  
  local list = bonusOutfitWindow:getChildById('outfitList')
  list:destroyChildren()
  
  local topPanel = bonusOutfitWindow:getChildById('topPanel')
  local activeOutfitContainer = topPanel:getChildById('activeOutfitContainer')
  local activeOutfitWidget = activeOutfitContainer and activeOutfitContainer:getChildById('activeOutfit')
  local activeOutfitShadow = topPanel:getChildById('activeOutfitShadow')
  local activeDescLabel = topPanel:getChildById('activeDesc')
  local removeActiveBtn = topPanel:getChildById('removeActiveButton')
  
  local pagePanel = bonusOutfitWindow:getChildById('pagePanel')
  if pagePanel then
    local pageLabel = pagePanel:getChildById('pageLabel')
--    if pageLabel then
--      pageLabel:setText(string.format("Página %d de %d", currentPage, totalPages))
--    end
  end
  
  local player = g_game.getLocalPlayer()
  local playerOutfit = player and player:getOutfit() or {head = 0, body = 0, legs = 0, feet = 0}
  
  local foundActiveDesc = false
  
  local foundActiveDesc = false
  
  for _, outfitData in ipairs(allAvailableOutfits) do
    local lookType = outfitData.lookType
    local desc = outfitData.desc or ""
    local unlocked = outfitData.unlocked
    
    -- Active bonus logic for top panel
    if lookType == activeLookType then
      local outfit = {
        type = lookType,
        head = playerOutfit.head or 0,
        body = playerOutfit.body or 0,
        legs = playerOutfit.legs or 0,
        feet = playerOutfit.feet or 0,
        addons = 3
      }
      if activeOutfitWidget then
        activeOutfitWidget:setOutfit(outfit)
        activeOutfitWidget:setCenter(true)
      end
      if activeOutfitContainer then activeOutfitContainer:show() end
      if activeOutfitShadow then activeOutfitShadow:show() end
      if removeActiveBtn then removeActiveBtn:show() end
      activeDescLabel:setText("Bônus fornecidos por esta roupa:\n" .. desc)
      foundActiveDesc = true
    end
    
    local creature = g_ui.createWidget('BonusCreature', list)
      
      local outfitContainer = creature:getChildById('outfitContainer')
      local descContainer = creature:getChildById('descContainer')
      
      local outfitWidget = outfitContainer:getChildById('outfit')
      local descLabel = descContainer:getChildById('desc')
      local nameLabel = creature:getChildById('outfitName')
      local selectBtn = creature:getChildById('selectButton')
      
      local outfit = {
        type = lookType,
        head = playerOutfit.head or 0,
        body = playerOutfit.body or 0,
        legs = playerOutfit.legs or 0,
        feet = playerOutfit.feet or 0,
        addons = 3
      }
      
      outfitWidget:setOutfit(outfit)
      outfitWidget:setCenter(true)
      descLabel:setText(desc)
      nameLabel:setText(outfitData.name or "Outfit")
      
      if not unlocked then
        creature:setOpacity(0.5)
        outfitContainer:setImageColor('#444444')
        descContainer:setImageColor('#444444')
        selectBtn:disable()
      end
      
      if lookType == activeLookType then
        selectBtn:setText('Remover')
        selectBtn.onClick = function()
          removeBonus()
        end
      else
        selectBtn:setText('Selecionar')
        selectBtn.onClick = function()
          if not unlocked then return end
          for _, child in pairs(list:getChildren()) do
            child:setChecked(false)
          end
          creature:setChecked(true)
          selectedLookType = lookType
          
          local bottomPanel = bonusOutfitWindow:getChildById('bottomPanel')
          local filterCheckbox = bottomPanel:getChildById('filterUnlocked')
          local activeMatch = "all"
          for _, cat in ipairs(categories) do
            if cat.id == currentCategory then
              activeMatch = cat.match
              break
            end
          end

          local protocolGame = g_game.getProtocolGame()
          if protocolGame then
            protocolGame:sendExtendedOpcode(OUTFIT_BONUS_OPCODE, json.encode({
              action = "set", 
              lookType = selectedLookType,
              page = currentPage,
              category = activeMatch,
              showUnlocked = filterCheckbox:isChecked()
            }))
          end
        end
      end
      
      if lookType == activeLookType then
        creature:setChecked(true)
        selectedLookType = lookType
      end
  end
  
  if not foundActiveDesc then
    if activeOutfitContainer then activeOutfitContainer:hide() end
    if activeOutfitShadow then activeOutfitShadow:hide() end
    if removeActiveBtn then removeActiveBtn:hide() end
    activeDescLabel:setText("Nenhum bônus ativo no momento.")
  end
end

function removeBonus()
  local protocolGame = g_game.getProtocolGame()
  if protocolGame then
    protocolGame:sendExtendedOpcode(OUTFIT_BONUS_OPCODE, json.encode({action = "set", lookType = 0}))
  end
end
