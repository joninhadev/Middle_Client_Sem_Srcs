local window = nil
local selectedEntry = nil
local consoleEvent = nil
local taskButton
local pointsGeneral
local currentPage = 1
local totalPages = 1
local TASK_LIMITS = {}

function init()
    connect(g_game, {
        onGameStart = onGameStart,
        onGameEnd = destroy
    })

    window = g_ui.displayUI('tasks')
    window:setVisible(false)

    g_keyboard.bindKeyDown('Ctrl+Shift+A', toggleWindow)
    g_keyboard.bindKeyDown('Escape', hideWindowzz)
    taskButton = modules.client_topmenu.addLeftGameButton('taskButton', tr('Tasks'), '/images/topbuttons/taskSystem', toggleWindow)
    ProtocolGame.registerExtendedJSONOpcode(215, parseOpcode)
end

function terminate()
    disconnect(g_game, {
        onGameEnd = destroy
    })
    ProtocolGame.unregisterExtendedJSONOpcode(215, parseOpcode)
    taskButton:destroy()
    destroy()
end

function onGameStart()
    if (window) then
        window:destroy()
        window = nil
    end

    window = g_ui.displayUI('tasks')
    window:setVisible(false)
    if window and window.listSearch and window.listSearch.search then
        window.listSearch.search.onKeyPress = onFilterSearch
    end
end

function destroy()
    if (window) then
        window:destroy()
        window = nil
    end
end

function parseOpcode(protocol, opcode, data)
    if data and data.action == 'confirm_reset' then
        showResetConfirmation(data.taskId, data.taskName, data.cost, data.page)
        return
    end
    
    if data and data.pagination then
        currentPage = data.pagination.currentPage
        totalPages = data.pagination.totalPages
        updatePaginationButtons()
    end
    
    if data and data.message then
        setTaskConsoleText(data.message, data.color)
    else
        updateTasks(data)
    end
    
    if data and data.pointsGeneral then
        pointsGeneral = data.pointsGeneral
    end
end

function sendOpcode(data)
   if not data then
    return
  end

  local protocolGame = g_game.getProtocolGame()

  if protocolGame then
    protocolGame:sendExtendedJSONOpcode(215, data)
  end
end

function onItemSelect(list, focusedChild, unfocusedChild, reason)
    if not window then return true end
    
    if focusedChild then
        selectedEntry = tonumber(focusedChild:getId())

        if (not selectedEntry) then
            return true
        end

        -- Verificar se os botões existem antes de tentar acessá-los
        if window.finishButton then window.finishButton:hide() end
        if window.startButton then window.startButton:hide() end
        if window.abortButton then window.abortButton:hide() end
        
        -- Botão reset sempre visível, mas desabilitado se não atingiu o limite
        if window.resetButton then
            window.resetButton:setEnabled(false)
        end
        
        local children = window.selectionList:getChildren()

        for _, child in ipairs(children) do
            local id = tonumber(child:getId())

            if (selectedEntry == id) then
                -- Verificar se a task está completa (progresso = 100%)
                local progressWidth = child.progress:getWidth()
                local isTaskComplete = (progressWidth >= 159) -- 159 é o width máximo

                if isTaskComplete then
                    -- Task completa: mostrar botão Finish
                    if window.finishButton then window.finishButton:show() end
                else
                    local killsText = child.kills:getText()
                    
                    -- Verificar se é uma task ativa (tem contagem de kills)
                    if killsText and killsText:find('/') then
                        -- Task ativa mas não completa: mostrar botão Abort
                        if window.abortButton then window.abortButton:show() end
                    else
                        -- Task disponível para iniciar: mostrar botão Start
                        if window.startButton then window.startButton:show() end
                    end
                end
                
                -- Habilitar botão de reset apenas se atingiu o limite diário
                if window.resetButton and TASK_LIMITS and TASK_LIMITS[id] and TASK_LIMITS[id].completed >= 3 then
                    window.resetButton:setEnabled(true)
                end
            end
        end
    end
end

function onFilterSearch()
    addEvent(function()
        if not window or not window.listSearch or not window.listSearch.search then return end
        
        local searchText = window.listSearch.search:getText():lower():trim()
        local children = window.selectionList:getChildren()

        if (searchText:len() >= 1) then
            for _, child in ipairs(children) do
                local text = child.name:getText():lower()

                if (text:find(searchText)) then
                    child:show()
                else
                    child:hide()
                end
            end
        else
            for _, child in ipairs(children) do
                child:show()
            end
        end
    end)
end

function start()
    if (not selectedEntry) then
        return not setTaskConsoleText("Please select a monster from the list.", "red")
    end

    sendOpcode({
        action = 'start',
        entry = selectedEntry,
        page = currentPage
    })
end

function finish()
    if (not selectedEntry) then
        return not setTaskConsoleText("Please select a monster from the list.", "red")
    end

    sendOpcode({
        action = 'finish',
        entry = selectedEntry,
        page = currentPage
    })
end

function abort()
    local cancelConfirm = nil

    if (cancelConfirm) then
        cancelConfirm:destroy()
        cancelConfirm = nil
    end

    if (not selectedEntry) then
        return not setTaskConsoleText("Please select a monster from the list.", "red")
    end

    local yesFunc = function()
        if cancelConfirm then cancelConfirm:destroy() end
        cancelConfirm = nil
        sendOpcode({
            action = 'cancel',
            entry = selectedEntry,
            page = currentPage
        })
    end

    local noFunc = function()
        if cancelConfirm then cancelConfirm:destroy() end
        cancelConfirm = nil
    end

    cancelConfirm = displayGeneralBox(tr('Tasks'), tr("Do you really want to abort this task?"), {
        {
            text = tr('Yes'),
            callback = yesFunc
        },
        {
            text = tr('No'),
            callback = noFunc
        },
        anchor = AnchorHorizontalCenter
    }, yesFunc, noFunc)
end

function resetTask()
    if (not selectedEntry) then
        return not setTaskConsoleText("Please select a task from the list.", "red")
    end

    -- Verificar se atingiu o limite diário
    if not (TASK_LIMITS and TASK_LIMITS[selectedEntry] and TASK_LIMITS[selectedEntry].completed >= 3) then
        return not setTaskConsoleText("You haven't reached the daily limit for this task yet.", "red")
    end

    sendOpcode({
        action = 'reset',
        entry = selectedEntry,
        page = currentPage
    })
end

function showResetConfirmation(taskId, taskName, cost, page)
    local confirmReset = nil

    local yesFunc = function()
        if confirmReset then confirmReset:destroy() end
        confirmReset = nil
        sendOpcode({
            action = 'confirm_reset_yes',
            entry = taskId,
            page = page
        })
    end

    local noFunc = function()
        if confirmReset then confirmReset:destroy() end
        confirmReset = nil
    end

    local message = string.format("Você deseja resetar a task '%s'?\n O valor é de %d gold coin(s).", taskName, cost)
    
    confirmReset = displayGeneralBox(tr('Reset Task'), tr(message), {
        {
            text = tr('Yes'),
            callback = yesFunc
        },
        {
            text = tr('No'),
            callback = noFunc
        },
        anchor = AnchorHorizontalCenter
    }, yesFunc, noFunc)
end

function updateTasks(data)
    if not window or not window.selectionList then return end
    
    local selectionList = window.selectionList
    selectionList.onChildFocusChange = onItemSelect
    selectionList:destroyChildren()
    local playerTaskIds = {}

    -- Armazenar limites de tasks globalmente
    TASK_LIMITS = data.taskLimits or {}

    for _, task in ipairs(data['playerTasks']) do
        local button = g_ui.createWidget("SelectionButtonTask", window.selectionList)
        button:setId(task.id)
        table.insert(playerTaskIds, task.id)
        button.creature:setOutfit(task.looktype)
        button.creature:setAnimate(true)
        button.name:setText(task.name)
        
        -- Adicionar informação de limite diário
        local dailyCompleted = 0
        if TASK_LIMITS[task.id] then
            dailyCompleted = TASK_LIMITS[task.id].completed or 0
        end
        button.limit:setColoredText({'Daily: ', '#4CFFAB', '['..dailyCompleted ..'/' .. (data.dailyTaskLimit or 3) ..']' , '#FFD644'})
        
        if window.pointsGeneral then
            window.pointsGeneral:setText('Task Points: ' .. data.pointsGeneral .. '')
        end

        button.kills:setColoredText({'Kills: ', '#B6FF00', ''..task.done ..'/' .. task.kills ..'' , '#FFFFFF'})
        button.reward:setColoredText({'Reward: ', '#267FBA', ''..task.exp ..'' , '#FFFFFF', 'exp', '#FFFFFF'})
        
        if not (task.taskPoints == nil) then
            button.rewardTaskPoints:setText('Task Points: ' .. task.taskPoints .. '')
        else
            button.rewardTaskPoints:setText('Task Points: 0')
        end

        if not (task.item == nil) then
            button.item:setItemId(task.item)
        else
            button.item:setItem(nil)
        end

        -- Calcular progresso corretamente (garantir que não ultrapasse 159)
        local progress = 159 * task.done / task.kills
        progress = math.min(progress, 159) -- Garantir que não passe do máximo
        button.progress:setWidth(progress)
        
        if selectionList then
            selectionList:focusChild(button)
        end
    end

    for _, task in ipairs(data['allTasks']) do
        if (not table.contains(playerTaskIds, task.id)) then
            local button = g_ui.createWidget("SelectionButtonTask", window.selectionList)
            button:setId(task.id)
            button.creature:setOutfit(task.looktype)
            button.creature:setAnimate(true)
            button.name:setText(task.name)
            
            -- Adicionar informação de limite diário
            local dailyCompleted = 0
            if TASK_LIMITS[task.id] then
                dailyCompleted = TASK_LIMITS[task.id].completed or 0
            end
            button.limit:setColoredText({'Daily: ', '#4CFFAB', '['..dailyCompleted ..'/' .. (data.dailyTaskLimit or 3) ..']' , '#FFD644'})

            if window.pointsGeneral then
                window.pointsGeneral:setText('Pontos: ' .. data.pointsGeneral .. '')
            end

            button.kills:setColoredText({'Kills: ', '#267FBA', ''..task.kills ..'' , '#FFFFFF'})
            button.reward:setColoredText({'Reward: ', '#B6FF00', ''..task.exp ..'' , '#FFFFFF', ' xp', '#FFFFFF'})
            
            if not (task.taskPoints == nil) then
                button.rewardTaskPoints:setText('Pontos: ' .. task.taskPoints .. '')
            else
                button.rewardTaskPoints:setText('Pontos: 0')
            end

            if not (task.item == nil) then
                button.item:setItemId(task.item)
            else
                button.item:setItem(nil)
            end
            button.progress:setWidth(0)
            if selectionList then
                selectionList:focusChild(button)
            end
        end
    end

    if selectionList then
        local firstChild = selectionList:getFirstChild()
        if firstChild then
            selectionList:focusChild(firstChild)
        end
    end
    
    onFilterSearch()
end

function toggleWindow()
    if (not g_game.isOnline()) then
        return
    end

    if (window:isVisible()) then
        sendOpcode({
            action = 'hide'
        })
        window:setVisible(false)
    else
        currentPage = 1
        sendOpcode({
            action = 'info',
            page = 1
        })
        window:setVisible(true)
    end
end

function hideWindowzz()
    if (not g_game.isOnline()) then
        return
    end

    if (window:isVisible()) then
        sendOpcode({
            action = 'hide'
        })
        window:setVisible(false)
    end
end

function setTaskConsoleText(text, color)
    if (not color) then
        color = 'white'
    end

    if window and window.info then
        window.info:setText(text)
        window.info:setColor(color)
    end

    if consoleEvent then
        removeEvent(consoleEvent)
        consoleEvent = nil
    end

    consoleEvent = scheduleEvent(function()
        if window and window.info then
            window.info:setText('')
        end
    end, 5000)

    return true
end

function nextPage()
    if currentPage < totalPages then
        currentPage = currentPage + 1
        requestTasksPage(currentPage)
    end
end

function prevPage()
    if currentPage > 1 then
        currentPage = currentPage - 1
        requestTasksPage(currentPage)
    end
end

function requestTasksPage(page)
    sendOpcode({
        action = 'info',
        page = page
    })
end

function updatePaginationButtons()
    if window then
        if window.prevButton then window.prevButton:setEnabled(currentPage > 1) end
        if window.nextButton then window.nextButton:setEnabled(currentPage < totalPages) end
        if window.pageInfo then window.pageInfo:setText(string.format("Page %d/%d", currentPage, totalPages)) end
    end
end