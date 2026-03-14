local acceptWindow = {}
local statusUpdateEvent
local successAnimationEvent

local donationWindow
local donaterInfo
local qrCodeScreen
local successScreen

local urlPixInit = "https://www.middleearth-server.com/payment/init.php"
local urlPixVerify = "https://www.middleearth-server.com/payment/init.php"
local apiPassword = "@jona052911"
local BETA_COIN_MULTIPLIER = 0

local successAnimationFrame = 0
local unknownStatusCount = {} -- Contador de verificações com status desconhecido por paymentId
local lastPaymentTime = {} -- Armazena o timestamp da última geração de pagamento por player
local PAYMENT_COOLDOWN = 300 -- 5 minutos em segundos

local function cleanCPF(cpf)
    return cpf:gsub("%D", "")
end

local function isValidFullName(name)
    return name and name:find(" ") and #name >= 5
end

local function isValidCPF(cpf)
    cpf = cleanCPF(cpf)
    return #cpf == 11
end

local function updateNextButton()
    if not donaterInfo then return end
    
    local name = donaterInfo.donaterName:getText()
    local cpf  = donaterInfo.donaterCpf:getText()
    local coins = donaterInfo.coinsValue:getCurrentOption()

    if isValidFullName(name) and isValidCPF(cpf) and coins then
        donaterInfo.next:setEnabled(true)
    else
        donaterInfo.next:setEnabled(false)
    end
end

local function showDonaterInfo()
    if not donaterInfo then return end
    donaterInfo:setVisible(true)
    qrCodeScreen:setVisible(false)
    successScreen:setVisible(false)
end

local function showQrCode()
    if not qrCodeScreen then return end
    if not donationWindow then return end
    
    -- Garante que a janela principal esteja visível
    if not donationWindow:isVisible() then
        donationWindow:show()
        donationWindow:raise()
        donationWindow:focus()
    end
    
    donaterInfo:setVisible(false)
    qrCodeScreen:setVisible(true)
    successScreen:setVisible(false)
end

local function startSuccessAnimation()
    if not successScreen then return end
    
    local successIcon = successScreen:recursiveGetChildById("successIcon")
    if not successIcon then return end
    
    successIcon:setVisible(true)
    successIcon:setImageClip(torect(string.format("%d %d %d %d", (108 * successAnimationFrame), 0, 108, 108)))
    
    successAnimationFrame = successAnimationFrame + 1
    
    if successAnimationFrame >= 13 then
        if successAnimationEvent then
            removeEvent(successAnimationEvent)
            successAnimationEvent = nil
        end
        successAnimationFrame = 0
    else
        successAnimationEvent = scheduleEvent(startSuccessAnimation, 100)
    end
end

local function showSuccess()
    if not successScreen then return end
    donaterInfo:setVisible(false)
    qrCodeScreen:setVisible(false)
    successScreen:setVisible(true)
    
    successAnimationFrame = 0
    if successAnimationEvent then
        removeEvent(successAnimationEvent)
    end
    
    startSuccessAnimation()
end

local function sendCancelBox(header, text)
    local function cancelFunc()
        if #acceptWindow > 0 then
            acceptWindow[#acceptWindow]:destroy()
            acceptWindow = {}
        end
    end

    if #acceptWindow > 0 then
        acceptWindow[#acceptWindow]:destroy()
    end

    acceptWindow[#acceptWindow + 1] = displayGeneralBox(header, text, {
        { text = "OK", callback = cancelFunc }
    }, cancelFunc)
end

function closePix()
    if donationWindow then
        donationWindow:hide()
    end
    
    if statusUpdateEvent then
        removeEvent(statusUpdateEvent)
        statusUpdateEvent = nil
    end
end

function onCpfChange(widget, text)
    -- Remove todos os caracteres não numéricos
    local clean = cleanCPF(text)
    
    -- Limita a 11 dígitos
    if #clean > 11 then
        clean = clean:sub(1, 11)
    end
    
    -- Aplica a máscara progressivamente conforme o usuário digita
    local formatted = ""
    if #clean == 0 then
        formatted = ""
    elseif #clean <= 3 then
        formatted = clean
    elseif #clean <= 6 then
        formatted = clean:sub(1, 3) .. "." .. clean:sub(4)
    elseif #clean <= 9 then
        formatted = clean:sub(1, 3) .. "." .. clean:sub(4, 6) .. "." .. clean:sub(7)
    else
        formatted = clean:sub(1, 3) .. "." .. clean:sub(4, 6) .. "." .. clean:sub(7, 9) .. "-" .. clean:sub(10, 11)
    end
    
    -- Atualiza o texto apenas se for diferente para evitar loop infinito
    local currentText = widget:getText()
    if currentText ~= formatted then
        widget:setText(formatted)
        -- Move o cursor para o final após formatação
        scheduleEvent(function()
            if widget and widget:getText() == formatted then
                widget:setCursorPos(#formatted)
            end
        end, 10)
    end
    
    updateNextButton()
end

function copyCode()
    if qrCodeScreen then
        local pixKey = qrCodeScreen:getChildById("pixKey")
        if pixKey then
            g_window.setClipboardText(pixKey:getText())
        end
    end
end

function chooseTextMode(fieldId, buttonId)
    if not donaterInfo then return end
    
    local field = donaterInfo:getChildById(fieldId)
    local button = donaterInfo:getChildById(buttonId)
    
    if field and button then
        local isHidden = field:isTextHidden()
        field:setTextHidden(not isHidden)
        button:setOn(not isHidden)
    end
end

function Pix_checkPayment(paymentId)
    if not g_game.isOnline() then
        return
    end

    local postData = {
        ["pass"] = apiPassword,
        ["metodo_pagamento"] = "PP",
        ["payment_id"] = paymentId
    }

    local function callback(data, err)
        if err or not data or data == "" then
            -- Em caso de erro, continua verificando mas mantém a janela aberta
            if donationWindow and not donationWindow:isVisible() then
                donationWindow:show()
                donationWindow:raise()
                donationWindow:focus()
            end
            if qrCodeScreen and not qrCodeScreen:isVisible() then
                showQrCode()
            end
            statusUpdateEvent = scheduleEvent(function()
                Pix_checkPayment(paymentId)
            end, 5000) -- Aumenta o intervalo em caso de erro
            return
        end

        local res = json.decode(data)
        if not res then
            -- Se não conseguir decodificar, continua verificando mas mantém a janela aberta
            if donationWindow and not donationWindow:isVisible() then
                donationWindow:show()
                donationWindow:raise()
                donationWindow:focus()
            end
            if qrCodeScreen and not qrCodeScreen:isVisible() then
                showQrCode()
            end
            statusUpdateEvent = scheduleEvent(function()
                Pix_checkPayment(paymentId)
            end, 5000) -- Aumenta o intervalo em caso de erro
            return
        end

        -- Limpa o contador quando recebe um status conhecido
        if unknownStatusCount[paymentId] then
            unknownStatusCount[paymentId] = nil
        end
        
        if res.status == "aprovado" or res.status == "approved" or res.status == "paid" then
            showSuccess()
            if statusUpdateEvent then
                removeEvent(statusUpdateEvent)
                statusUpdateEvent = nil
            end
            return
        elseif res.status == "pendente" or res.status == "pending" or res.status == "unpaid" then
            -- Mantém a janela do QR code visível
            if donationWindow and not donationWindow:isVisible() then
                donationWindow:show()
                donationWindow:raise()
                donationWindow:focus()
            end
            if qrCodeScreen and not qrCodeScreen:isVisible() then
                showQrCode()
            end
            statusUpdateEvent = scheduleEvent(function()
                Pix_checkPayment(paymentId)
            end, 3000)
        elseif res.status == "cancelado" or res.status == "cancelled" then
            if statusUpdateEvent then
                removeEvent(statusUpdateEvent)
                statusUpdateEvent = nil
            end
            if unknownStatusCount[paymentId] then
                unknownStatusCount[paymentId] = nil
            end
            sendCancelBox("Error", "Payment cancelled or invalid.")
            showDonaterInfo()
        else
            -- Status desconhecido - continua verificando ao invés de mostrar erro imediatamente
            -- Pode ser que a API ainda não processou o pagamento
            -- Mantém a janela do QR code visível
            if donationWindow and not donationWindow:isVisible() then
                donationWindow:show()
                donationWindow:raise()
                donationWindow:focus()
            end
            if qrCodeScreen and not qrCodeScreen:isVisible() then
                showQrCode()
            end
            
            -- Conta quantas vezes recebemos status desconhecido
            unknownStatusCount[paymentId] = (unknownStatusCount[paymentId] or 0) + 1
            
            -- Se receber status desconhecido muitas vezes (mais de 10 vezes = 30 segundos), mostra erro
            if unknownStatusCount[paymentId] > 10 then
                if statusUpdateEvent then
                    removeEvent(statusUpdateEvent)
                    statusUpdateEvent = nil
                end
                unknownStatusCount[paymentId] = nil
                sendCancelBox("Error", "Payment cancelled or invalid.")
                showDonaterInfo()
            else
                statusUpdateEvent = scheduleEvent(function()
                    Pix_checkPayment(paymentId)
                end, 3000)
            end
        end
    end

    HTTP.post(urlPixVerify, json.encode(postData), callback)
end

function sendDonate()
    if not donaterInfo then 
        return 
    end
    
    local name = donaterInfo.donaterName:getText()
    local cpf  = cleanCPF(donaterInfo.donaterCpf:getText())
    local option = donaterInfo.coinsValue:getCurrentOption()

    if not option then
        sendCancelBox("Error", "Select a coin amount.")
        return
    end

    local optionText = option.text
    local coins = tonumber(optionText:match("(%d+)"))
    local valorStr = optionText:match("R%$ ([%d,%.]+)")
    
    local valor = nil
    if valorStr then
        local cleanValor = valorStr:gsub("%.", ""):gsub(",", ".")
        valor = tonumber(cleanValor)
    end
    
    if not coins or not valor then
        sendCancelBox("Error", "Invalid coin amount format.")
        return
    end

    local coinsToCredit = math.floor(coins * BETA_COIN_MULTIPLIER)

    if not isValidFullName(name) then
        sendCancelBox("Error", "Enter your full name.")
        return
    end

    if not isValidCPF(cpf) then
        sendCancelBox("Error", "Invalid CPF.")
        return
    end

    -- Tenta obter o nome do personagem primeiro, depois o nome da conta
    local playerName = nil
    if g_game.isOnline() then
        local localPlayer = g_game.getLocalPlayer()
        if localPlayer then
            playerName = localPlayer:getName()
        end
    end
    
    -- Obtém o nome da conta
    local playerAccount = G.account or G.accNameTfs
    
    -- Se não conseguir o nome do personagem, usa o nome da conta
    if not playerName or playerName == "" then
        playerName = playerAccount
    end
    
    if not playerName or playerName == "" then
        sendCancelBox("Error", "Unable to get player or account name.")
        return
    end
    
    if not playerAccount or playerAccount == "" then
        sendCancelBox("Error", "Unable to get account name.")
        return
    end
    
    -- Verifica cooldown antes de gerar novo pagamento
    local playerKey = playerAccount .. "_" .. (playerName or "")
    local currentTime = os.time()
    local lastTime = lastPaymentTime[playerKey] or 0
    local timeSinceLastPayment = currentTime - lastTime
    
    if timeSinceLastPayment < PAYMENT_COOLDOWN then
        sendCancelBox("Error", "You need to wait a few minutes to create a new payment.")
        return
    end
    
    -- Atualiza o timestamp da última geração (antes de fazer a requisição)
    lastPaymentTime[playerKey] = currentTime
    
    local postData = {
        ["pass"] = apiPassword,
        ["metodo_pagamento"] = "PP",
        ["nameAccount"] = playerAccount,
        ["namePlayer"] = playerName,
        ["valor"] = valor,
        ["cpf"] = cpf,
        ["nome"] = name,
        ["coins"] = coinsToCredit,
        ["coin_multiplier"] = BETA_COIN_MULTIPLIER
    }

    local function callback(data, err)
        
        -- HTTP.postJSON já decodifica o JSON automaticamente
        -- Se data for uma tabela, já está decodificada
        -- Se data for string vazia ou nil, houve erro
        
        if err then
            lastPaymentTime[playerKey] = nil
            local errStr = tostring(err)
            local httpCode = errStr:match("(%d%d%d)")
            if httpCode then
                if httpCode == "403" then
                    sendCancelBox("Error", "HTTP 403 Forbidden\n\nThe request was blocked.\n\nThis is likely a Cloudflare security block.\n\nSolutions:\n1. Whitelist client IP in Cloudflare\n2. Lower Cloudflare security level\n3. Disable challenge for API endpoints")
                    return
                elseif httpCode == "429" then
                    sendCancelBox("Error", "HTTP 429 Too Many Requests\n\nRate limit exceeded.\n\nPlease wait a few minutes and try again.")
                    return
                elseif httpCode:match("^5%d%d") then
                    sendCancelBox("Error", "HTTP " .. httpCode .. " Server Error\n\nThe server encountered an error.\n\nPlease contact the administrator.")
                    return
                end
            end
            sendCancelBox("Error", "Unable to start PIX transaction.\nError: " .. tostring(err))
            return
        end
        
        if not data then
            lastPaymentTime[playerKey] = nil
            sendCancelBox("Error", "Server returned empty response. Please check server configuration.")
            return
        end
        
        if type(data) == "string" and data == "" then
            lastPaymentTime[playerKey] = nil
            sendCancelBox("Error", "Server returned empty response.\n\nPossible causes:\n- Cloudflare blocking the request\n- Server error\n- Network issue\n\nPlease check server logs or try again later.")
            return
        end
        
        if type(data) == "string" and (data:find("<!DOCTYPE") or data:find("<html") or data:find("cloudflare") or data:find("challenge")) then
            lastPaymentTime[playerKey] = nil
            sendCancelBox("Error", "Cloudflare challenge detected.\n\nThe server may be blocking automated requests.\n\nPlease contact the server administrator to:\n1. Whitelist the client IP\n2. Adjust Cloudflare security settings\n3. Use a different endpoint")
            return
        end
        
        local res = data
        if type(data) == "string" then
            local lowerData = data:lower()
            if lowerData:find("<!doctype") or lowerData:find("<html") or lowerData:find("cloudflare") or lowerData:find("challenge") or lowerData:find("cf-") then
                lastPaymentTime[playerKey] = nil
                sendCancelBox("Error", "Cloudflare Challenge Detected!\n\nThe request was blocked by Cloudflare security.\n\nPossible solutions:\n1. Whitelist the client IP in Cloudflare\n2. Adjust Cloudflare security level\n3. Disable Cloudflare challenge for API endpoints\n4. Use Cloudflare API token instead\n\nContact server administrator.")
                return
            end
            res = json.decode(data)
            if not res then
                lastPaymentTime[playerKey] = nil
                sendCancelBox("Error", "Invalid server response format.\n\nResponse preview:\n" .. (data:sub(1, 100) or "Empty"))
                return
            end
        end
        
        if not res or type(res) ~= "table" then
            lastPaymentTime[playerKey] = nil
            sendCancelBox("Error", "Invalid server response format. Server may be returning empty or invalid data.")
            return
        end
        
        if res.error then
            lastPaymentTime[playerKey] = nil
            local errorMsg = tostring(res.error)
            if res.retry_after then
                errorMsg = errorMsg .. "\n\nAguarde " .. math.floor(res.retry_after / 60) .. " minuto(s) antes de tentar novamente."
            end
            sendCancelBox("Error", errorMsg)
            return
        end
        
        if not res.qr_code_base64 then
            lastPaymentTime[playerKey] = nil
            sendCancelBox("Error", "QR Code not generated.")
            return
        end

        local paymentId = res.payment_id or res.id

        if qrCodeScreen then
            local code = qrCodeScreen:recursiveGetChildById("code")
            if code then
                code:setImageSourceBase64(res.qr_code_base64)
            end
            
            local pixKey = qrCodeScreen:recursiveGetChildById("pixKey")
            if pixKey and res.qr_code then
                pixKey:setText(res.qr_code)
            end
        end

        if donationWindow and not donationWindow:isVisible() then
            donationWindow:show()
            donationWindow:raise()
            donationWindow:focus()
        end
        
        showQrCode()
        
        if paymentId then
            statusUpdateEvent = scheduleEvent(function()
                Pix_checkPayment(paymentId)
            end, 2000)
        end
    end

    -- Aumenta temporariamente o timeout para requisições PIX (podem demorar até 60 segundos)
    local originalTimeout = HTTP.timeout
    HTTP.timeout = 60
    
    HTTP.postJSON(urlPixInit, postData, callback)
    
    -- Restaura o timeout original após um delay
    scheduleEvent(function()
        HTTP.timeout = originalTimeout
    end, 100)
end

function init()
    g_ui.importStyle('game_payment')
    
    donationWindow = g_ui.createWidget('PixWindow', rootWidget)
    
    if not donationWindow then
        return
    end
    
    donationWindow:hide()

    donaterInfo   = donationWindow:recursiveGetChildById("donaterInfo")
    qrCodeScreen  = donationWindow:recursiveGetChildById("qrCode")
    successScreen = donationWindow:recursiveGetChildById("success")

    if not donaterInfo or not qrCodeScreen or not successScreen then
        return
    end

    showDonaterInfo()

    local nextButton = donaterInfo:getChildById("next")
    if nextButton then
        nextButton.onClick = sendDonate
    end
    
    local successClose = successScreen:getChildById("close")
    if successClose then
        successClose.onClick = closePix
    end

    donaterInfo.donaterName.onTextChange = updateNextButton
    donaterInfo.donaterCpf.onTextChange = onCpfChange
    donaterInfo.coinsValue.onOptionChange = updateNextButton

    updateNextButton()
end

function terminate()
    if statusUpdateEvent then
        removeEvent(statusUpdateEvent)
        statusUpdateEvent = nil
    end
    
    if successAnimationEvent then
        removeEvent(successAnimationEvent)
        successAnimationEvent = nil
    end
    
    if donationWindow then
        donationWindow:destroy()
        donationWindow = nil
    end
    
    donaterInfo = nil
    qrCodeScreen = nil
    successScreen = nil
    successAnimationFrame = 0
end

function show()
    if donationWindow then
        donationWindow:show()
        donationWindow:raise()
        donationWindow:focus()
        showDonaterInfo()
    end
end

function toggle()
    if donationWindow then
        if donationWindow:isVisible() then
            closePix()
        else
            show()
        end
    end
end

function showSuccessTest()
    if donationWindow then
        donationWindow:show()
        donationWindow:raise()
        donationWindow:focus()
        showSuccess()
    end
end
