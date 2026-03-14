-- private variables
local background
local clientVersionLabel
local muteButton
local isMuted = false

-- public functions
function init()
  background = g_ui.displayUI('background')
  background:lower()

  clientVersionLabel = background:getChildById('clientVersionLabel')
  if clientVersionLabel then
    clientVersionLabel:setText('Middle Earth v3.0')
  end

  initBottomBar()

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
      if not g_sounds then return end
      isMuted = not isMuted
      if isMuted then
        for _, id in pairs(SoundChannels or {}) do
          local ch = g_sounds.getChannel(id)
          if ch then ch:setGain(0) end
        end
        muteButton:setImageSource('/images/ui/entergame/menu-buttons/muted')
        muteButton:setTooltip(tr('Muted'))
      else
        for _, id in pairs(SoundChannels or {}) do
          local ch = g_sounds.getChannel(id)
          if ch then ch:setGain(1.0) end
        end
        muteButton:setImageSource('/images/ui/entergame/menu-buttons/sound')
        muteButton:setTooltip(tr('Sound'))
      end
    end
  end

  bindBtn('exitBtn', function() g_app.exit() end)

  -- Social links (customize these URLs for your server)
  bindBtn('discordBtn', function() g_platform.openUrl('https://discord.gg/YOUR_SERVER') end)
  bindBtn('youtubeBtn', function() g_platform.openUrl('https://youtube.com/@YOUR_SERVER') end)
  bindBtn('instagramBtn', function() g_platform.openUrl('https://instagram.com/YOUR_SERVER') end)
  bindBtn('wikiBtn', function() g_platform.openUrl('https://wiki.YOUR_SERVER.com') end)
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