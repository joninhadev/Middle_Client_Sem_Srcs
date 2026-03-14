CharacterList = {}

-- private variables
local charactersWindow
local loadBox
local characterList
local errorBox
local waitingWindow
local autoReconnectButton
local updateWaitEvent
local resendWaitEvent
local loginEvent
local autoReconnectEvent
local lastLogout = 0
local deleteDialog
local previewCreature
local previewAltar
local previewEffect
local previewEffectEvent
local previewEffectDebounce
local previewCreatureRevealEvent
local eventsContent

EventSchedule = { events = {} }

-- Vocation ID to name mapping
VocationString = {
  [0] = 'Campones',
  [1] = 'Sorcerer',
  [2] = 'Master Sorcerer',
  [3] = 'Archmage',
  [4] = 'Arcane Wizard',
  [40] = 'Secret of Flame',
  [5] = 'Druid',
  [6] = 'Elder Druid',
  [7] = 'Celtic Druid',
  [8] = 'Spirit Healer',
  [41] = 'Forest of Shepherd',
  [9] = 'Archer',
  [10] = 'Royal Archer',
  [11] = 'Medieval Archer',
  [12] = 'Executioner',
  [42] = 'Scout of Watcher',
  [13] = 'Knight',
  [14] = 'Elite Knight',
  [15] = 'Templar Knight',
  [16] = 'Chaos Knight',
  [43] = 'King of Gondor',
  [17] = 'Dwarf',
  [18] = 'Dwarf Blacksmith',
  [19] = 'Dwarf Weaponsmith',
  [20] = 'Dwarf Artisan',
  [44] = 'Warden of the Mountain',
  [21] = 'Orc',
  [22] = 'Orc Warrior',
  [23] = 'Orc Berserker',
  [24] = 'Orc Leader',
  [25] = 'Orc Warlord',
  [26] = 'Orc General',
  [45] = 'Lord of Gundabad',
  [35] = 'Elf',
  [36] = 'Elf Ranger',
  [37] = 'Elf Sentinel',
  [38] = 'High Elf',
  [39] = 'Elven Elite',
  [46] = 'Keeper of Galadhrim'
}
local function tryLogin(charInfo, tries)
  tries = tries or 1

  if tries > 50 then
    return
  end

  if g_game.isOnline() then
    if tries == 1 then
      g_game.safeLogout()
    end
    loginEvent =
      scheduleEvent(
      function()
        tryLogin(charInfo, tries + 1)
      end,
      100
    )
    return
  end

  if charactersWindow then
    CharacterList.hide()
  end
  if EnterGame then
    EnterGame.hide()
  end
  g_game.loginWorld(
    G.account,
    G.password,
    charInfo.worldName,
    charInfo.worldHost,
    charInfo.worldPort,
    charInfo.characterName,
    G.authenticatorToken,
    G.sessionKey
  )

  if EnterGame and EnterGame.showLoadingIndicator then
    EnterGame.showLoadingIndicator(tr('Connecting to game server'), function()
      loadBox = nil
      g_game.cancelLogin()
      CharacterList.show()
    end)
  else
    loadBox = displayCancelBox(tr("Please wait"), tr("Connecting to game server..."))
    connect(
      loadBox,
      {
        onCancel = function()
          loadBox = nil
          g_game.cancelLogin()
          CharacterList.show()
        end
      }
    )
  end

  -- save last used character
  g_settings.set("last-used-character", charInfo.characterName)
  g_settings.set("last-used-world", charInfo.worldName)
end

local function updateWait(timeStart, timeEnd)
  if waitingWindow then
    local time = g_clock.seconds()
    if time <= timeEnd then
      local percent = ((time - timeStart) / (timeEnd - timeStart)) * 100
      local timeStr = string.format("%.0f", timeEnd - time)

      local progressBar = waitingWindow:getChildById("progressBar")
      progressBar:setPercent(percent)

      local label = waitingWindow:getChildById("timeLabel")
      label:setText(tr("Trying to reconnect in %s seconds.", timeStr))

      updateWaitEvent =
        scheduleEvent(
        function()
          updateWait(timeStart, timeEnd)
        end,
        1000 * progressBar:getPercentPixels() / 100 * (timeEnd - timeStart)
      )
      return true
    end
  end

  if updateWaitEvent then
    updateWaitEvent:cancel()
    updateWaitEvent = nil
  end
end

local function resendWait()
  if waitingWindow then
    waitingWindow:destroy()
    waitingWindow = nil

    if updateWaitEvent then
      updateWaitEvent:cancel()
      updateWaitEvent = nil
    end

    if charactersWindow then
      local selected = characterList:getFocusedChild()
      if selected then
        local charInfo = {
          worldHost = selected.worldHost,
          worldPort = selected.worldPort,
          worldName = selected.worldName,
          characterName = selected.characterName
        }
        tryLogin(charInfo)
      end
    end
  end
end

local function onLoginWait(message, time)
  CharacterList.destroyLoadBox()

  waitingWindow = g_ui.displayUI("waitinglist")

  local label = waitingWindow:getChildById("infoLabel")
  label:setText(message)

  updateWaitEvent =
    scheduleEvent(
    function()
      updateWait(g_clock.seconds(), g_clock.seconds() + time)
    end,
    0
  )
  resendWaitEvent = scheduleEvent(resendWait, time * 1000)
end

function onGameLoginError(message)
  CharacterList.destroyLoadBox()
  if EnterGame and EnterGame.showErrorIndicator then
    EnterGame.showErrorIndicator(message, function()
      if CharacterList and CharacterList.showAgain then
        CharacterList.showAgain()
      end
    end)
  else
    errorBox = displayErrorBox(tr("Login Error"), message)
    errorBox.onOk = function()
      errorBox = nil
      if CharacterList and CharacterList.showAgain then
        CharacterList.showAgain()
      end
    end
  end
  scheduleAutoReconnect()
end

function onGameLoginToken(unknown)
  CharacterList.destroyLoadBox()
  -- TODO: make it possible to enter a new token here / prompt token
  errorBox = displayErrorBox(tr("Two-Factor Authentification"), "A new authentification token is required.\nPlease login again.")
  errorBox.onOk = function()
    errorBox = nil
    EnterGame.show()
  end
end

function onGameConnectionError(message, code)
  CharacterList.destroyLoadBox()
  if (not g_game.isOnline() or code ~= 2) and not errorBox then -- code 2 is normal disconnect, end of file
    local text = translateNetworkError(code, g_game.getProtocolGame() and g_game.getProtocolGame():isConnecting(), message)
    if EnterGame and EnterGame.showErrorIndicator then
      EnterGame.showErrorIndicator(text, function()
        errorBox = nil
        if CharacterList and CharacterList.showAgain then
          CharacterList.showAgain()
        end
      end)
    else
      errorBox = displayErrorBox(tr("Connection Error"), text)
      errorBox.onOk = function()
        errorBox = nil
        if CharacterList and CharacterList.showAgain then
          CharacterList.showAgain()
        end
      end
    end
  end
  scheduleAutoReconnect()
end

function onGameUpdateNeeded(signature)
  CharacterList.destroyLoadBox()
  if EnterGame and EnterGame.showErrorIndicator then
    EnterGame.showErrorIndicator(tr("Enter with your account again to update your client."), function()
      if CharacterList and CharacterList.showAgain then
        CharacterList.showAgain()
      end
    end)
  else
    errorBox = displayErrorBox(tr("Update needed"), tr("Enter with your account again to update your client."))
    errorBox.onOk = function()
      errorBox = nil
      if CharacterList and CharacterList.showAgain then
        CharacterList.showAgain()
      end
    end
  end
end

function onGameEnd()
  scheduleAutoReconnect()
  if CharacterList and CharacterList.showAgain then
    CharacterList.showAgain()
  end
end

function onLogout()
  lastLogout = g_clock.millis()
end

function scheduleAutoReconnect()
  if lastLogout + 2000 > g_clock.millis() then
    return
  end
  if autoReconnectEvent then
    removeEvent(autoReconnectEvent)
  end
  autoReconnectEvent = scheduleEvent(executeAutoReconnect, 2500)
end

function executeAutoReconnect()
  if not autoReconnectButton or not autoReconnectButton:isOn() or g_game.isOnline() then
    return
  end
  if errorBox then
    errorBox:destroy()
    errorBox = nil
  end
  if CharacterList and CharacterList.doLogin then
    CharacterList.doLogin()
  end
end

-- public functions
function CharacterList.init()
  if USE_NEW_ENERGAME then
    return
  end
  connect(g_game, {onLoginError = onGameLoginError})
  connect(g_game, {onLoginToken = onGameLoginToken})
  connect(g_game, {onUpdateNeeded = onGameUpdateNeeded})
  connect(g_game, {onConnectionError = onGameConnectionError})
  connect(g_game, {onGameStart = CharacterList.destroyLoadBox})
  connect(g_game, {onLoginWait = onLoginWait})
  connect(g_game, {onGameEnd = onGameEnd})
  connect(g_game, {onLogout = onLogout})

  if G.characters then
    CharacterList.create(G.characters, G.characterAccount)
  end
end

function CharacterList.terminate()
  if USE_NEW_ENERGAME then
    return
  end
  disconnect(g_game, {onLoginError = onGameLoginError})
  disconnect(g_game, {onLoginToken = onGameLoginToken})
  disconnect(g_game, {onUpdateNeeded = onGameUpdateNeeded})
  disconnect(g_game, {onConnectionError = onGameConnectionError})
  disconnect(g_game, {onGameStart = CharacterList.destroyLoadBox})
  disconnect(g_game, {onLoginWait = onLoginWait})
  disconnect(g_game, {onGameEnd = onGameEnd})
  disconnect(g_game, {onLogout = onLogout})

  if charactersWindow then
    characterList = nil
    charactersWindow:destroy()
    charactersWindow = nil
  end

  if loadBox then
    g_game.cancelLogin()
    loadBox:destroy()
    loadBox = nil
  end

  if waitingWindow then
    waitingWindow:destroy()
    waitingWindow = nil
  end

  if updateWaitEvent then
    removeEvent(updateWaitEvent)
    updateWaitEvent = nil
  end

  if resendWaitEvent then
    removeEvent(resendWaitEvent)
    resendWaitEvent = nil
  end

  if loginEvent then
    removeEvent(loginEvent)
    loginEvent = nil
  end

  CharacterList = nil
end

function CharacterList.create(characters, account, otui)
  if not otui then
    otui = "characterlist"
  end
  if charactersWindow then
    charactersWindow:destroy()
  end

  charactersWindow = g_ui.displayUI(otui)
  if not charactersWindow then
    print("ERROR: Failed to load characterlist UI")
    return
  end
  
  if not G.account or G.account:len() == 0 then
    charactersWindow:setText("Cast List")
  end
  
  local charactersListWidget = charactersWindow:recursiveGetChildById("characters")
  if not charactersListWidget then
    print("ERROR: Could not find 'characters' widget in characterlist UI")
    return
  end
  
  characterList = charactersListWidget

  -- setup preview creature, altar, and effect
  previewCreature = charactersWindow:recursiveGetChildById('previewCreature')
  previewAltar = charactersWindow:recursiveGetChildById('previewAltar')
  previewEffect = charactersWindow:recursiveGetChildById('previewEffect')
  eventsContent = charactersWindow:recursiveGetChildById('eventsContent')

  -- characters
  G.characters = characters
  G.characterAccount = account

  characterList:destroyChildren()
  local accountStatusLabel = charactersWindow:recursiveGetChildById("accountStatusLabel")
  local focusLabel
  for i, characterInfo in ipairs(characters) do
    local widget = g_ui.createWidget("CharacterWidget", characterList)

    -- Populate the card labels
    local nameLabel = widget:getChildById('name')
    local levelLabel = widget:getChildById('level')
    local vocationLabel = widget:getChildById('vocation')
    local worldLabel = widget:getChildById('worldName')
    local pvpLabel = widget:getChildById('pvpType')

    if nameLabel then
      if not G.account or G.account:len() == 0 then
        nameLabel:setText(characterInfo.name or '')
      else
        nameLabel:setText(characterInfo.name or '')
      end
    end

    if levelLabel then
      if not G.account or G.account:len() == 0 then
        levelLabel:setText('Spectators ' .. (characterInfo.spectators or '0'))
      else
        levelLabel:setText(tostring(characterInfo.level or ''))
      end
    end

    if vocationLabel then
      local vocText = ''
      if characterInfo.vocation and VocationString and VocationString[characterInfo.vocation] then
        vocText = VocationString[characterInfo.vocation]
      elseif characterInfo.vocation then
        vocText = tostring(characterInfo.vocation)
      end
      vocationLabel:setText(vocText)
    end

    if worldLabel then
      worldLabel:setText(characterInfo.worldName or '')
    end

    if pvpLabel then
      local pvpStr = ''
      if characterInfo.pvpType then
        if characterInfo.pvpType == 0 then pvpStr = 'Open PvP'
        elseif characterInfo.pvpType == 1 then pvpStr = 'Optional PvP'
        elseif characterInfo.pvpType == 2 then pvpStr = 'Hardcore PvP'
        elseif characterInfo.pvpType == 3 then pvpStr = 'Retro Open PvP'
        elseif characterInfo.pvpType == 4 then pvpStr = 'Retro Hardcore PvP'
        end
      end
      pvpLabel:setText(pvpStr)
    end

    -- Store outfit data for preview
    widget.charOutfit = characterInfo.outfit

    -- these are used by login
    widget.characterName = characterInfo.name
    widget.worldName = characterInfo.worldName
    widget.worldHost = characterInfo.worldIp
    widget.worldPort = characterInfo.worldPort

    connect(
      widget,
      {
        onDoubleClick = function()
          CharacterList.doLogin()
          return true
        end
      }
    )

    if i == 1 or (g_settings.get("last-used-character") == widget.characterName and g_settings.get("last-used-world") == widget.worldName) then
      focusLabel = widget
    end
  end

  if focusLabel then
    characterList:focusChild(focusLabel, KeyboardFocusReason)
    addEvent(
      function()
        characterList:ensureChildVisible(focusLabel)
      end
    )
    -- Update preview for initial focus
    updateCharacterPreview(focusLabel)
  end

  characterList.onChildFocusChange = function(self, newFocusChild, oldFocusChild, reason)
    removeEvent(autoReconnectEvent)
    autoReconnectEvent = nil

    -- Update colors for focus highlighting
    if oldFocusChild then
      local nameL = oldFocusChild:getChildById('name')
      local levelL = oldFocusChild:getChildById('level')
      local vocL = oldFocusChild:getChildById('vocation')
      local worldL = oldFocusChild:getChildById('worldName')
      if nameL then nameL:setColor('#b2aca6') end
      if levelL then levelL:setColor('#808080') end
      if vocL then vocL:setColor('#4e4c48') end
      if worldL then worldL:setColor('#b2aca6') end
    end
    if newFocusChild then
      local nameL = newFocusChild:getChildById('name')
      local levelL = newFocusChild:getChildById('level')
      local vocL = newFocusChild:getChildById('vocation')
      local worldL = newFocusChild:getChildById('worldName')
      if nameL then nameL:setColor('#f6ede5') end
      if levelL then levelL:setColor('#d4a828') end
      if vocL then vocL:setColor('#b0a898') end
      if worldL then worldL:setColor('#f6ede5') end
      updateCharacterPreview(newFocusChild)
    end
  end

  -- Garantir que a janela sempre mantenha o foco sobre outras janelas
  -- Mas só quando o jogo não estiver online (quando online, o chat deve ter prioridade)
  if not charactersWindow._focusHandlerSet then
    charactersWindow._refocusing = false
    charactersWindow.onFocusChange = function(self, focused)
      if not focused and self:isVisible() and not self._refocusing and not g_game.isOnline() and not (deleteDialog and deleteDialog:isVisible()) then
        self._refocusing = true
        addEvent(function()
          if self:isVisible() and not self:isFocused() and not g_game.isOnline() and not (deleteDialog and deleteDialog:isVisible()) then
            self:raise()
            self:focus()
          end
          self._refocusing = false
        end)
      end
    end
    charactersWindow._focusHandlerSet = true
  end

  -- account
  CharacterList.updateAccountStatus(account)
  
  if populateEvents then
    populateEvents()
  end
end

function updateCharacterPreview(widget)
  if not previewCreature then return end
  if not widget or not widget.charOutfit then
    previewCreature:setVisible(false)
    if previewAltar then previewAltar:setVisible(false) end
    if previewEffect then previewEffect:setVisible(false) end
    return
  end
  local outfit = widget.charOutfit
  if type(outfit) == 'table' and outfit.type and outfit.type > 0 then
    local cleanOutfit = {
      type = outfit.type,
      head = outfit.head or 0,
      body = outfit.body or 0,
      legs = outfit.legs or 0,
      feet = outfit.feet or 0,
      addons = outfit.addons or 0,
      mount = outfit.mount or 0
    }
    if previewAltar then previewAltar:setVisible(true) end
    -- Hide creature, trigger effect, then reveal
    previewCreature:setVisible(false)
    triggerPreviewEffect(cleanOutfit)
  else
    previewCreature:setVisible(false)
    if previewAltar then previewAltar:setVisible(false) end
    if previewEffect then previewEffect:setVisible(false) end
  end
end

function triggerPreviewEffect(outfit)
  -- Debounce: wait for rapid switching to stop before playing effect
  removeEvent(previewEffectDebounce)
  removeEvent(previewEffectEvent)
  removeEvent(previewCreatureRevealEvent)

  -- If UIEffect is not available, just show the creature directly
  if not previewEffect then
    if previewCreature and outfit then
      previewCreature:setOutfit(outfit)
      previewCreature:setVisible(true)
    end
    return
  end

  -- Hide any in-progress effect immediately
  previewEffect:setVisible(false)
  if previewEffect.setEffect then
    previewEffect:setEffect(nil)
  elseif previewEffect.clearEffect then
    previewEffect:clearEffect()
  end

  -- Delay the effect so rapid key presses don't spam it
  previewEffectDebounce = scheduleEvent(function()
    previewEffectDebounce = nil
    if not previewEffect then return end

    if previewEffect.setEffect then
      local eff = Effect.create()
      eff:setId(244)
      previewEffect:setEffect(eff)
    elseif previewEffect.setEffectId then
      previewEffect:setEffectId(244)
    end
    if previewEffect.setEffectVisible then
      previewEffect:setEffectVisible(true)
    end
    previewEffect:setVisible(true)

    -- Reveal creature after effect has started playing
    previewCreatureRevealEvent = scheduleEvent(function()
      previewCreatureRevealEvent = nil
      if previewCreature and outfit then
        previewCreature:setOutfit(outfit)
        previewCreature:setVisible(true)
      end
    end, 200)

    -- Hide effect after animation completes
    previewEffectEvent = scheduleEvent(function()
      if previewEffect then
        previewEffect:setVisible(false)
        if previewEffect.setEffect then
          previewEffect:setEffect(nil)
        elseif previewEffect.clearEffect then
          previewEffect:clearEffect()
        end
      end
      previewEffectEvent = nil
    end, 800)
  end, 150)
end

function CharacterList.updateAccountStatus(account)
  if not charactersWindow then
    return
  end
  
  local accountStatusLabel = charactersWindow:recursiveGetChildById("accountStatusLabel")
  if not accountStatusLabel then
    return
  end
  
  local status = ""
  if account.status == AccountStatus.Frozen then
    status = tr(" (Frozen)")
  elseif account.status == AccountStatus.Suspended then
    status = tr(" (Suspended)")
  end

  -- Verifica se tem VIP (premium days)
  if account.subStatus == SubscriptionStatus.Free and account.premDays < 1 then
    accountStatusLabel:setText(("%s%s"):format(tr("Free Account"), status))
    local statusIcon = charactersWindow:recursiveGetChildById("accountStatusIcon")
    if statusIcon then statusIcon:setImageSource("/images/game/entergame/nopremium") end
    accountStatusLabel:setColor("#FFFFFF")
  else
    if account.premDays <= 0 or account.premDays == 65535 then
      accountStatusLabel:setText(("%s%s"):format(tr("Free Account"), status))
      local statusIcon = charactersWindow:recursiveGetChildById("accountStatusIcon")
    if statusIcon then statusIcon:setImageSource("/images/game/entergame/nopremium") end
      accountStatusLabel:setColor("#FFFFFF")
    else
      accountStatusLabel:setText(("%s%s"):format(tr("Premium Account (%s) days left", account.premDays), status))
      local statusIcon2 = charactersWindow:recursiveGetChildById("accountStatusIcon")
    if statusIcon2 then statusIcon2:setImageSource("/images/game/entergame/premium") end
      accountStatusLabel:setColor("#00FF00")
    end
  end

  if account.premDays > 0 and account.premDays <= 7 then
    accountStatusLabel:setOn(true)
  else
    accountStatusLabel:setOn(false)
  end
end

function CharacterList.destroy()
  CharacterList.hide(true)

  if charactersWindow then
    characterList = nil
    charactersWindow:destroy()
    charactersWindow = nil
  end
end

function CharacterList.show()
  if loadBox or errorBox then
    return
  end

  -- Se a janela não existe mas há dados em cache, recriá-la
  if not charactersWindow and G.characters and G.characterAccount then
    CharacterList.create(G.characters, G.characterAccount)
  end

  if not charactersWindow then
    return
  end

  -- Esconder a janela de login quando mostrar a lista de personagens
  if EnterGame then
    EnterGame.hide()
  end

  if g_game.isOnline() then
    local btnDel = charactersWindow:recursiveGetChildById('buttonDelete')
    local btnAdd = charactersWindow:recursiveGetChildById('buttonAdd')
    if btnDel then btnDel:hide() end
    if btnAdd then btnAdd:hide() end
  else
    local btnDel = charactersWindow:recursiveGetChildById('buttonDelete')
    local btnAdd = charactersWindow:recursiveGetChildById('buttonAdd')
    if btnDel then btnDel:show() end
    if btnAdd then btnAdd:show() end
  end

  charactersWindow:show()
  charactersWindow:raise()
  charactersWindow:focus()
  
  -- Garantir que o handler de foco esteja configurado
  if not charactersWindow._focusHandlerSet then
    charactersWindow._refocusing = false
    charactersWindow.onFocusChange = function(self, focused)
      -- Se a janela perdeu o foco mas ainda está visível, forçar o foco de volta
      -- Mas só se o jogo não estiver online (quando online, o chat deve ter prioridade)
      if not focused and self:isVisible() and not self._refocusing and not g_game.isOnline() and not (deleteDialog and deleteDialog:isVisible()) then
        self._refocusing = true
        addEvent(function()
          if self:isVisible() and not self:isFocused() and not g_game.isOnline() and not (deleteDialog and deleteDialog:isVisible()) then
            self:raise()
            self:focus()
          end
          self._refocusing = false
        end)
      end
    end
    charactersWindow._focusHandlerSet = true
  end
end

function CharacterList.hide(showLogin)
  removeEvent(autoReconnectEvent)
  autoReconnectEvent = nil

  showLogin = showLogin or false
  if charactersWindow and charactersWindow:isVisible() then
    charactersWindow:hide()
  end

  if showLogin and EnterGame and not g_game.isOnline() then
    EnterGame.show()
  end
end

function CharacterList.showAgain()
  -- Se não há dados em cache ou a janela não existe, não mostrar
  -- O usuário precisará fazer login novamente para obter dados atualizados
  if not G.characters or not G.characterAccount then
    -- Se não há dados, destruir a janela para forçar novo login
    if charactersWindow then
      CharacterList.destroy()
    end
    -- Voltar para a tela de login para obter dados atualizados
    if EnterGame then
      EnterGame.show()
    end
    return
  end
  
  -- Sempre mostrar a lista de personagens ao cancelar o creator (mesmo com lista vazia)
  CharacterList.show()
end

function CharacterList.isVisible()
  if charactersWindow and charactersWindow:isVisible() then
    return true
  end
  return false
end

function CharacterList.doLogin()
  removeEvent(autoReconnectEvent)
  autoReconnectEvent = nil

  if not characterList then
    return
  end

  local selected = characterList:getFocusedChild()
  if selected then
    local charInfo = {
      worldHost = selected.worldHost,
      worldPort = selected.worldPort,
      worldName = selected.worldName,
      characterName = selected.characterName
    }
    if charactersWindow then
      charactersWindow:hide()
    end
    if loginEvent then
      removeEvent(loginEvent)
      loginEvent = nil
    end
    -- Parar a música de login ao clicar no personagem (mesmo que onGameEnd: g_sounds.stopAll())
    if g_sounds and g_sounds.stopAll then
      g_sounds.stopAll()
    end
    if EnterGame and EnterGame.stopStartupMusic then
      EnterGame.stopStartupMusic()
    end
    tryLogin(charInfo)
  else
    displayErrorBox(tr("Error"), tr("You must select a character to login!"))
  end
end

function CharacterList.destroyLoadBox()
  if loadBox then
    loadBox:destroy()
    loadBox = nil
  end
  if EnterGame and EnterGame.hideLoadingIndicator then
    EnterGame.hideLoadingIndicator()
  end
end

function CharacterList.cancelWait()
  if waitingWindow then
    waitingWindow:destroy()
    waitingWindow = nil
  end

  if updateWaitEvent then
    removeEvent(updateWaitEvent)
    updateWaitEvent = nil
  end

  if resendWaitEvent then
    removeEvent(resendWaitEvent)
    resendWaitEvent = nil
  end

  CharacterList.destroyLoadBox()
  CharacterList.showAgain()
end

function CharacterList.PreCreate()
  if not G.account or not G.password or G.account:len() == 0 or G.password:len() == 0 then
    return
  end
  CharacterList.hide(false)
  CharacterCreator.init()
end

function CharacterList.showDeleteDialog()
  if not G.account or not G.password or G.account:len() == 0 or G.password:len() == 0 then
    return
  end
  if not deleteDialog then
    deleteDialog = g_ui.displayUI("delete_dialog")
    if addWindowToFocusList then
      addWindowToFocusList(deleteDialog)
    end
    deleteDialog.onDestroy = function(self)
      if removeWindowFromFocusList then
        removeWindowFromFocusList(self)
      end
    end
  end
  local selected = characterList:getFocusedChild()
  if selected then
    local desc = deleteDialog:getChildById("desc")
    desc:setText(selected.characterName)
    deleteDialog:show()
    deleteDialog:raise()
    deleteDialog:focus()
  end
end

local function onCharacterCreated(protocol, characters, account)
  CharacterList.hideDeleteDialog()
  CharacterList.create(characters, account)
  CharacterList.show()
end

function CharacterList.confirmDelete()
  if not G.account or not G.password or G.account:len() == 0 or G.password:len() == 0 then
    return
  end
  local selected = characterList:getFocusedChild()
  if selected then
    if selected.characterName == deleteDialog:getChildById("confirm"):getText() then
      protocolCreator = ProtocolCreator.create()
      protocolCreator.onCreatorError = function(protocol, message)
        errorBox = displayErrorBox(tr("Creator Error"), message)
        errorBox.onOk = function()
          errorBox = nil
        end
      end
      protocolCreator.onCharacterDeleted = function(protocol, success)
        if success then
          CharacterList.hideDeleteDialog()
          -- Remove o personagem da lista atual sem desconectar
          local selected = characterList:getFocusedChild()
          if selected then
            selected:destroy()
            -- Se não há mais personagens, volta para o login
            if not characterList:hasChildren() then
              CharacterList.destroy()
              EnterGame.show()
            end
          end
        end
      end

      local name = selected.characterName
      protocolCreator:deleteCharacter(G.host, G.account, G.password, name)
    end
  end
end

function CharacterList.hideDeleteDialog()
  if deleteDialog then
    if removeWindowFromFocusList then
      removeWindowFromFocusList(deleteDialog)
    end
    deleteDialog:destroy()
    deleteDialog = nil
  end
end

-- ===== EVENTS SCHEDULE SYSTEM =====
local function convertStringToTime(date_string)
  if not date_string then return os.time() end
  local year, month, day, hour, min, sec = date_string:match("(%d+)-(%d+)-(%d+) (%d+):(%d+):(%d+)")
  if not year then return os.time() end
  local timestamp = os.time({
    year = tonumber(year),
    month = tonumber(month),
    day = tonumber(day),
    hour = tonumber(hour),
    min = tonumber(min),
    sec = tonumber(sec)
  })
  return timestamp
end

function getEventByDay(time)
  local activesEvents = {}
  local activeTooltip = ''
  if not time then
    return activesEvents, activeTooltip
  end

  if not EventSchedule.events or table.empty(EventSchedule.events) then
    return {}, ""
  end

  local day = os.date("*t", time).day
  local weekday = os.date("*t", time).wday - 1
  for _, event in ipairs(EventSchedule.events) do
    if event.startdate and event.enddate then
      local startdate = convertStringToTime(event.startdate.date)
      local enddate = convertStringToTime(event.enddate.date)
      local canrun = time >= startdate and time <= enddate
      if event.recurring then
        local startDay = os.date("*t", startdate).day
        if #event.recurringweekdays > 0 then
          canrun = canrun and table.find(event.recurringweekdays, weekday) ~= nil
        elseif #event.recurringmonthdays > 0 then
          canrun = canrun and table.find(event.recurringmonthdays, day) ~= nil
        else
          canrun = canrun and day == startDay
        end
      end
      if canrun then
        local dayStart = os.date("*t", time)
        local evStart = os.date("*t", startdate)
        local evEnd = os.date("*t", enddate)
        local isStartDay = (dayStart.year == evStart.year and dayStart.yday == evStart.yday)
        local isEndDay = (dayStart.year == evEnd.year and dayStart.yday == evEnd.yday)

        local entry = {
          name = event.name,
          colorlight = event.colorlight or '#ffffff',
          colordark = event.colordark or '#cccccc',
          description = event.description or '',
          isStartDay = isStartDay,
          isEndDay = isEndDay,
        }
        table.insert(activesEvents, entry)

        if activeTooltip ~= '' then
          activeTooltip = activeTooltip .. '\n\n'
        end
        local marker = ''
        if isStartDay or isEndDay then marker = '*' end
        activeTooltip = activeTooltip .. marker .. event.name .. ":\n" .. string.todivide(event.description, 10)
      end
    end
  end

  return activesEvents, activeTooltip
end

function populateEvents()
  if not eventsContent then return end
  eventsContent:destroyChildren()

  local events = EventSchedule and EventSchedule.events
  if not events or table.empty(events) then
    local placeholder = g_ui.createWidget('Label', eventsContent)
    placeholder:setText(tr('No events'))
    placeholder:setFont('verdana-11px-antialised')
    placeholder:setColor('#909090')
    placeholder:setTextAlign(AlignLeft)
    placeholder:setTextAutoResize(true)
    placeholder:setMarginLeft(10)
    placeholder:setMarginTop(6)
    return
  end

  local time = os.time()
  local activeEvents = getEventByDay(time)

  local seenUpcoming = {}
  local upcomingEvents = {}
  for i = 1, 7 do
    local futureTime = time + (i * 24 * 60 * 60)
    local futureEvts = getEventByDay(futureTime)
    for _, ev in ipairs(futureEvts) do
      if not seenUpcoming[ev.name] then
        local isActive = false
        for _, a in ipairs(activeEvents) do
          if a.name == ev.name then isActive = true break end
        end
        if not isActive then
          seenUpcoming[ev.name] = true
          table.insert(upcomingEvents, ev)
        end
      end
    end
  end

  if #activeEvents == 0 and #upcomingEvents == 0 then
    local placeholder = g_ui.createWidget('Label', eventsContent)
    placeholder:setText(tr('No active events'))
    placeholder:setFont('verdana-11px-antialised')
    placeholder:setColor('#909090')
    placeholder:setTextAlign(AlignLeft)
    placeholder:setTextAutoResize(true)
    placeholder:setMarginLeft(10)
    placeholder:setMarginTop(6)
    return
  end

  if #activeEvents > 0 then
    local header = g_ui.createWidget('Label', eventsContent)
    header:setText(tr('Active Events'))
    header:setFont('verdana-11px-antialised')
    header:setColor('#d4a828')
    header:setTextAutoResize(true)
    header:setTextAlign(AlignLeft)
    header:setMarginLeft(8)
    header:setMarginTop(6)

    for _, ev in ipairs(activeEvents) do
      local row = g_ui.createWidget('EventHoverLabel', eventsContent)
      row:setText('  ' .. ev.name)
      local dot = row:getChildById('dot')
      if dot then dot:setBackgroundColor(ev.colorlight) end
    end
  end

  if #upcomingEvents > 0 then
    local header = g_ui.createWidget('Label', eventsContent)
    header:setText(tr('Upcoming Events'))
    header:setFont('verdana-11px-antialised')
    header:setColor('#909090')
    header:setTextAutoResize(true)
    header:setTextAlign(AlignLeft)
    header:setMarginLeft(8)
    header:setMarginTop(#activeEvents > 0 and 6 or 6)

    for _, ev in ipairs(upcomingEvents) do
      local row = g_ui.createWidget('EventHoverLabel', eventsContent)
      row:setText('  ' .. ev.name)
      local dot = row:getChildById('dot')
      if dot then dot:setBackgroundColor(ev.colordark) end
    end
  end
end
