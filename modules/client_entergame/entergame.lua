EnterGame = { }

-- private variables
local loadBox
local enterGameClip
local enterGame
local enterGameButton
local logpass
local clientBox
local protocolLogin
local server = nil
local versionsFound = false

local customServerSelectorPanel
local serverSelectorPanel
local serverSelector
local clientVersionSelector
local serverHostTextEdit
local rememberPasswordBox
local savedAccountsDropdown
local savedAccountsVisible = false
local emailVisible = true
local passwordVisible = false
local realEmailText = ''
local realPasswordText = ''
local updatingPasswordField = false
local protos = {"740", "760", "772", "792", "800", "810", "854", "860", "870", "910", "961", "1000", "1077", "1090", "1096", "1098", "1099", "1100", "1200", "1220"}

local checkedByUpdater = {}
local waitingForHttpResults = 0

-- Saved accounts helper functions
function getSavedAccounts()
  local raw = g_settings.get('savedAccounts')
  if raw and raw ~= '' then
    local ok, accounts = pcall(function() return json.decode(raw) end)
    if ok and type(accounts) == 'table' then return accounts end
  end
  return {}
end

function setSavedAccounts(accounts)
  local ok, encoded = pcall(function() return json.encode(accounts) end)
  if ok then g_settings.set('savedAccounts', encoded) end
end

function saveCurrentAccount()
  if not enterGame then return end
  local accField = enterGame:getChildById('accountNameTextEdit')
  if not accField then return end
  local email = accField:getText()
  if email == '' then return end
  local accounts = getSavedAccounts()
  for i, acc in ipairs(accounts) do
    if acc.email == email then
      if rememberPasswordBox and rememberPasswordBox:isChecked() then
        local pwField = enterGame:getChildById('accountPasswordTextEdit')
        if pwField then
          acc.password = g_crypt.encrypt(pwField:getText())
        end
      end
      setSavedAccounts(accounts)
      return
    end
  end
  local entry = { email = email }
  if rememberPasswordBox and rememberPasswordBox:isChecked() then
    local pwField = enterGame:getChildById('accountPasswordTextEdit')
    if pwField then
      entry.password = g_crypt.encrypt(pwField:getText())
    end
  end
  table.insert(accounts, entry)
  setSavedAccounts(accounts)
end

function removeSavedAccount(email)
  local accounts = getSavedAccounts()
  for i, acc in ipairs(accounts) do
    if acc.email == email then
      table.remove(accounts, i)
      setSavedAccounts(accounts)
      return
    end
  end
end

function maskEmail(email)
  local at = email:find('@')
  if not at or at <= 2 then return email end
  local name = email:sub(1, at - 1)
  local domain = email:sub(at)
  if #name <= 3 then
    return name:sub(1, 1) .. string.rep('*', #name - 1) .. domain
  end
  return name:sub(1, 2) .. string.rep('*', #name - 2) .. domain
end

function populateSavedAccountsDropdown()
  if not savedAccountsDropdown then return end
  local children = savedAccountsDropdown:getChildren()
  for _, child in ipairs(children) do
    child:destroy()
  end

  local accounts = getSavedAccounts()
  if #accounts == 0 then
    savedAccountsDropdown:setHeight(0)
    return
  end

  local rowHeight = 36
  local maxVisible = 4
  local dropdownPadding = 12
  local visibleCount = math.min(#accounts, maxVisible)
  local totalHeight = visibleCount * rowHeight + dropdownPadding

  for i, acc in ipairs(accounts) do
    local row = g_ui.createWidget('UIWidget', savedAccountsDropdown)
    row:setHeight(rowHeight)
    row:setPhantom(false)
    row:setFocusable(false)
    row:setBackgroundColor('#00000000')

    local displayEmail = maskEmail(acc.email)
    local label = g_ui.createWidget('Label', row)
    label:setId('emailLabel')
    label:setText(displayEmail)
    label:setFont('verdana-11px-antialised')
    label:setColor('#b0b0b0')
    label:addAnchor(AnchorTop, 'parent', AnchorTop)
    label:addAnchor(AnchorLeft, 'parent', AnchorLeft)
    label:addAnchor(AnchorRight, 'parent', AnchorRight)
    label:setMarginTop(8)
    label:setMarginLeft(10)
    label:setMarginRight(30)
    label:setPhantom(true)
    label:setTextAlign(AlignLeft)
    label:setTextAutoResize(true)

    local deleteBtn = g_ui.createWidget('UIButton', row)
    deleteBtn:setId('deleteBtn')
    deleteBtn:setSize({width = 12, height = 12})
    deleteBtn:addAnchor(AnchorRight, 'parent', AnchorRight)
    deleteBtn:addAnchor(AnchorVerticalCenter, 'parent', AnchorVerticalCenter)
    deleteBtn:setMarginRight(8)
    deleteBtn:setText('X')
    deleteBtn:setFont('verdana-11px-antialised')
    deleteBtn:setColor('#ff5555')
    deleteBtn:setOpacity(0.4)
    deleteBtn:setCursor('pointer')

    local emailToDelete = acc.email
    deleteBtn.onClick = function()
      removeSavedAccount(emailToDelete)
      populateSavedAccountsDropdown()
      if #getSavedAccounts() == 0 then
        hideSavedAccountsDropdown()
      end
    end

    row.onHoverChange = function(widget, hovered)
      if hovered then
        widget:setBackgroundColor('#ffffff11')
        widget:getChildById('emailLabel'):setColor('#f6ede5')
      else
        widget:setBackgroundColor('#00000000')
        widget:getChildById('emailLabel'):setColor('#b0b0b0')
      end
    end

    local emailToSelect = acc.email
    local passwordToSelect = acc.password
    row.onClick = function()
      selectSavedAccount(emailToSelect, passwordToSelect)
    end
  end

  savedAccountsDropdown:setHeight(totalHeight)
end

function selectSavedAccount(email, encryptedPassword)
  if not enterGame then return end
  local accountWidget = enterGame:getChildById('accountNameTextEdit')
  local passwordWidget = enterGame:getChildById('accountPasswordTextEdit')

  if accountWidget then
    accountWidget:setText(email)
    accountWidget:setCursorPos(#email)
  end

  if passwordWidget then
    if encryptedPassword and encryptedPassword ~= '' then
      passwordWidget:setText(g_crypt.decrypt(encryptedPassword))
    else
      passwordWidget:clearText()
    end
  end

  if rememberPasswordBox then rememberPasswordBox:setChecked(true) end
  hideSavedAccountsDropdown()
  if accountWidget then accountWidget:focus() end
end

function toggleSavedAccountsDropdown()
  if savedAccountsVisible then
    hideSavedAccountsDropdown()
  else
    showSavedAccountsDropdown()
  end
end

function showSavedAccountsDropdown()
  if not savedAccountsDropdown then return end
  local accounts = getSavedAccounts()
  if #accounts == 0 then return end

  populateSavedAccountsDropdown()

  savedAccountsDropdown:setVisible(true)
  savedAccountsDropdown:raise()
  savedAccountsVisible = true
end

function hideSavedAccountsDropdown()
  if not savedAccountsDropdown then return end
  savedAccountsDropdown:setVisible(false)
  savedAccountsVisible = false
end

function toggleEmailVisibility()
  if not enterGame then return end
  local emailWidget = enterGame:getChildById('accountNameTextEdit')
  if not emailWidget then return end

  if emailVisible then
    realEmailText = emailWidget:getText()
    emailVisible = false
    emailWidget:setText(string.rep('*', #realEmailText))
  else
    emailVisible = true
    emailWidget:setText(realEmailText)
    emailWidget:setCursorPos(#realEmailText)
  end
  g_settings.set('emailHidden', not emailVisible)

  local eyeBtn = enterGame:getChildById('toggleEmailVisibility')
  if eyeBtn then
    eyeBtn:setOn(emailVisible)
  end
end

function togglePasswordVisibility()
  if not enterGame then return end
  local pwField = enterGame:getChildById('accountPasswordTextEdit')
  if not pwField then return end

  if not passwordVisible then
    passwordVisible = true
    pwField:setText(realPasswordText)
    pwField:setCursorPos(#realPasswordText)
  else
    realPasswordText = pwField:getText()
    passwordVisible = false
    pwField:setText(string.rep('*', #realPasswordText))
  end

  local eyeBtn = enterGame:getChildById('togglePasswordVisibility')
  if eyeBtn then
    eyeBtn:setOn(passwordVisible)
  end
end

function onTextChange()
  if not enterGame then return end
  if savedAccountsVisible then hideSavedAccountsDropdown() end
end

function onPasswordTextChange(widget)
  if updatingPasswordField then return end
  if passwordVisible then
    realPasswordText = widget:getText()
    return
  end
  local displayed = widget:getText()
  local realLen = #realPasswordText
  local dispLen = #displayed
  if dispLen > realLen then
    local newChars = displayed:sub(realLen + 1)
    realPasswordText = realPasswordText .. newChars
  elseif dispLen < realLen then
    realPasswordText = realPasswordText:sub(1, dispLen)
  end
  updatingPasswordField = true
  local cursorPos = widget:getCursorPos()
  widget:setText(string.rep('*', #realPasswordText))
  widget:setCursorPos(cursorPos)
  updatingPasswordField = false
end

-- private functions
local function onProtocolError(protocol, message, errorCode)
  if errorCode then
    return EnterGame.onError(message)
  end
  return EnterGame.onLoginError(message)
end

local function onSessionKey(protocol, sessionKey)
  G.sessionKey = sessionKey
end

local function onCharacterList(protocol, characters, account, otui)
  if rememberPasswordBox:isChecked() then
    local account = g_crypt.encrypt(G.account)
    local password = g_crypt.encrypt(G.password)

    g_settings.set('account', account)
    g_settings.set('password', password)
    saveCurrentAccount()
  else
    EnterGame.clearAccountFields()
  end

  for _, characterInfo in pairs(characters) do
    if characterInfo.previewState and characterInfo.previewState ~= PreviewState.Default then
      characterInfo.worldName = characterInfo.worldName .. ', Preview'
    end
  end

  if loadBox then
    loadBox:destroy()
    loadBox = nil
  end
    
  CharacterList.create(characters, account, otui)
  CharacterList.show()

  g_settings.save()
end

local function onUpdateNeeded(protocol, signature)
  return EnterGame.onError(tr('Your client needs updating, try redownloading it.'))
end

local function onProxyList(protocol, proxies)
  for _, proxy in ipairs(proxies) do
    g_proxy.addProxy(proxy["host"], proxy["port"], proxy["priority"])
  end
end

local function parseFeatures(features)
  for feature_id, value in pairs(features) do
      if value == "1" or value == "true" or value == true then
        g_game.enableFeature(feature_id)
      else
        g_game.disableFeature(feature_id)
      end
  end  
end

local function validateThings(things)
  local incorrectThings = ""
  local missingFiles = false
  local versionForMissingFiles = 0
  if things ~= nil then
    local thingsNode = {}
    for thingtype, thingdata in pairs(things) do
      thingsNode[thingtype] = thingdata[1]
      if not g_resources.fileExists("/things/" .. thingdata[1]) then
        incorrectThings = incorrectThings .. "Missing file: " .. thingdata[1] .. "\n"
        missingFiles = true
        versionForMissingFiles = thingdata[1]:split("/")[1]
      else
        local localChecksum = g_resources.fileChecksum("/things/" .. thingdata[1]):lower()
        if localChecksum ~= thingdata[2]:lower() and #thingdata[2] > 1 then
          if g_resources.isLoadedFromArchive() then -- ignore checksum if it's test/debug version
            incorrectThings = incorrectThings .. "Invalid checksum of file: " .. thingdata[1] .. " (is " .. localChecksum .. ", should be " .. thingdata[2]:lower() .. ")\n"
          end
        end
      end
    end
    g_settings.setNode("things", thingsNode)
  else
    g_settings.setNode("things", {})
  end
  if missingFiles then
    incorrectThings = incorrectThings .. "\nYou should open data/things and create directory " .. versionForMissingFiles .. 
    ".\nIn this directory (data/things/" .. versionForMissingFiles .. ") you should put missing\nfiles (Tibia.dat and Tibia.spr/Tibia.cwm) " ..
    "from correct Tibia version."
  end
  return incorrectThings
end

local function onTibia12HTTPResult(session, playdata)
  local characters = {}
  local worlds = {}
  local account = {
    status = 0,
    subStatus = 0,
    premDays = 0
  }
  if session["status"] ~= "active" then
    account.status = 1
  end
  if session["ispremium"] then
    account.subStatus = 1 -- premium
  end
  if session["premiumuntil"] > g_clock.seconds() then
    account.subStatus = math.floor((session["premiumuntil"] - g_clock.seconds()) / 86400)
  end
    
  local things = {
    data = {G.clientVersion .. "/Tibia.dat", ""},
    sprites = {G.clientVersion .. "/Tibia.cwm", ""},
  }

  local incorrectThings = validateThings(things)
  if #incorrectThings > 0 then
    things = {
      data = {G.clientVersion .. "/Tibia.dat", ""},
      sprites = {G.clientVersion .. "/Tibia.spr", ""},
    }  
    incorrectThings = validateThings(things)
  end
  
  if #incorrectThings > 0 then
    g_logger.error(incorrectThings)
    if Updater and not checkedByUpdater[G.clientVersion] then
      checkedByUpdater[G.clientVersion] = true
      return Updater.check({
        version = G.clientVersion,
        host = G.host
      })
    else
      return EnterGame.onError(incorrectThings)
    end
  end
  
  onSessionKey(nil, session["sessionkey"])
  
  for _, world in pairs(playdata["worlds"]) do
    worlds[world.id] = {
      name = world.name,
      port = world.externalportunprotected or world.externalportprotected or world.externaladdress,
      address = world.externaladdressunprotected or world.externaladdressprotected or world.externalport
    }
  end
  
  for _, character in pairs(playdata["characters"]) do
    local world = worlds[character.worldid]
    if world then
      table.insert(characters, {
        name = character.name,
        worldName = world.name,
        worldIp = world.address,
        worldPort = world.port
      })
    end
  end
  
  -- proxies
  if g_proxy then
    g_proxy.clear()
    if playdata["proxies"] then
      for i, proxy in ipairs(playdata["proxies"]) do
        g_proxy.addProxy(proxy["host"], tonumber(proxy["port"]), tonumber(proxy["priority"]))
      end
    end
  end
  
  g_game.setCustomProtocolVersion(0)
  g_game.chooseRsa(G.host)
  g_game.setClientVersion(G.clientVersion)
  g_game.setProtocolVersion(g_game.getClientProtocolVersion(G.clientVersion))
  g_game.setCustomOs(-1) -- disable
  if not g_game.getFeature(GameExtendedOpcode) then
    g_game.setCustomOs(5) -- set os to windows if opcodes are disabled
  end
  
  onCharacterList(nil, characters, account, nil)  
end

local function onHTTPResult(data, err)
  if waitingForHttpResults == 0 then
    return
  end
  
  waitingForHttpResults = waitingForHttpResults - 1
  if err and waitingForHttpResults > 0 then
    return -- ignore, wait for other requests
  end

  if err then
    return EnterGame.onError(err)
  end
  waitingForHttpResults = 0 
  if data['error'] and data['error']:len() > 0 then
    return EnterGame.onLoginError(data['error'])
  elseif data['errorMessage'] and data['errorMessage']:len() > 0 then
    return EnterGame.onLoginError(data['errorMessage'])
  end
  
  if type(data["session"]) == "table" and type(data["playdata"]) == "table" then
    return onTibia12HTTPResult(data["session"], data["playdata"])
  end  
  
  local characters = data["characters"]
  local account = data["account"]
  local session = data["session"]
 
  local version = data["version"]
  local things = data["things"]
  local customProtocol = data["customProtocol"]

  local features = data["features"]
  local settings = data["settings"]
  local rsa = data["rsa"]
  local proxies = data["proxies"]

  local incorrectThings = validateThings(things)
  if #incorrectThings > 0 then
    g_logger.info(incorrectThings)
    return EnterGame.onError(incorrectThings)
  end
  
  -- custom protocol
  g_game.setCustomProtocolVersion(0)
  if customProtocol ~= nil then
    customProtocol = tonumber(customProtocol)
    if customProtocol ~= nil and customProtocol > 0 then
      g_game.setCustomProtocolVersion(customProtocol)
    end
  end
  
  -- force player settings
  if settings ~= nil then
    for option, value in pairs(settings) do
      modules.client_options.setOption(option, value, true)
    end
  end
    
  -- version
  G.clientVersion = version
  g_game.setClientVersion(version)
  g_game.setProtocolVersion(g_game.getClientProtocolVersion(version))  
  g_game.setCustomOs(-1) -- disable
  
  if rsa ~= nil then
    g_game.setRsa(rsa)
  end

  if features ~= nil then
    parseFeatures(features)
  end

  if session ~= nil and session:len() > 0 then
    onSessionKey(nil, session)
  end
  
  -- proxies
  if g_proxy then
    g_proxy.clear()
    if proxies then
      for i, proxy in ipairs(proxies) do
        g_proxy.addProxy(proxy["host"], tonumber(proxy["port"]), tonumber(proxy["priority"]))
      end
    end
  end
  
  onCharacterList(nil, characters, account, nil)  
end


-- public functions
function EnterGame.init()
  if USE_NEW_ENERGAME then return end
  enterGameClip = g_ui.displayUI('entergame')
  enterGame = enterGameClip:getChildById('enterGame')
  if not enterGame then
    enterGame = enterGameClip -- fallback if no nested enterGame
  end
  if LOGPASS ~= nil then
    logpass = g_ui.loadUI('logpass', enterGameClip:getParent())
  end
  
  savedAccountsDropdown = enterGame:getChildById('savedAccountsDropdown')
  serverSelectorPanel = enterGame:recursiveGetChildById('serverSelectorPanel')
  customServerSelectorPanel = enterGame:recursiveGetChildById('customServerSelectorPanel')
  
  serverSelector = serverSelectorPanel and serverSelectorPanel:getChildById('serverSelector')
  rememberPasswordBox = enterGame:recursiveGetChildById('rememberPasswordBox') or enterGame:recursiveGetChildById('rememberMeBox')
  serverHostTextEdit = customServerSelectorPanel and customServerSelectorPanel:getChildById('serverHostTextEdit')
  clientVersionSelector = customServerSelectorPanel and customServerSelectorPanel:getChildById('clientVersionSelector')
  
  if Servers ~= nil and serverSelector then 
    for name,server in pairs(Servers) do
      serverSelector:addOption(name)
    end
  end
  if serverSelector and (serverSelector:getOptionsCount() == 0 or ALLOW_CUSTOM_SERVERS) then
    serverSelector:addOption(tr("Another"))    
  end  
  if clientVersionSelector then
    for i,proto in pairs(protos) do
      clientVersionSelector:addOption(proto)
    end
  end

  if serverSelector and serverSelector:getOptionsCount() == 1 and serverSelectorPanel then
    enterGame:setHeight(enterGame:getHeight() - serverSelectorPanel:getHeight())
    serverSelectorPanel:setOn(false)
  end
  
  local account = g_crypt.decrypt(g_settings.get('account'))
  local password = g_crypt.decrypt(g_settings.get('password'))
  local server = g_settings.get('server')
  local host = g_settings.get('host')
  local clientVersion = g_settings.get('client-version')

  if serverSelector and serverSelector:isOption(server) then
    serverSelector:setCurrentOption(server, false)
    if (Servers == nil or Servers[server] == nil) and serverHostTextEdit then
      serverHostTextEdit:setText(host)
    end
    if clientVersionSelector then clientVersionSelector:setOption(clientVersion) end
  else
    server = ""
    host = ""
  end
  
  local pwField = enterGame:recursiveGetChildById('accountPasswordTextEdit')
  local accField = enterGame:recursiveGetChildById('accountNameTextEdit')
  if pwField then
    pwField:setText(string.rep('*', #password))
  end
  if accField then
    accField:setText(account)
    accField:setCursorPos(#account)
  end
  if rememberPasswordBox then rememberPasswordBox:setChecked(#account > 0) end

  -- Initialize email visibility from saved setting
  emailVisible = not g_settings.getBoolean('emailHidden', false)
  if accField and not emailVisible then
    realEmailText = accField:getText()
    accField:setText(string.rep('*', #realEmailText))
  end
  local emailEyeBtn = enterGame:getChildById('toggleEmailVisibility')
  if emailEyeBtn then emailEyeBtn:setOn(emailVisible) end

  -- Password always starts hidden
  passwordVisible = false
  realPasswordText = password or ''
  local pwEyeBtn = enterGame:getChildById('togglePasswordVisibility')
  if pwEyeBtn then pwEyeBtn:setOn(false) end

  Keybind.new("Misc.", "Change Character", "Ctrl+G", "")
  Keybind.bind("Misc.", "Change Character", {
    {
      type = KEY_DOWN,
      callback = EnterGame.openWindow,
    }
  })

  if g_game.isOnline() then
    return EnterGame.hide()
  end

  scheduleEvent(function()
    EnterGame.show()
  end, 100)
end

function EnterGame.terminate()
  if not enterGameClip and not enterGame then return end

  Keybind.delete("Misc.", "Change Character")

  if logpass then
    logpass:destroy()
    logpass = nil
  end
  
  if enterGameClip then
    enterGameClip:destroy()
    enterGameClip = nil
    enterGame = nil
  elseif enterGame then
    enterGame:destroy()
    enterGame = nil
  end
  if loadBox then
    loadBox:destroy()
    loadBox = nil
  end
  if protocolLogin then
    protocolLogin:cancelLogin()
    protocolLogin = nil
  end
  EnterGame = nil
end

function EnterGame.show()
  if not enterGame then return end
  if enterGameClip then
    enterGameClip:show()
    enterGameClip:raise()
  end
  enterGame:show()
  enterGame:raise()
  enterGame:focus()
  local accField = enterGame:getChildById('accountNameTextEdit')
  if accField then accField:focus() end
  if logpass then
    logpass:show()
    logpass:raise()
    logpass:focus()
  end
end

function EnterGame.hide()
  if not enterGame then return end
  if enterGameClip then
    enterGameClip:hide()
  end
  enterGame:hide()
  if logpass then
    logpass:hide()
    if modules.logpass then
      modules.logpass:hide()
    end
  end
end

function EnterGame.openWindow()
  if g_game.isOnline() then
    CharacterList.show()
  elseif not g_game.isLogging() and not CharacterList.isVisible() then
    EnterGame.show()
  end
end

function EnterGame.clearAccountFields()
  local accField = enterGame:getChildById('accountNameTextEdit')
  local pwField = enterGame:getChildById('accountPasswordTextEdit')
  if accField then accField:clearText() end
  if pwField then pwField:clearText() end
  if accField then accField:focus() end
  g_settings.remove('account')
  g_settings.remove('password')
end

function EnterGame.onServerChange()
  server = serverSelector:getText()
  if server == tr("Another") then
    if not customServerSelectorPanel:isOn() then
      serverHostTextEdit:setText("")
      customServerSelectorPanel:setOn(true)  
      enterGame:setHeight(enterGame:getHeight() + customServerSelectorPanel:getHeight())
    end
  elseif customServerSelectorPanel:isOn() then
    enterGame:setHeight(enterGame:getHeight() - customServerSelectorPanel:getHeight())
    customServerSelectorPanel:setOn(false)
  end
  if Servers and Servers[server] ~= nil then
    if type(Servers[server]) == "table" then
      serverHostTextEdit:setText(Servers[server][1])
    else
      serverHostTextEdit:setText(Servers[server])
    end
  end
end

function EnterGame.doLogin(account, password, host)
  if g_game.isOnline() then
    local errorBox = displayErrorBox(tr('Login Error'), tr('Cannot login while already in game.'))
    connect(errorBox, { onOk = EnterGame.show })
    return
  end
  
  local accField = enterGame:getChildById('accountNameTextEdit')
  local pwField = enterGame:getChildById('accountPasswordTextEdit')
  -- Use real text if fields are masked with asterisks
  local accText = accField and accField:getText() or ''
  local pwText = pwField and pwField:getText() or ''
  if not emailVisible and realEmailText ~= '' then accText = realEmailText end
  if not passwordVisible and realPasswordText ~= '' then pwText = realPasswordText end
  G.account = account or accText
  G.password = password or pwText
--  G.authenticatorToken = token or enterGame:getChildById('accountTokenTextEdit'):getText()
  G.stayLogged = true
  G.server = serverSelector and serverSelector:getText():trim() or ''
  G.host = host or (serverHostTextEdit and serverHostTextEdit:getText() or '')
  G.clientVersion = clientVersionSelector and tonumber(clientVersionSelector:getText()) or 0  
 
  if not rememberPasswordBox:isChecked() then
    g_settings.set('account', G.account)
    g_settings.set('password', G.password)  
  end
  g_settings.set('host', G.host)
  g_settings.set('server', G.server)
  g_settings.set('client-version', G.clientVersion)
  g_settings.save()

  local server_params = G.host:split(":")
  if G.host:lower():find("http") ~= nil then
    if #server_params >= 4 then
      G.host = server_params[1] .. ":" .. server_params[2] .. ":" .. server_params[3] 
      G.clientVersion = tonumber(server_params[4])
    elseif #server_params >= 3 then
      if tostring(tonumber(server_params[3])) == server_params[3] then
        G.host = server_params[1] .. ":" .. server_params[2] 
        G.clientVersion = tonumber(server_params[3])
      end
    end
    return EnterGame.doLoginHttp()      
  end
  
  local server_ip = server_params[1]
  local server_port = 7171
  if #server_params >= 2 then
    server_port = tonumber(server_params[2])
  end
  if #server_params >= 3 then
    G.clientVersion = tonumber(server_params[3])
  end
  if type(server_ip) ~= 'string' or server_ip:len() <= 3 or not server_port or not G.clientVersion then
    return EnterGame.onError("Invalid server, it should be in format IP:PORT or it should be http url to login script")  
  end
  
  local things = {
    data = {G.clientVersion .. "/Tibia.dat", ""},
    sprites = {G.clientVersion .. "/Tibia.cwm", ""},
  }
  
  local incorrectThings = validateThings(things)
  if #incorrectThings > 0 then
    things = {
      data = {G.clientVersion .. "/Tibia.dat", ""},
      sprites = {G.clientVersion .. "/Tibia.spr", ""},
    }  
    incorrectThings = validateThings(things)
  end
  if #incorrectThings > 0 then
    g_logger.error(incorrectThings)
    if Updater and not checkedByUpdater[G.clientVersion] then
      checkedByUpdater[G.clientVersion] = true
      return Updater.check({
        version = G.clientVersion,
        host = G.host
      })
    else
      return EnterGame.onError(incorrectThings)
    end
  end

  protocolLogin = ProtocolLogin.create()
  protocolLogin.onLoginError = onProtocolError
  protocolLogin.onSessionKey = onSessionKey
  protocolLogin.onCharacterList = onCharacterList
  protocolLogin.onUpdateNeeded = onUpdateNeeded
  protocolLogin.onProxyList = onProxyList

  EnterGame.hide()
  loadBox = displayCancelBox(tr('Please wait'), tr('Connecting to login server...'))
  connect(loadBox, { onCancel = function(msgbox)
                                  loadBox = nil
                                  protocolLogin:cancelLogin()
                                  EnterGame.show()
                                end })

  if G.clientVersion == 1000 then -- some people don't understand that tibia 10 uses 1100 protocol
    G.clientVersion = 1100
  end
  -- if you have custom rsa or protocol edit it here
  g_game.setClientVersion(G.clientVersion)
  g_game.setProtocolVersion(g_game.getClientProtocolVersion(G.clientVersion))
  g_game.setCustomProtocolVersion(0)
  g_game.setCustomOs(-1) -- disable
  g_game.chooseRsa(G.host)
  if #server_params <= 3 and not g_game.getFeature(GameExtendedOpcode) then
    g_game.setCustomOs(2) -- set os to windows if opcodes are disabled
  end

  -- extra features from init.lua
  for i = 4, #server_params do
    g_game.enableFeature(tonumber(server_params[i]))
  end
  
  -- proxies
  if g_proxy then
    g_proxy.clear()
  end
  
  if modules.game_things.isLoaded() then
    g_logger.info("Connecting to: " .. server_ip .. ":" .. server_port)
    protocolLogin:login(server_ip, server_port, G.account, G.password, G.stayLogged)
  else
    loadBox:destroy()
    loadBox = nil
    EnterGame.show()
  end
end

function EnterGame.doLoginHttp()
  if G.host == nil or G.host:len() < 10 then
    return EnterGame.onError("Invalid server url: " .. G.host)    
  end

  loadBox = displayCancelBox(tr('Please wait'), tr('Connecting to login server...'))
  connect(loadBox, { onCancel = function(msgbox)
                                  loadBox = nil
                                  EnterGame.show()
                                end })                                
                              
  local data = {
    type = "login",
    account = G.account,
    accountname = G.account,
    email = G.account,
    password = G.password,
    accountpassword = G.password,
    --token = G.authenticatorToken,
    version = APP_VERSION,
    uid = G.UUID,
    stayloggedin = true
  }
  
  local server = serverSelector and serverSelector:getText() or ''
  if Servers and Servers[server] ~= nil then
    if type(Servers[server]) == "table" then
      local urls = Servers[server]      
      waitingForHttpResults = #urls
      for _, url in ipairs(urls) do
        HTTP.postJSON(url, data, onHTTPResult)
      end
    else
      waitingForHttpResults = 1
      HTTP.postJSON(G.host, data, onHTTPResult)    
    end
  end
  EnterGame.hide()
end

function EnterGame.onError(err)
  if loadBox then
    loadBox:destroy()
    loadBox = nil
  end
  local errorBox = displayErrorBox(tr('Login Error'), err)
  errorBox.onOk = EnterGame.show
end

function EnterGame.onLoginError(err)
  if loadBox then
    loadBox:destroy()
    loadBox = nil
  end
  local errorBox = displayErrorBox(tr('Login Error'), err)
  errorBox.onOk = EnterGame.show
  if err:lower():find("invalid") or err:lower():find("not correct") or err:lower():find("or password") then
    EnterGame.clearAccountFields()
  end
end
