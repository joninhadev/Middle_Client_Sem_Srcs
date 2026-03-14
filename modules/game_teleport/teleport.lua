local cities = {
  {name = "Edoras",    image = "/modules/game_teleport/images/edoras.png",   cmd = "edoras"},
  {name = "Dol Guldur",image = "/modules/game_teleport/images/dol.png",      cmd = "dol"},
  {name = "Minas Tirith", image = "/modules/game_teleport/images/minas.png", cmd = "minas"},
  {name = "Anfallas",  image = "/modules/game_teleport/images/anfallas.png", cmd = "anfallas"},
  {name = "Argond",    image = "/modules/game_teleport/images/argond.png",   cmd = "argond"},
  {name = "Dunedain",  image = "/modules/game_teleport/images/dunedain.png", cmd = "dunedain"},
  {name = "Bree",      image = "/modules/game_teleport/images/bree.png",     cmd = "bree"},
  {name = "Mordor",    image = "/modules/game_teleport/images/mordor.png",   cmd = "mordor"},
  {name = "Esgaroth",  image = "/modules/game_teleport/images/esg.png",      cmd = "esg"},
  {name = "Rivendell", image = "/modules/game_teleport/images/rivendell.png",cmd = "rivendell"},
  {name = "Forodwaith",image = "/modules/game_teleport/images/forod.png",    cmd = "forod"},
  {name = "Moria",     image = "/modules/game_teleport/images/moria.png",    cmd = "moria"},
  {name = "Condado",   image = "/modules/game_teleport/images/condado.png",  cmd = "condado"},
  {name = "Enedwaith", image = "/modules/game_teleport/images/enedwaith.png",cmd = "enedwaith"},
  {name = "Umbar",     image = "/modules/game_teleport/images/umbar.png",    cmd = "umbar"}
}

local teleportWindow
local teleportButton
local selectedCity = nil
local OPCODE_TELEPORT = 52

function init()
  teleportWindow = g_ui.displayUI('teleport')
  teleportWindow:hide()
  
  -- Add button to top menu
  teleportButton = modules.client_topmenu.addRightGameToggleButton('teleportButton', tr('Teleportar'), '/images/topbuttons/teleport_icon', toggle)
  
  -- Bind teleport button
  local btn = teleportWindow:getChildById('teleportButton')
  if btn then
     btn.onClick = teleport
  end
  
  refreshCities()
end

function terminate()
  if teleportButton then
    teleportButton:destroy()
  end
  
  if teleportWindow then
    teleportWindow:destroy()
  end
end


function shuffle(t)
  local n = #t
  for i = n, 2, -1 do
    local j = math.random(i)
    t[i], t[j] = t[j], t[i]
  end
end

function refreshCities()
  local list = teleportWindow:getChildById('cityList')
  if not list then return end
  
  list:destroyChildren()
  
  -- Create a copy to shuffle so we don't mess up original order permanently if needed elsewhere (though here it doesn't matter much)
  -- Actually, let's just shuffle the table in place or a shallow copy.
  local shuffledCities = {unpack(cities)}
  shuffle(shuffledCities)
  
  for _, city in ipairs(shuffledCities) do
    local widget = g_ui.createWidget('TeleportCityButton', list)
    local cityImage = widget:getChildById('cityImage')
    local cityName = widget:getChildById('cityName')
    
    cityName:setText(city.name)
    cityImage:setImageSource(city.image)
    
    widget.onClick = function()
      selectCity(widget, city)
    end
  end
end

function selectCity(widget, cityData)
    -- Reset previous selection
    local list = teleportWindow:getChildById('cityList')
    if list then
        for _, child in pairs(list:getChildren()) do
            child:setOn(false)
            child:getChildById('cityImage'):setOpacity(0.5)
        end
    end

    -- Set new selection
    widget:setOn(true)
    widget:getChildById('cityImage'):setOpacity(1.0)
    selectedCity = cityData
    
    local btn = teleportWindow:getChildById('teleportButton')
    if btn then
        btn:setEnabled(true)
    end
end

function teleport()
    if not selectedCity then return end
    
    local protocol = g_game.getProtocolGame()
    if protocol then
        protocol:sendExtendedOpcode(OPCODE_TELEPORT, json.encode({action = 'teleport', city = selectedCity.cmd}))
    end
    -- Reset selection after teleport? Or keep it? keeping it for now.
    toggle() -- hide window
end

function toggle()
  if teleportWindow:isVisible() then
    teleportWindow:hide()
    if teleportButton then teleportButton:setOn(false) end
  else
    teleportWindow:show()
    teleportWindow:raise()
    teleportWindow:focus()
    if teleportButton then teleportButton:setOn(true) end
    
    -- Reset selection on open
    selectedCity = nil
    local btn = teleportWindow:getChildById('teleportButton')
    if btn then btn:setEnabled(false) end
    refreshCities() -- re-render to clear selection visual state
  end
end
