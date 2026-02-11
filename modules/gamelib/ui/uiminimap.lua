function UIMinimap:onCreate()
  self.autowalk = true
end

function UIMinimap:onSetup()
  self.flagWindow = nil
  self.flags = {}
  self.alternatives = {}
  self.onAddAutomapFlag = function(pos, icon, description) self:addFlag(pos, icon, description) end
  self.onRemoveAutomapFlag = function(pos, icon, description) self:removeFlag(pos, icon, description) end
  connect(g_game, {
    onAddAutomapFlag = self.onAddAutomapFlag,
    onRemoveAutomapFlag = self.onRemoveAutomapFlag,
  })
end

function UIMinimap:getAlternatives()
  return self.alternatives
end

function UIMinimap:onDestroy()
  for _,widget in pairs(self.alternatives) do
    widget:destroy()
  end
  self.alternatives = {}
  disconnect(g_game, {
    onAddAutomapFlag = self.onAddAutomapFlag,
    onRemoveAutomapFlag = self.onRemoveAutomapFlag,
  })
  self:destroyFlagWindow()
  self.flags = {}
end

function UIMinimap:onVisibilityChange()
  if not self:isVisible() then
    self:destroyFlagWindow()
  end
end

function UIMinimap:onCameraPositionChange(cameraPos)
  if self.cross then
    self:setCrossPosition(self.cross.pos)
  end
end

function UIMinimap:hideFloor()
  self.floorUpWidget:hide()
  self.floorDownWidget:hide()
end

function UIMinimap:hideZoom()
  self.zoomInWidget:hide()
  self.zoomOutWidget:hide()
end

function UIMinimap:disableAutoWalk()
  self.autowalk = false
end

function UIMinimap:load()
  local settings = g_settings.getNode('Minimap')
  if settings then
    if settings.flags then
      for _,flag in pairs(settings.flags) do
        self:addFlag(flag.position, flag.icon, flag.description)
      end
    end
    self:setZoom(settings.zoom)
  end
end

function UIMinimap:save()
  local settings = { flags={} }
  for _,flag in pairs(self.flags) do
    if not flag.temporary then
      table.insert(settings.flags, {
        position = flag.pos,
        icon = flag.icon,
        description = flag.description,
      })
    end
  end
  settings.zoom = self:getZoom()
  g_settings.setNode('Minimap', settings)
end

local function onFlagMouseRelease(widget, pos, button)
  if button == MouseRightButton then
    local menu = g_ui.createWidget('PopupMenu')
    menu:setGameMenu(true)
    menu:addOption(tr('Delete mark'), function() widget:destroy() end)
    menu:display(pos)
    return true
  end
  return false
end

local vocationIcons = {
    [1] = '/images/game/minimap/rookie.png',
    [2] = '/images/game/minimap/sorcerer.png',
    [3] = '/images/game/minimap/druid.png',
    [4] = '/images/game/minimap/paladin.png',
    [5] = '/images/game/minimap/knight.png',
    [6] = '/images/game/minimap/sorcerer.png',
    [7] = '/images/game/minimap/druid.png',
    [8] = '/images/game/minimap/paladin.png',
    [9] = '/images/game/minimap/knight.png',
    [10] = '/images/game/minimap/monk.png',
    [11] = '/images/game/minimap/samurai.png',
    [12] = '/images/game/minimap/bard.png',
    [13] = '/images/game/minimap/assassin.png',
    [14] = '/images/game/minimap/sorcerer.png',
    [15] = '/images/game/minimap/druid.png',
    [16] = '/images/game/minimap/paladin.png',
    [17] = '/images/game/minimap/knight.png',
    [18] = '/images/game/minimap/monk.png',
    [19] = '/images/game/minimap/monk.png',
    [20] = '/images/game/minimap/samurai.png',
    [21] = '/images/game/minimap/samurai.png',
    [22] = '/images/game/minimap/bard.png',
    [23] = '/images/game/minimap/bard.png',
    [24] = '/images/game/minimap/assassin.png',
    [25] = '/images/game/minimap/assassin.png',
    [26] = '/images/game/minimap/assassin.png',
    [27] = '/images/game/minimap/assassin.png',
    [28] = '/images/game/minimap/assassin.png',
    [29] = '/images/game/minimap/assassin.png',
    [30] = '/images/game/minimap/assassin.png',
    [31] = '/images/game/minimap/assassin.png',
    [32] = '/images/game/minimap/assassin.png',
    [33] = '/images/game/minimap/assassin.png',
    [34] = '/images/game/minimap/assassin.png',
    [35] = '/images/game/minimap/assassin.png',
    [36] = '/images/game/minimap/assassin.png',
    [37] = '/images/game/minimap/assassin.png',
    [38] = '/images/game/minimap/assassin.png',
    [39] = '/images/game/minimap/assassin.png',
    [40] = '/images/game/minimap/assassin.png',
    [41] = '/images/game/minimap/assassin.png',
    [42] = '/images/game/minimap/assassin.png',
    [43] = '/images/game/minimap/assassin.png',
    [44] = '/images/game/minimap/assassin.png',
    [45] = '/images/game/minimap/assassin.png',
    [46] = '/images/game/minimap/assassin.png',
    [47] = '/images/game/minimap/assassin.png',
    [48] = '/images/game/minimap/assassin.png',
    [49] = '/images/game/minimap/assassin.png',
    [50] = '/images/game/minimap/assassin.png',
    -- Add more as needed
}
g_partyIcons = {}

local partyWidgetIcons = {}
function UIMinimap:setCrossPartyPosition(name, vocationId, position)
	if partyWidgetIcons[name] then
		partyWidgetIcons[name]:destroy()
		partyWidgetIcons[name] = nil
	end

    if not name or not vocationId or not position then
        return
    end

    -- Get icon based on vocationId
    local iconPath = vocationIcons[vocationId + 1]
    if not iconPath then
        return
    end

    local partyIcon = g_ui.createWidget('MinimapCross', self)
    partyIcon:setImageSource(iconPath)
    partyIcon:setTooltip(name) -- Display the player's name when hovered
    partyIcon:setSize({ width = 32, height = 32 }) -- Adjust size as needed
	partyIcon:setClipping(true)
	partyWidgetIcons[name] = partyIcon


    -- Calculate screen position based on the game map position
    local screenPos = self:getCameraPosition()
    if not screenPos then
        return
    end

    -- Set the widget position
    self:centerInPosition(partyIcon, position)

    -- Optional: Add animations or effects
        partyIcon:show() -- Smooth fade-in effect

    -- Store reference for later removal if needed
    if not g_partyIcons then
        g_partyIcons = {}
    end
    g_partyIcons[#g_partyIcons + 1] = partyIcon
end

-- Cleanup function if needed
function UIMinimap:removeCrossPartyIcons()
    for i = 1, #g_partyIcons do
		if g_partyIcons[i] then
			g_partyIcons[i]:destroy()
			g_partyIcons[i] = nil
		end
    end
end


function UIMinimap:setCrossPosition(pos)
  local cross = self.cross
  if not pos then
    return
  end

  if not self.cross then
    cross = g_ui.createWidget('MinimapCross', self)
    cross:setIcon('/images/game/minimap/cross')
    self.cross = cross
  end

  local cameraPos = self:getCameraPosition()
  if cameraPos then
    pos.z = cameraPos.z
  end
  cross.pos = pos
  self:centerInPosition(cross, pos)
end

function UIMinimap:addFlag(pos, icon, description, temporary)
  if not pos or not icon then return end
  local flag = self:getFlag(pos, icon, description)
  if flag or not icon then
    return
  end
  temporary = temporary or false

  flag = g_ui.createWidget('MinimapFlag')
  self:insertChild(1, flag)
  flag.pos = pos
  flag.description = description
  flag.icon = icon
  flag.temporary = temporary
  if type(tonumber(icon)) == 'number' then
    flag:setIcon('/images/game/minimap/flag' .. icon)
  else
    flag:setIcon(resolvepath(icon, 1))
  end
  flag:setTooltip(description)
  flag.onMouseRelease = onFlagMouseRelease
  flag.onDestroy = function() table.removevalue(self.flags, flag) end
  table.insert(self.flags, flag)
  self:centerInPosition(flag, pos)
end

function UIMinimap:addAlternativeWidget(widget, pos, maxZoom)
  widget.pos = pos
  widget.maxZoom = maxZoom or 0
  widget.minZoom = minZoom
  table.insert(self.alternatives, widget)
end

function UIMinimap:internalRegisterAlternative(widget)
  self:centerInPosition(widget, widget.pos)
  self:getLayout():update()
end

function UIMinimap:setAlternativeWidgetsVisible(show)
  local layout = self:getLayout()
  layout:disableUpdates()
  for _,widget in pairs(self.alternatives) do
    if show then
      self:insertChild(1, widget)
      self:centerInPosition(widget, widget.pos)
    else
      self:removeChild(widget)
    end
  end
  layout:enableUpdates()
  layout:update()
end

function UIMinimap:onZoomChange(zoom)
  for _,widget in pairs(self.alternatives) do
    if widget and zoom then
      local minZoom = widget.minZoom or -999
      local maxZoom = widget.maxZoom or 999
      if minZoom <= zoom and maxZoom >= zoom then
        widget:show()
      else
        widget:hide()
      end
    end
  end
end

function UIMinimap:getFlag(pos)
  for _,flag in pairs(self.flags) do
    if flag.pos.x == pos.x and flag.pos.y == pos.y and flag.pos.z == pos.z then
      return flag
    end
  end
  return nil
end

function UIMinimap:removeFlag(pos, icon, description)
  local flag = self:getFlag(pos)
  if flag then
    flag:destroy()
  end
end

function UIMinimap:reset()
  self:setZoom(0)
  if self.cross then
    self:setCameraPosition(self.cross.pos)
  end
end

function UIMinimap:move(x, y)
  local cameraPos = self:getCameraPosition()
  local scale = self:getScale()
  if scale > 1 then scale = 1 end
  local dx = x/scale
  local dy = y/scale
  local pos = {x = cameraPos.x - dx, y = cameraPos.y - dy, z = cameraPos.z}
  self:setCameraPosition(pos)
end

function UIMinimap:onMouseWheel(mousePos, direction)
  local keyboardModifiers = g_keyboard.getModifiers()
  if direction == MouseWheelUp and keyboardModifiers == KeyboardNoModifier then
    self:zoomIn()
  elseif direction == MouseWheelDown and keyboardModifiers == KeyboardNoModifier then
    self:zoomOut()
  elseif direction == MouseWheelDown and keyboardModifiers == KeyboardCtrlModifier then
    self:floorUp(1)
  elseif direction == MouseWheelUp and keyboardModifiers == KeyboardCtrlModifier then
    self:floorDown(1)
  end
end

function UIMinimap:onMousePress(pos, button)
  if not self:isDragging() then
    self.allowNextRelease = true
  end
end

function UIMinimap:onMouseRelease(pos, button)
  if not self.allowNextRelease then return true end
  self.allowNextRelease = false

  local mapPos = self:getTilePosition(pos)
  if not mapPos then return end

  if button == MouseLeftButton then
    local player = g_game.getLocalPlayer()
    if self.autowalk then
      player:autoWalk(mapPos)
    end
    return true
  elseif button == MouseRightButton then
    local menu = g_ui.createWidget('PopupMenu')
    menu:setGameMenu(true)
    menu:addOption(tr('Create mark'), function() self:createFlagWindow(mapPos) end)
    menu:display(pos)
    return true
  end
  return false
end

function UIMinimap:onDragEnter(pos)
  self.dragReference = pos
  self.dragCameraReference = self:getCameraPosition()
  return true
end

function UIMinimap:onDragMove(pos, moved)
  if not self.dragReference or not self.dragCameraReference then
    return false
  end
  local scale = self:getScale()
  local dx = (self.dragReference.x - pos.x)/scale
  local dy = (self.dragReference.y - pos.y)/scale
  local pos = {x = self.dragCameraReference.x + dx, y = self.dragCameraReference.y + dy, z = self.dragCameraReference.z}
  self:setCameraPosition(pos)
  return true
end

function UIMinimap:onDragLeave(widget, pos)
  return true
end

function UIMinimap:onStyleApply(styleName, styleNode)
  for name,value in pairs(styleNode) do
    if name == 'autowalk' then
      self.autowalk = value
    end
  end
end

function UIMinimap:createFlagWindow(pos)
  if self.flagWindow then return end
  if not pos then return end

  self.flagWindow = g_ui.createWidget('MinimapFlagWindow', rootWidget)

  local positionLabel = self.flagWindow:getChildById('position')
  local description = self.flagWindow:getChildById('description')
  local okButton = self.flagWindow:getChildById('okButton')
  local cancelButton = self.flagWindow:getChildById('cancelButton')

  positionLabel:setText(string.format('%i, %i, %i', pos.x, pos.y, pos.z))

  local flagRadioGroup = UIRadioGroup.create()
  for i=0,19 do
    local checkbox = self.flagWindow:getChildById('flag' .. i)
    checkbox.icon = i
    flagRadioGroup:addWidget(checkbox)
  end

  flagRadioGroup:selectWidget(flagRadioGroup:getFirstWidget())

  local successFunc = function()
    self:addFlag(pos, flagRadioGroup:getSelectedWidget().icon, description:getText())
    self:destroyFlagWindow()
  end

  local cancelFunc = function()
    self:destroyFlagWindow()
  end

  okButton.onClick = successFunc
  cancelButton.onClick = cancelFunc

  self.flagWindow.onEnter = successFunc
  self.flagWindow.onEscape = cancelFunc

  self.flagWindow.onDestroy = function() flagRadioGroup:destroy() end
end

function UIMinimap:destroyFlagWindow()
  if self.flagWindow then
    self.flagWindow:destroy()
    self.flagWindow = nil
  end
end

function UIMinimap:clearCrossPartyPosition()
  for v, icon in pairs(partyWidgetIcons) do
    icon:destroy()
    partyWidgetIcons[v] = nil
  end
end
