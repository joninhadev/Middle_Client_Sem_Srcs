-- UI Widgets
local windowDialog
local buttonHolder
local labelTitle
local outfitBox
local panelMessage
local scrollPanel
local labelMessage

-- Global Variables
local OpcodeDialog = 80
local Actions = {
    open = 1,
    closed = 2
}

function init()
    connect(g_game, { onGameEnd = closeDialog })
    connect(LocalPlayer, { onPositionChange = onPositionChange })

    if not ProtocolGame or not ProtocolGame.registerExtendedOpcode then
        return
    end

    ProtocolGame.registerExtendedOpcode(OpcodeDialog, function(protocol, opcode, buffer)
        if not buffer or buffer == "" then
            return
        end

        local status, result = pcall(function()
            return json.decode(buffer)
        end)

        if not status then
            return
        end

        if result.action == Actions.open then
            createDialog(result.data)
        elseif result.action == Actions.closed then
            closeDialog()
        end
    end)

    windowDialog = g_ui.displayUI('npcdialog')

    buttonHolder = windowDialog:getChildById('buttonHolder')
    labelTitle = windowDialog:getChildById('labelTitle')
    scrollPanel = windowDialog:getChildById('scrollPanel')
    panelMessage = windowDialog:getChildById('panelMessage')
    outfitBox = windowDialog:getChildById('outfitBox')

    labelMessage = g_ui.createWidget('LabelText', panelMessage)
end

function terminate()
    disconnect(g_game, { onGameEnd = closeDialog })
    disconnect(Creature, { onPositionChange = onPositionChange })
    ProtocolGame.unregisterExtendedOpcode(OpcodeDialog)
    windowDialog:destroy()
end

function closeDialog()
    windowDialog:hide()
end

function onPositionChange(creature, newPos, oldPos)
    if creature:isLocalPlayer() then
        windowDialog:hide()
    end
end

function openDialog()
    windowDialog:raise()
    windowDialog:show()
end

function createDialog(value)
    local Npc = g_map.getCreatureById(value.npcId)
    if not Npc then
        return
    end

    labelTitle:setText(Npc:getName())
    outfitBox:setOutfit(Npc:getOutfit())

    labelMessage:clearText()
    labelMessage:setText(value.message)

    scrollPanel:setVisible(labelMessage:getTextSize().height > panelMessage.limitText)

    buttonHolder:destroyChildren()
    if value.options ~= '' then
        local options = value.options:split('&')

        for i = 1, #options do
            local button = g_ui.createWidget('OptionButton', buttonHolder)
            button:setText(tr(options[i]))
            button.onClick = function()
                g_game.talkChannel(MessageModes.NpcTo, 0, options[i])
            end
        end

        buttonHolder:setHeight(#options > 5 and 68 or 34)
    end

    openDialog()
end
