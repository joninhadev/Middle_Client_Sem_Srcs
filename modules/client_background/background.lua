-- private variables
local background
local clientVersionLabel
local muteButton
local isMuted = false

local updateOnlineEvent = nil

-- public functions
function updateOnlinePlayers()
  if updateOnlineEvent then
    removeEvent(updateOnlineEvent)
    updateOnlineEvent = nil
  end

  if HTTP and HTTP.getJSON then
    HTTP.getJSON("https://www.middleearth-server.com/count_online.php", function(data, err)
      if err then return end
      if data and data.online then
        local countVal = tostring(data.online)
        local bar = background and background:getChildById('bottomBar')
        if bar then
          local panel = bar:getChildById('onlinePlayersPanel')
          if panel then
            panel:setVisible(true)
            local count = panel:getChildById('onlinePlayersCount')
            if count then count:setText(countVal) end
          end
        end
      end
    end)
  end
  
  updateOnlineEvent = scheduleEvent(updateOnlinePlayers, 60000)
end

function init()
  background = g_ui.displayUI('background')
  background:lower()

  clientVersionLabel = background:getChildById('clientVersionLabel')
  if clientVersionLabel then
    clientVersionLabel:setText('Middle Earth v3.0')
  end

  initBottomBar()
  updateOnlinePlayers()

  connect(g_game, { onGameStart = onGameStart })
  connect(g_game, { onGameEnd = onGameEnd })
end

function initBottomBar()
  local bar = background:getChildById('bottomBar')
  if not bar then return end

  local function bindBtn(id, fn)
    local btn = bar:getChildById(id)
    if btn then btn.onClick = fn end
  end

  -- Config button: block if CharacterList is visible
  bindBtn('configBtn', function()
    if modules.client_entergame and modules.client_entergame.CharacterList
       and modules.client_entergame.CharacterList.isVisible
       and modules.client_entergame.CharacterList.isVisible() then
      return
    end
    if modules.client_options then
      modules.client_options.toggle()
    end
  end)

  -- Sound/Mute toggle
  muteButton = bar:getChildById('muteBtn')
  if muteButton then
    muteButton.onClick = function()
      isMuted = not isMuted
      if isMuted then
        -- Mute: set volume to 0
        if EnterGame and EnterGame.muteStartupMusic then
          EnterGame.muteStartupMusic()
        end
        if g_sounds then
          for _, id in pairs(SoundChannels or {}) do
            local ch = g_sounds.getChannel(id)
            if ch then ch:setGain(0) end
          end
        end
        muteButton:setImageSource('/images/ui/entergame/menu-buttons/muted')
        muteButton:setTooltip(tr('Muted'))
      else
        -- Unmute: restore volume
        if EnterGame and EnterGame.unmuteStartupMusic then
          EnterGame.unmuteStartupMusic()
        end
        if g_sounds then
          for _, id in pairs(SoundChannels or {}) do
            local ch = g_sounds.getChannel(id)
            if ch then ch:setGain(1.0) end
          end
        end
        muteButton:setImageSource('/images/ui/entergame/menu-buttons/sound')
        muteButton:setTooltip(tr('Sound'))
      end
    end
  end

  bindBtn('exitBtn', function() g_app.exit() end)

  -- Social links (customize these URLs for your server)
  bindBtn('discordBtn', function() g_platform.openUrl('https://discord.gg/a3A6dPNq') end)
  bindBtn('youtubeBtn', function() g_platform.openUrl('https://youtube.com/@') end)
  bindBtn('instagramBtn', function() g_platform.openUrl('https://instagram.com/middle.earth.br/') end)
  bindBtn('wikiBtn', function() g_platform.openUrl('https://www.middleearth-server.com/middlewiki/index.php?title=P%C3%A1gina_principal') end)
end

function terminate()
  disconnect(g_game, { onGameStart = onGameStart })
  disconnect(g_game, { onGameEnd = onGameEnd })

  if clientVersionLabel then
    g_effects.cancelFade(clientVersionLabel)
  end
  background:destroy()

  Background = nil
end

function onGameStart()
  background:hide()
end

function onGameEnd()
  background:show()
end

function hide()
  background:hide()
end

function show()
  background:show()
end

function hideVersionLabel()
  if clientVersionLabel then
    clientVersionLabel:hide()
  end
end

function setVersionText(text)
  if clientVersionLabel then
    clientVersionLabel:setText(text)
  end
end

function getBackground()
  return background
end