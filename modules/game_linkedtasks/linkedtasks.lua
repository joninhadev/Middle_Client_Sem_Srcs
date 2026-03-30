-- game_linkedtasks / linkedtasks.lua

linkedTasksWindow = nil
local taskButton  = nil

local OPCODE_LINKED_TASKS = 101
local categories = {"Iniciante", "Intermediaria", "Hard"}
local CARD_WIDTH = 100
local selectedCard = nil

-- -- Outfit helpers ------------------------------------------
local function normalizeOutfit(outfit)
    if not outfit then return {type = 0} end
    if outfit.lookType then
        outfit.type   = outfit.lookType
        outfit.head   = outfit.lookHead   or 0
        outfit.body   = outfit.lookBody   or 0
        outfit.legs   = outfit.lookLegs   or 0
        outfit.feet   = outfit.lookFeet   or 0
        outfit.addons = outfit.lookAddons or 0
        outfit.mount  = outfit.lookMount  or 0
    end
    return outfit
end

-- -- Module lifecycle ----------------------------------------
function init()
    connect(g_game, {
        onGameStart = onGameStart,
        onGameEnd   = destroy
    })

    linkedTasksWindow = g_ui.displayUI('linkedtasks')
    if linkedTasksWindow then
        linkedTasksWindow:setVisible(false)
        setupCategoryCombo()
    end

    taskButton = modules.client_topmenu.addRightGameToggleButton(
        'linkedTasksButton',
        tr('Linked Tasks'),
        '/images/topbuttons/taskSystem',
        toggle
    )
    taskButton:setOn(false)

    ProtocolGame.registerExtendedOpcode(OPCODE_LINKED_TASKS, onExtendedOpcode)
end

function terminate()
    disconnect(g_game, {
        onGameStart = onGameStart,
        onGameEnd   = destroy
    })
    ProtocolGame.unregisterExtendedOpcode(OPCODE_LINKED_TASKS, onExtendedOpcode)

    if taskButton then
        taskButton:destroy()
        taskButton = nil
    end
    destroy()
end

function onGameStart()
    destroy()
    linkedTasksWindow = g_ui.displayUI('linkedtasks')
    if linkedTasksWindow then
        linkedTasksWindow:setVisible(false)
        setupCategoryCombo()
    end
end

function destroy()
    if linkedTasksWindow then
        linkedTasksWindow:destroy()
        linkedTasksWindow = nil
    end
end

-- -- Category ComboBox ---------------------------------------
function setupCategoryCombo()
    if not linkedTasksWindow then return end
    local combo = linkedTasksWindow:recursiveGetChildById('categoryCombo')
    if not combo then return end

    combo:clearOptions()
    for _, cat in ipairs(categories) do
        combo:addOption(cat)
    end
    combo:setCurrentIndex(1)

    combo.onOptionChange = function(widget, text, data)
        sendCategoryRequest(text)
    end
end

function sendCategoryRequest(category)
    if not g_game.isOnline() then return end
    local proto = g_game.getProtocolGame()
    if proto then
        proto:sendExtendedOpcode(OPCODE_LINKED_TASKS,
            json.encode({ action = "info", category = category }))
    end
end

-- -- Toggle / Show / Hide ------------------------------------
function toggle()
    if not linkedTasksWindow then return end
    if linkedTasksWindow:isVisible() then hide() else show() end
end

function show()
    if not linkedTasksWindow then return end
    linkedTasksWindow:show()
    linkedTasksWindow:raise()
    linkedTasksWindow:focus()
    if taskButton then taskButton:setOn(true) end

    local combo = linkedTasksWindow:recursiveGetChildById('categoryCombo')
    local cat = combo and combo:getCurrentOption() and combo:getCurrentOption().text or "Iniciante"
    sendCategoryRequest(cat)
end

function hide()
    if not linkedTasksWindow then return end
    linkedTasksWindow:hide()
    if taskButton then taskButton:setOn(false) end
end

-- -- Network (generic action sender) -------------------------
function sendAction(actionType)
    if not g_game.isOnline() then return end
    local proto = g_game.getProtocolGame()
    if not proto then return end

    local combo = linkedTasksWindow and linkedTasksWindow:recursiveGetChildById('categoryCombo')
    local cat = "Iniciante"
    if combo and combo:getCurrentOption() then
        cat = combo:getCurrentOption().text
    end

    proto:sendExtendedOpcode(OPCODE_LINKED_TASKS,
        json.encode({ action = actionType, category = cat }))
end

local updateDetailPanel

function sendViewTaskRequest(taskId, category)
    if not g_game.isOnline() then return end
    local proto = g_game.getProtocolGame()
    if not proto then return end
    proto:sendExtendedOpcode(OPCODE_LINKED_TASKS,
        json.encode({ action = "viewTask", taskId = taskId, category = category }))
end

function onExtendedOpcode(protocol, opcode, buffer)
    local ok, data = pcall(json.decode, buffer)
    if not ok or not data then return end

    if data.action == "update" then
        updateUI(data)
    elseif data.action == "viewTaskInfo" then
        -- Show details for a specific task (view only, no state change)
        updateDetailPanel(data)

        -- Update reward slots with the viewed task's rewards
        if linkedTasksWindow then
            local rewardsPanel = linkedTasksWindow:recursiveGetChildById('rewardsPanel')
            if rewardsPanel and data.rewards then
                for i = 1, 4 do
                    local slot = rewardsPanel:getChildById('rewardSlot' .. i)
                    if slot then
                        if data.rewards[i] then
                            slot:setItemId(data.rewards[i])
                            slot:setItemCount(data.rewardsCount and data.rewardsCount[i] or 1)
                        else
                            slot:setItemId(0)
                        end
                    end
                end
            end
        end
    end
end

-- -- Task Card builder ---------------------------------------
local function createTaskCard(parent, taskInfo, isCurrent, isDone, isLocked, progress, category)
    local card = g_ui.createWidget('TaskCardWidget', parent)

    if isCurrent and not isDone then
        card:setOn(true)
    end

    -- Allow clicking ANY task card to view its details
    card:setFocusable(true)
    card.onMouseRelease = function(self, mousePosition, mouseButton)
        if mouseButton == MouseLeftButton then
            -- Remove border from previously selected card
            if selectedCard and selectedCard ~= self then
                selectedCard:setBorderColor("#3d3d3d")
            end
            -- Highlight this card
            self:setBorderWidth(1)
            self:setBorderColor("#FFDD44")
            selectedCard = self
            sendViewTaskRequest(taskInfo.id, category or "Iniciante")
            return true
        end
        return false
    end

    local lockIcon = card:getChildById('lockIcon')
    if lockIcon then
        lockIcon:setVisible(isLocked)
    end

    local creatureBox = card:getChildById('creatureBox')
    if creatureBox then
        creatureBox:setOutfit(normalizeOutfit(taskInfo.outfit))
        creatureBox:setAnimate(true)
        if isLocked then
            creatureBox:setOpacity(0.25)
        elseif isDone then
            creatureBox:setOpacity(0.50)
        end
    end

    local nameLabel = card:getChildById('nameLabel')
    if nameLabel then
        nameLabel:setText(taskInfo.name or "???")
        if isDone then
            nameLabel:setColor("#55FF55")
            nameLabel:setMarginTop(5)
        elseif isCurrent then
            nameLabel:setColor("#FFFFFF")
			nameLabel:setMarginTop(5)
        elseif isLocked then
            nameLabel:setColor("#666666")
			nameLabel:setMarginTop(5)
        else
            nameLabel:setColor("#AAAAAA")
			nameLabel:setMarginTop(5)
        end
    end

    -- Progress bar only (no text on cards)
    local progressLabel = card:getChildById('progressLabel')
    if progressLabel then progressLabel:setText("") end

    local barBg   = card:getChildById('barBackground')
    local barFill = barBg and barBg:getChildById('barFill')

    if isCurrent and not isDone then
        if barFill then
            local prog  = progress or 0
            local total = taskInfo.count or 1
            local pct   = math.min(prog / total, 1.0)
            local maxW  = barBg:getWidth()
            if maxW <= 0 then maxW = CARD_WIDTH - 8 end
            barFill:setWidth(math.max(1, math.floor(maxW * pct)))
            if pct >= 1.0 then
                barFill:setBackgroundColor("#55FF55")
            elseif pct >= 0.5 then
                barFill:setBackgroundColor("#FFAA22")
            else
                barFill:setBackgroundColor("#4488FF")
            end
        end
    else
        if barBg then barBg:setVisible(false) end
    end

    local badgeLabel = card:getChildById('badgeLabel')
    if badgeLabel then
        if isDone then
            badgeLabel:setText("Concluída")
            badgeLabel:setColor("#55FF55")
			badgeLabel:setMarginTop(10)
        elseif isCurrent then
            badgeLabel:setText("Disponível")
            badgeLabel:setColor("#FFFFFF")
            badgeLabel:setMarginTop(10)
        elseif isLocked then
            badgeLabel:setText("Bloqueada")
            badgeLabel:setColor("#666666")
			badgeLabel:setMarginTop(10)
        else
            badgeLabel:setText("")
        end
    end
end

-- -- Detail panel builder ------------------------------------
updateDetailPanel = function(data)
    if not linkedTasksWindow then return end

    local detailContent = linkedTasksWindow:recursiveGetChildById('detailContent')
    if not detailContent then return end

    detailContent:destroyChildren()

    -- If category locked and no specific task data, show lock message
    if data.state == "category_locked" and not data.taskName and not data.targetsDetail then
        local lbl = g_ui.createWidget('Label', detailContent)
        lbl:setText("Clique em uma task para\nver os detalhes.")
        lbl:setTextAlign(AlignCenter)
        lbl:setColor("#666666")
        lbl:setFont("verdana-11px-rounded")
        lbl:setHeight(30)
        lbl:setBackgroundColor("alpha")
        return
    end

    -- If no active/completed task AND no specific task data, show placeholder
    if (not data.state or data.state == "locked" or data.state == "all_done") and not data.taskName and not data.targetsDetail then
        local lbl = g_ui.createWidget('Label', detailContent)
        lbl:setText("Clique em uma task para\nver os detalhes.")
        lbl:setTextAlign(AlignCenter)
        lbl:setColor("#666666")
        lbl:setFont("verdana-11px-rounded")
        lbl:setHeight(20)
        lbl:setBackgroundColor("alpha")
        return
    end

    -- Show task name if viewing a specific task
    if data.taskName then
        local titleLabel = g_ui.createWidget('Label', detailContent)
        titleLabel:setText(data.taskName)
        titleLabel:setTextAlign(AlignCenter)
        titleLabel:setColor("#FFDD44")
        titleLabel:setFont("verdana-11px-rounded")
        titleLabel:setHeight(16)
        titleLabel:setBackgroundColor("alpha")

        local spacer0 = g_ui.createWidget('Panel', detailContent)
        spacer0:setHeight(4)
        spacer0:setBackgroundColor("alpha")
    end
    -- Creatures header
    local creaturesHeader = g_ui.createWidget('Label', detailContent)
    creaturesHeader:setText("Criaturas:")
    creaturesHeader:setTextAlign(AlignCenter)
    creaturesHeader:setColor("#CCCCCC")
    creaturesHeader:setFont("verdana-11px-rounded")
    creaturesHeader:setHeight(16)
    creaturesHeader:setBackgroundColor("alpha")

    -- Creature list
    if data.targetsDetail then
        for _, tgt in ipairs(data.targetsDetail) do
            local row = g_ui.createWidget('Label', detailContent)
            row:setText("  " .. tgt.name)
            row:setTextAlign(AlignCenter)
            row:setColor("#AAAAAA")
            row:setFont("verdana-11px-rounded")
            row:setHeight(14)
            row:setBackgroundColor("alpha")
        end
    end

    -- Spacer
    local spacer1 = g_ui.createWidget('Panel', detailContent)
    spacer1:setHeight(6)
    spacer1:setBackgroundColor("alpha")

    -- Progress count
    local progressCount = g_ui.createWidget('Label', detailContent)
    local prog  = data.progress or 0
    local total = data.totalCount or 0
    progressCount:setText("" .. prog .. " de " .. total)
    progressCount:setTextAlign(AlignCenter)
    progressCount:setColor("#FFFFFF")
    progressCount:setFont("verdana-11px-rounded")
    progressCount:setHeight(16)
    progressCount:setBackgroundColor("alpha")

    -- Progress bar in detail panel
    local detailBarBg = g_ui.createWidget('Panel', detailContent)
    detailBarBg:setHeight(8)
    detailBarBg:setBackgroundColor("#222222")

    local pct = 0
    if total > 0 then pct = math.min(prog / total, 1.0) end
    local barW = detailBarBg:getWidth()
    if barW <= 0 then barW = 200 end

    local detailBarFill = g_ui.createWidget('Panel', detailBarBg)
    detailBarFill:addAnchor(AnchorTop, 'parent', AnchorTop)
    detailBarFill:addAnchor(AnchorLeft, 'parent', AnchorLeft)
    detailBarFill:addAnchor(AnchorBottom, 'parent', AnchorBottom)
    detailBarFill:setWidth(math.max(1, math.floor(barW * pct)))
    if pct >= 1.0 then
        detailBarFill:setBackgroundColor("#55FF55")
    elseif pct >= 0.5 then
        detailBarFill:setBackgroundColor("#FFAA22")
    else
        detailBarFill:setBackgroundColor("#4488FF")
    end

    -- XP Reward (with icon)
    local xpRow = g_ui.createWidget('Panel', detailContent)
    xpRow:setHeight(16)
    xpRow:setBackgroundColor("alpha")
    xpRow:setLayout(UIHorizontalLayout.create(xpRow))

    local xpIcon = g_ui.createWidget('UIWidget', xpRow)
    xpIcon:setWidth(15)
    xpIcon:setHeight(15)
--    xpIcon:setImageSource('/modules/game_linkedtasks/images/xp')
    xpIcon:setMarginLeft(2)
    xpIcon:setMarginTop(1)

    local xpLabel = g_ui.createWidget('Label', xpRow)
    xpLabel:setText("Experiencia: " .. (data.xpReward or 0) .. " pontos.")
    xpLabel:setTextAlign(AlignLeft)
    xpLabel:setColor("#FFDD44")
    xpLabel:setFont("verdana-11px-rounded")
    xpLabel:setWidth(150)
    xpLabel:setHeight(16)
    xpLabel:setMarginLeft(4)
    xpLabel:setMarginTop(2)
    xpLabel:setBackgroundColor("alpha")

    -- Task Points (with star icon)
    local ptsRow = g_ui.createWidget('Panel', detailContent)
    ptsRow:setHeight(16)
    ptsRow:setBackgroundColor("alpha")
    ptsRow:setLayout(UIHorizontalLayout.create(ptsRow))

    local starIcon = g_ui.createWidget('UIWidget', ptsRow)
    starIcon:setWidth(14)
    starIcon:setHeight(14)
--    starIcon:setImageSource('/modules/game_linkedtasks/images/icon-star-gold')
    starIcon:setMarginLeft(2)
    starIcon:setMarginTop(0)

    local ptsLabel = g_ui.createWidget('Label', ptsRow)
    ptsLabel:setText("Pontos: +" .. (data.taskPoints or 1) .. " ponto(s)")
    ptsLabel:setTextAlign(AlignLeft)
    ptsLabel:setColor("#FFB800")
    ptsLabel:setFont("verdana-11px-rounded")
    ptsLabel:setWidth(150)
    ptsLabel:setHeight(16)
    ptsLabel:setMarginLeft(5)
    ptsLabel:setMarginTop(4)
    ptsLabel:setBackgroundColor("alpha")

    -- Spacer
    local spacer2 = g_ui.createWidget('Panel', detailContent)
    spacer2:setHeight(6)
    spacer2:setBackgroundColor("alpha")

    -- Fixed reward
    local fixedHeader = g_ui.createWidget('Label', detailContent)
    fixedHeader:setText("Recompensa:")
    fixedHeader:setTextAlign(AlignCenter)
    fixedHeader:setColor("#CCCCCC")
    fixedHeader:setFont("verdana-11px-rounded")
    fixedHeader:setHeight(16)
    fixedHeader:setBackgroundColor("alpha")

    if data.fixedRewardId and data.fixedRewardId > 0 then
        local rewardRow = g_ui.createWidget('Panel', detailContent)
        rewardRow:setHeight(36)
        rewardRow:setBackgroundColor("alpha")
        rewardRow:setLayout(UIHorizontalLayout.create(rewardRow))

        local itemWidget = g_ui.createWidget('Item', rewardRow)
        itemWidget:setVirtual(true)
        itemWidget:setItemId(data.fixedRewardId)
        itemWidget:setItemCount(data.fixedRewardCount or 1)
        itemWidget:setWidth(34)
        itemWidget:setHeight(34)
        itemWidget:setMarginLeft(110)
    end
end

-- -- Update entire UI from server payload --------------------
function updateUI(data)
    if not linkedTasksWindow then return end

    -- Rank label
    local rankLabel = linkedTasksWindow:recursiveGetChildById('rankLabel')
    if rankLabel and data.rankTitle then
        local txt = "Rank: " .. data.rankTitle .. " (" .. (data.rankPoints or 0) .. " pts)"
        if data.nextRankTitle then
            txt = txt .. " - Proximo: " .. data.nextRankTitle .. " (" .. data.nextRankMin .. " pts)"
        end
        rankLabel:setText(txt)
    end

    -- Sync ComboBox
    local combo = linkedTasksWindow:recursiveGetChildById('categoryCombo')
    if combo and data.category then
        local current = combo:getCurrentOption()
        if not current or current.text ~= data.category then
            combo:setCurrentOption(data.category, true)
        end
    end

    -- Task cards
    local container = linkedTasksWindow:recursiveGetChildById('taskListContainer')
    local scrollbar = linkedTasksWindow:recursiveGetChildById('taskScrollbar')

    if container then
        container:destroyChildren()

        if data.tasks then
            local foundCurrent = false
            for _, taskInfo in ipairs(data.tasks) do
                local isCurrent = (taskInfo.id == data.currentTaskId)
                local isDone    = false
                local isLocked  = false

                if data.state == "category_locked" then
                    isLocked = true
                    isCurrent = false
                elseif isCurrent then
                    foundCurrent = true
                    isDone = (data.state == "all_done")
                elseif not foundCurrent then
                    isDone = true
                else
                    isLocked = true
                end

                createTaskCard(container, taskInfo, isCurrent, isDone, isLocked, data.progress, data.category)
            end
        end

        if scrollbar then
            local totalCards = data.tasks and #data.tasks or 0
            local totalWidth = totalCards * (CARD_WIDTH + 6)
            local overflow   = math.max(0, totalWidth - container:getWidth())
            scrollbar:setRange(0, overflow)
            scrollbar.onValueChange = function(_, value)
                local first = container:getChildByIndex(1)
                if first then first:setMarginLeft(-value) end
            end
        end
    end

    -- Reward slots
    local rewardsPanel = linkedTasksWindow:recursiveGetChildById('rewardsPanel')
    if rewardsPanel then
        for i = 1, 4 do
            local slot = rewardsPanel:getChildById('rewardSlot' .. i)
            if slot then
                if data.rewards and data.rewards[i] then
                    slot:setItemId(data.rewards[i])
                    slot:setItemCount(data.rewardsCount and data.rewardsCount[i] or 1)
                else
                    slot:setItemId(0)
                end
            end
        end
    end

    -- Detail panel (right side)
    updateDetailPanel(data)

    -- Action button
    local actionButton = linkedTasksWindow:recursiveGetChildById('actionButton')
    if actionButton then
        if data.state == "category_locked" then
            actionButton:setText(tr("Categoria Bloqueada"))
            actionButton.onClick = nil
            actionButton:setEnabled(false)
        elseif data.state == "completed" then
            actionButton:setText(tr("Claim Reward"))
            actionButton.onClick = function() sendAction("claim") end
            actionButton:setEnabled(true)
        elseif data.state == "active" then
            actionButton:setText(tr("Em progresso ..."))
            actionButton.onClick = nil
            actionButton:setEnabled(false)
        elseif data.state == "locked" then
            local txt = data.reqLevel
                and ("Locked (Level " .. data.reqLevel .. ")")
                or "Locked"
            actionButton:setText(tr(txt))
            actionButton.onClick = nil
            actionButton:setEnabled(false)
        elseif data.state == "available" then
            actionButton:setText(tr("Iniciar Task"))
            actionButton.onClick = function() sendAction("start") end
            actionButton:setEnabled(true)
        elseif data.state == "all_done" then
            actionButton:setText(tr("Todas completas!"))
            actionButton.onClick = nil
            actionButton:setEnabled(false)
        else
            actionButton:setText(tr("N/A"))
            actionButton.onClick = nil
            actionButton:setEnabled(false)
        end
    end
end