local acceptWindow = {}
local statusUpdateEvent = nil
local qrCodeWindow = nil
local url = "http://localhost/payment/init.php"
local apiPassword = "SENHADASUAAPI"
local lastPaymentTime = {} -- Armazena o timestamp da última geração de pagamento por player
local PAYMENT_COOLDOWN = 300 -- 5 minutos em segundos

Pix = {}

function pixInit()
end

function pixTerminate()
    if statusUpdateEvent then
        removeEvent(statusUpdateEvent)
        statusUpdateEvent = nil
    end
    if qrCodeWindow then
        qrCodeWindow:destroy()
        qrCodeWindow = nil
    end
end

function Pix.checkPayment(url, paymentId)
    if not g_game.isOnline() then
        removeEvent(statusUpdateEvent)
        return true
    end

    if not paymentId or paymentId == "" then
        return
    end

    local function callback(data, err)
        if err or not data or data == "" then
            -- Em caso de erro, agenda nova verificação mas mantém a janela aberta
            if qrCodeWindow and not qrCodeWindow:isVisible() then
                qrCodeWindow:show()
                qrCodeWindow:raise()
                qrCodeWindow:focus()
            end
            statusUpdateEvent = scheduleEvent(function()
                Pix.checkPayment(url, paymentId)
            end, 10000)
            return
        end

        local response = json.decode(data)
        if not response then
            -- Se não conseguir decodificar, agenda nova verificação mas mantém a janela aberta
            if qrCodeWindow and not qrCodeWindow:isVisible() then
                qrCodeWindow:show()
                qrCodeWindow:raise()
                qrCodeWindow:focus()
            end
            statusUpdateEvent = scheduleEvent(function()
                Pix.checkPayment(url, paymentId)
            end, 10000)
            return
        end

        local status = response.status

        if status == "aprovado" or status == "approved" or status == "paid" then
            removeEvent(statusUpdateEvent)
            if qrCodeWindow then
                qrCodeWindow:hide()
                qrCodeWindow = nil
            end
            sendCancelBox("Aviso", "Seu pagamento foi confirmado e seus pontos adicionados!")
        elseif status == "pendente" or status == "pending" or status == "unpaid" then
            -- Mantém a janela visível enquanto o pagamento está pendente
            if qrCodeWindow then
                if qrCodeWindow:getChildById('Loading') then
                    qrCodeWindow:getChildById('Loading'):hide()
                end
                -- Garante que a janela continue visível
                if not qrCodeWindow:isVisible() then
                    qrCodeWindow:show()
                    qrCodeWindow:raise()
                    qrCodeWindow:focus()
                end
            end
            statusUpdateEvent = scheduleEvent(function()
                Pix.checkPayment(url, paymentId)
            end, 10000)
        elseif status == "cancelado" or status == "cancelled" then
            removeEvent(statusUpdateEvent)
            if qrCodeWindow then
                qrCodeWindow:hide()
                qrCodeWindow = nil
            end
            sendCancelBox("Aviso", "O pagamento foi cancelado. Nenhuma cobranca foi efetuada.")
        else
            removeEvent(statusUpdateEvent)
            if qrCodeWindow then
                qrCodeWindow:hide()
                qrCodeWindow = nil
            end
            sendCancelBox("Erro", "Erro ao verificar o pagamento. Status desconhecido: " .. tostring(status))
        end
    end

    local postData = {
        ["payment_id"] = paymentId,
        ["pass"] = apiPassword,
        ["metodo_pagamento"] = "PP"
    }

    HTTP.post(url, json.encode(postData), callback)
end


function Pix.returnQr(data, valor)
    local response = json.decode(data)
    if not response then
        sendCancelBox("Erro", "Erro ao processar a resposta da API.")
        return true
    end

    local base64 = response["qr_code_base64"]
    local copiaecola = response["qr_code"]
    local paymentId = response["payment_id"]

    if not base64 or not paymentId or not copiaecola then
        sendCancelBox("Aviso", "Dados incompletos na transacao. Tente novamente mais tarde.")
        return true
    end

    Pix.currentPaymentId = paymentId

    if not qrCodeWindow then
        qrCodeWindow = g_ui.displayUI('qrcodePix')
        if not qrCodeWindow then
            return true
        end
    end

    local qrCode = qrCodeWindow:getChildById('qrCode')
    local loading = qrCodeWindow:getChildById('Loading')

    if not qrCode or not loading then
        return true
    end

    qrCode:setImageSourceBase64(base64)
    loading:hide()

    qrCode.onClick = function()
        g_window.setClipboardText(copiaecola)
        sendCancelBox("Aviso", "Codigo Pix copiado para a area de transferencia.")
    end

    -- Garante que a janela esteja visível e não seja fechada automaticamente
    qrCodeWindow:show()
    qrCodeWindow:raise()
    qrCodeWindow:focus()
    
    -- Previne que a janela seja fechada automaticamente
    if qrCodeWindow.onClose then
        qrCodeWindow.onClose = nil
    end

    Pix.checkPayment(url, paymentId)
end

function Pix.sendPost(valor, playerAccount, playerCharacter)
    valor = tonumber(valor)

    if not valor or valor <= 0 then
        sendCancelBox("Erro", "Valor invalido.")
        return
    end

    -- Verifica cooldown
    local playerKey = playerAccount .. "_" .. (playerCharacter or "")
    local currentTime = os.time()
    local lastTime = lastPaymentTime[playerKey] or 0
    local timeSinceLastPayment = currentTime - lastTime

    if timeSinceLastPayment < PAYMENT_COOLDOWN then
        local remainingTime = PAYMENT_COOLDOWN - timeSinceLastPayment
        local minutes = math.floor(remainingTime / 60)
        local seconds = remainingTime % 60
        sendCancelBox("Aviso", string.format("Aguarde %d minuto(s) e %d segundo(s) antes de gerar um novo pagamento.", minutes, seconds))
        return
    end

    -- Atualiza o timestamp da última geração
    lastPaymentTime[playerKey] = currentTime

    local postData = {
        ["nameAccount"] = playerAccount,
        ["valor"] = valor,
        ["namePlayer"] = playerCharacter,
        ["pass"] = apiPassword,
        ["metodo_pagamento"] = "PP"
    }

    local function callback(data, err)
        if not err then
            Pix.returnQr(data, valor)
        else
            sendCancelBox("Erro", "Erro ao iniciar pagamento Pix.")
        end
    end

    HTTP.post(url, json.encode(postData), callback)
end



function onCancelPix()
    if qrCodeWindow and qrCodeWindow:getChildById('Loading') then
        qrCodeWindow:getChildById('Loading'):show()
    end

    if statusUpdateEvent then
        removeEvent(statusUpdateEvent)
        statusUpdateEvent = nil
    end

    if not Pix.currentPaymentId or Pix.currentPaymentId == "" then
        sendCancelBox("Erro", "Nenhuma transacao ativa para cancelar.")
        return
    end

    local postData = {
        ["payment_id"] = Pix.currentPaymentId,
        ["pass"] = apiPassword,
        ["metodo_pagamento"] = "PP",
        ["cancel_pix"] = true
    }

    local function callback(data, err)
        if qrCodeWindow and qrCodeWindow:getChildById('Loading') then
            qrCodeWindow:getChildById('Loading'):hide()
        end

        if not err then
            local response = json.decode(data)
            if response and response.status == "cancelado" then
                if qrCodeWindow then
                    qrCodeWindow:hide()
                    qrCodeWindow = nil
                end
                sendCancelBox("Aviso", "A transacao foi cancelada com sucesso.")
            elseif response and response.status == "erro" then
                sendCancelBox("Erro", response.message or "Erro ao cancelar a transacao.")
            else
                sendCancelBox("Erro", "Erro ao cancelar a transacao.")
            end
        else
            sendCancelBox("Erro", "Erro ao comunicar-se com a API para cancelar a transacao.")
        end
    end

    HTTP.post(url, json.encode(postData), callback)
end

_G.onCancelPix = onCancelPix

-- Função chamada pelo store.lua
function Pix.CreatePixPayment(valor)
    if not valor or valor <= 0 then
        sendCancelBox("Erro", "Valor invalido.")
        return
    end

    -- Tenta obter o nome do personagem primeiro, depois o nome da conta
    local playerName = nil
    local playerAccount = nil
    
    if g_game.isOnline() then
        local localPlayer = g_game.getLocalPlayer()
        if localPlayer then
            playerName = localPlayer:getName()
        end
    end
    
    -- Obtém o nome da conta
    playerAccount = G.account or G.accNameTfs
    
    if not playerAccount or playerAccount == "" then
        sendCancelBox("Erro", "Nao foi possivel obter o nome da conta.")
        return
    end
    
    -- Chama a função de envio
    Pix.sendPost(valor, playerAccount, playerName)
end
