local EXTENDED_OPCODE = 1

local window = nil
local windowButton = nil

local purchaseWindow = nil
local amountGroup = nil
local successWindow = nil

local giftWindow = nil

local featuredPanel, featuredBtn = nil, nil
local historyPanel = nil
local historyLimit = 0
local historyTotal = 0
local historyPage = 1
local categoryWidgets = { panels = {}, buttons = {}, sub = {} }

local ownedSort = nil

local GameStore = {}
local DONATION_URL = ""

local Actions = {
  NOTIFICATION = 0,
  FETCH_BASE = 1,
  FETCH_FEATURED = 2,
  FETCH_PRODUCTS = 3,
  FETCH_CURRENCY = 4,
  PURCHASE = 5,
  FETCH_HISTORY = 6,
  HISTORY_NEW = 7,
  GIFTED = 8,
  UPDATE_PRODUCT = 9,
  SET_OWNED = 10,
  FETCH_OWNED = 11
}

local SortTypes = {
  PRICE_LOWER = 1,
  PRICE_HIGHER = 2,
  ALPHABETICAL = 3,
  ON_SALE = 4,
  OWNED = 5,
  CURRENCY_POINTS = 6,
  CURRENCY_GOLD = 7,
  CURRENCY_ITEM = 8,
  CAN_AFFORD = 9
}
local sorting = 0

local Currencies = {
  POINTS = 1,
  GOLD = 2,
  ITEM = 3
}

local ProductTypes = {
  ITEM = 0,
  MOUNT = 1,
  OUTFIT = 2,
  IMAGE = 3,
  WINGS = 4,
  AURA = 5,
  SHADER = 6
}

function init()
  connect(
    g_game,
    {
      onGameStart = create,
      onGameEnd = destroy
    }
  )

  ProtocolGame.registerOpcode(GameServerOpcodes.GameServerGameStore, parseGameStore)

  if g_game.isOnline() then
    create()
  end
end

function terminate()
  disconnect(
    g_game,
    {
      onGameStart = create,
      onGameEnd = destroy
    }
  )

  ProtocolGame.unregisterOpcode(GameServerOpcodes.GameServerGameStore, parseGameStore)

  destroy()
end

function create()
  if window then
    return
  end

  windowButton = modules.client_topmenu.addRightGameToggleButton("gamestore", "Game Store", "/images/topbuttons/shop",
    toggle)
  window = g_ui.displayUI("store")
  window:hide()
  window.onEscape = hide

  purchaseWindow = g_ui.loadUI("purchase", window)
  purchaseWindow:hide()
  purchaseWindow.onEscape = cancelPurchase

  successWindow = g_ui.displayUI("success")
  successWindow:hide()
  successWindow.onEscape = confirmAnimation

  successWindow.button.onClick = confirmAnimation

  giftWindow = g_ui.loadUI("gift", window)
  giftWindow:hide()
  giftWindow.onEscape = hideGift

  window.tabBar:setContentWidget(window.content)

  featuredPanel = g_ui.loadUI("featured")
  featuredBtn = window.tabBar:addTab(nil, featuredPanel)
  featuredBtn.icon:setImageClip("0 0 13 13")
  featuredBtn.label:setText("Featured")

  historyPanel = g_ui.loadUI("history")
  window.tabBar:addTabCustom(window.history, historyPanel)

  window.tabBar.onTabChange = onCategoryChange
end

function destroy()
  if historyPanel then
    historyPanel:destroy()
    historyPanel = nil
  end

  if amountGroup then
    amountGroup:destroy()
    amountGroup = nil
  end

  if successWindow then
    successWindow:destroy()
    successWindow = nil
  end

  if window then
    purchaseWindow = nil
    giftWindow = nil

    window:destroy()
    window = nil
  end

  if windowButton then
    windowButton:destroy()
    windowButton = nil
  end

  GameStore.loaded = false
  GameStore.History = nil
  categoryWidgets = { panels = {}, buttons = {}, sub = {} }
  ownedSort = nil
end

function parseGameStore(protocol, msg)
  local action = msg:getU8()
  if action == Actions.NOTIFICATION then
    parseNotification(msg)
  elseif action == Actions.FETCH_BASE then
    parseBase(msg)
  elseif action == Actions.FETCH_FEATURED then
    parseFeatured(msg)
  elseif action == Actions.FETCH_PRODUCTS then
    parseProducts(msg)
  elseif action == Actions.FETCH_CURRENCY then
    parseCurrency(msg)
  elseif action == Actions.PURCHASE then
    parsePurchase(msg)
  elseif action == Actions.FETCH_HISTORY then
    parseHistory(msg)
  elseif action == Actions.HISTORY_NEW then
    parseHistoryNew(msg)
  elseif action == Actions.GIFTED then
    giftWindow:hide()
  elseif action == Actions.UPDATE_PRODUCT then
    parseProductUpdate(msg)
  elseif action == Actions.SET_OWNED then
    parseProductOwned(msg)
  elseif action == Actions.FETCH_OWNED then
    parseOwnedProducts(msg)
  end
end

function parseNotification(msg)
  displayErrorBox(msg:getString(), msg:getString())
end

function parseBase(msg)
  GameStore.loaded = true
  GameStore.Categories = {}

  local categoriesCount = msg:getU8()

  for i = 1, categoriesCount do
    local categoryId = msg:getU8()
    local name = msg:getString()
    local image = msg:getString()
    local otui = msg:getString()

    GameStore.Categories[categoryId] = { products = {} }

    g_ui.createWidget("VerticalSeparator", window.tabBar.buttonsPanel)

    if not categoryWidgets.sub[categoryId] then
      categoryWidgets.sub[categoryId] = { panels = {}, buttons = {} }
    end

    categoryWidgets.panels[categoryId] = g_ui.loadUI(otui)
    categoryWidgets.buttons[categoryId] = window.tabBar:addTab(nil, categoryWidgets.panels[categoryId])

    categoryWidgets.buttons[categoryId].icon:setImageSource("/images/store/" .. image)
    categoryWidgets.buttons[categoryId].label:setText(name)
    categoryWidgets.buttons[categoryId].categoryId = categoryId
    categoryWidgets.panels[categoryId].left.tabBar:setContentWidget(categoryWidgets.panels[categoryId].content)
    categoryWidgets.panels[categoryId].left.tabBar.categoryId = categoryId

    categoryWidgets.panels[categoryId].left.search.onTextChange = onSearch

    categoryWidgets.panels[categoryId].left.sort:addOption("Price Lower", SortTypes.PRICE_LOWER)
    categoryWidgets.panels[categoryId].left.sort:addOption("Price Higher", SortTypes.PRICE_HIGHER)
    categoryWidgets.panels[categoryId].left.sort:addOption("Alphabetical", SortTypes.ALPHABETICAL)
    categoryWidgets.panels[categoryId].left.sort.onOptionChange = onSortChange

    categoryWidgets.panels[categoryId].left.sale.onCheckChange = onShowOnSale
    if categoryWidgets.panels[categoryId].left.owned then
      categoryWidgets.panels[categoryId].left.owned.onCheckChange = onShowOwned
    end

    categoryWidgets.panels[categoryId].left.currencyPoints.onCheckChange = onCurrencyChange
    categoryWidgets.panels[categoryId].left.currencyGold.onCheckChange = onCurrencyChange
    categoryWidgets.panels[categoryId].left.currencyItem.onCheckChange = onCurrencyChange

    categoryWidgets.panels[categoryId].left.afford.onCheckChange = onCanAffordChange

    local subCategoriesCount = msg:getU8()
    for k = 1, subCategoriesCount do
      local subCategoryId = msg:getU8()
      local subCategoryName = msg:getString()
      local subCategoryImage = msg:getString()
      otui = msg:getString()

      categoryWidgets.sub[categoryId].panels[subCategoryId] = g_ui.loadUI(otui)
      categoryWidgets.sub[categoryId].panels[subCategoryId].categoryId = categoryId
      categoryWidgets.sub[categoryId].panels[subCategoryId].subCategoryId = subCategoryId
      categoryWidgets.sub[categoryId].buttons[subCategoryId] = categoryWidgets.panels[categoryId].left.tabBar:addTab(nil,
        categoryWidgets.sub[categoryId].panels[subCategoryId])
      categoryWidgets.sub[categoryId].buttons[subCategoryId].icon:setImageSource("/images/store/" .. subCategoryImage)
      categoryWidgets.sub[categoryId].buttons[subCategoryId].label:setText(subCategoryName)
      categoryWidgets.sub[categoryId].buttons[subCategoryId].subCategoryId = subCategoryId
      categoryWidgets.sub[categoryId].panels[subCategoryId].list:setText("No products here.")
    end

    categoryWidgets.panels[categoryId].left.tabBar.onTabChange = onSubCategoryChange
  end

  sorting = 0
  setSorting(SortTypes.PRICE_LOWER)

  parseCurrency(msg)
  DONATION_URL = msg:getString()
end

function parseProduct(msg)
  local productId = msg:getU16()
  local name = msg:getString()
  local description = msg:getString()
  local currency = msg:getU8()
  local onSale = msg:getU8() == 1

  local cost = 0
  local amount = 0
  local bulk = msg:getU8() == 1
  local bulks = 0
  if bulk then
    cost = {}
    amount = {}
    bulks = msg:getU8()
    for j = 1, bulks do
      cost[j] = msg:getU64()
      amount[j] = msg:getU16()
    end
  else
    cost = msg:getU64()
    amount = msg:getU16()
  end

  local icon = nil
  local productType = msg:getU8()
  if productType == ProductTypes.ITEM then
    icon = msg:getU16()
  elseif productType == ProductTypes.MOUNT then
    icon = msg:getU16()
  elseif productType == ProductTypes.OUTFIT then
    icon = msg:getU16()
  elseif productType == ProductTypes.IMAGE then
    icon = msg:getString()
  elseif productType == ProductTypes.WINGS then
    icon = msg:getU16()
  elseif productType == ProductTypes.AURA then
    icon = msg:getU16()
  elseif productType == ProductTypes.SHADER then
    icon = msg:getString()
  end
  local owned = msg:getU8() == 1

  return productId, name, description, onSale, cost, currency, amount, bulk, productType, icon, owned
end

function parseFeatured(msg)
  if not GameStore.Bundles then
    GameStore.Bundles = {}
  end

  if not GameStore.Products then
    GameStore.Products = {}
  end

  local bundlesCount = msg:getU8()

  if bundlesCount == 0 then
    featuredPanel.list.bundles:hide()
    featuredPanel.list.bundlesLabel:hide()
  end

  for i = 1, bundlesCount do
    local bundleId = msg:getU8()
    local name = msg:getString()
    local description = msg:getString()
    local currency = msg:getU8()
    local cost = msg:getU64()
    local totalCost = msg:getU64()
    local image = msg:getString()

    local widget = g_ui.createWidget("StoreBundleEntry", featuredPanel.list.bundles)
    widget.bundleId = bundleId
    widget.name:setText(name)
    widget.price:setText(comma_value(cost))
    widget.save:setText(string.format("Save %s", comma_value(totalCost - cost)))

    setProductCurrency(widget, currency)

    widget.previews.image:setImageSource("/images/store/" .. image)
    widget.previews.image:show()

    widget.onClick = onBundleClicked

    GameStore.Bundles[bundleId] = {
      name = name,
      description = description,
      cost = cost,
      currency = currency,
      image = image
    }
  end

  local salesCount = msg:getU8()

  for i = 1, salesCount do
    local productId, name, description, onSale, cost, currency,
    amount, bulk, productType, icon, owned = parseProduct(msg)
    local widget = createProductWidget(productType, icon, featuredPanel.list.sales, true)

    widget.name:setText(name)
    setProductPrice(widget, bulk, cost, currency, owned)
    g_ui.createWidget("StoreSaleFlag", widget)
    widget.productId = productId
    widget.onClick = onProductClicked

    if owned then
      widget:hide()
    end

    GameStore.Products[productId] = {
      name = name,
      description = description,
      bulk = bulk,
      cost = cost,
      currency = currency,
      amount = amount,
      type = productType,
      icon = icon,
      sale = onSale,
      owned = owned
    }
  end

  if salesCount == 0 then
    featuredPanel.list.salesSeparator:hide()
    featuredPanel.list.sales:hide()
    featuredPanel.list.salesLabel:hide()
  end

  local popularCount = msg:getU8()
  for i = 1, popularCount do
    local productId, name, description, onSale, cost, currency,
    amount, bulk, productType, icon, owned = parseProduct(msg)
    local widget = createProductWidget(productType, icon, featuredPanel.list.popular, true)

    widget.name:setText(name)
    setProductPrice(widget, bulk, cost, currency, owned)

    if onSale then
      g_ui.createWidget("StoreSaleFlag", widget)
    end

    widget.productId = productId
    widget.onClick = onProductClicked

    if owned then
      widget:hide()
    end

    if not GameStore.Products[productId] then
      GameStore.Products[productId] = {
        name = name,
        description = description,
        bulk = bulk,
        cost = cost,
        currency = currency,
        amount = amount,
        type = productType,
        icon = icon,
        sale = onSale,
        owned = owned
      }
    end
  end

  if popularCount == 0 then
    featuredPanel.list.popularSeparator:hide()
    featuredPanel.list.popular:hide()
    featuredPanel.list.popularLabel:hide()
  end
end

function parseProducts(msg)
  local categoryId = msg:getU8()
  local subCategoryId = msg:getU8()

  GameStore.Categories[categoryId].products[subCategoryId] = {}
  if not GameStore.Products then
    GameStore.Products = {}
  end

  local player = g_game.getLocalPlayer()
  local productsCount = msg:getU8()
  for i = 1, productsCount do
    local productId, name, description, onSale, cost, currency,
    amount, bulk, productType, icon, owned = parseProduct(msg)
    local widget = createProductWidget(productType, icon, categoryWidgets.sub[categoryId].panels[subCategoryId].list)

    widget:setId("product" .. productId)
    widget.name:setText(name)
    setProductPrice(widget, bulk, cost, currency, owned)

    if onSale then
      g_ui.createWidget("StoreSaleFlag", widget)
    end

    widget.productId = productId
    widget.onClick = onProductClicked

    if owned then
      widget:hide()
    end

    if not GameStore.Products[productId] then
      GameStore.Products[productId] = {
        name = name,
        description = description,
        bulk = bulk,
        cost = cost,
        currency = currency,
        amount = amount,
        type = productType,
        icon = icon,
        sale = onSale,
        owned = owned
      }
    end

    table.insert(GameStore.Categories[categoryId].products[subCategoryId], productId)

    categoryWidgets.sub[categoryId].panels[subCategoryId].list:setText("")
  end

  sortProducts(categoryId, subCategoryId)
end

function parseCurrency(msg)
  GameStore.points = msg:getU32()
  GameStore.gold = msg:getU64()
  GameStore.items = msg:getU32()
  window.pointsPanel.label:setText(comma_value(GameStore.points))

  local gold = comma_value(GameStore.gold)
  if GameStore.gold > 10 ^ 12 then
    gold = comma_value(math.floor(GameStore.gold / 10 ^ 9)) .. "B"
  elseif GameStore.gold > 10 ^ 9 then
    gold = comma_value(math.floor(GameStore.gold / 10 ^ 6)) .. "M"
  end

  window.goldPanel.label:setText(gold)
  window.itemPanel.label:setText(comma_value(GameStore.items))

  local currentTab = window.tabBar:getCurrentTab()
  if currentTab then
    if currentTab.tabPanel.left then
      local categoryId = currentTab.categoryId
      local subCategoryId = currentTab.tabPanel.left.tabBar:getCurrentTab().subCategoryId
      sortProducts(categoryId, subCategoryId)
    end
  end
end

function parsePurchase(msg)
  local success = msg:getU8() == 1
  if success then
    successWindow.animation:setImageClip("0 0 108 108")
    successWindow.text:setText(msg:getString())
    successWindow:show()
    hide()
  end
end

function parseHistory(msg)
  if not GameStore.History then
    GameStore.History = {}
  end

  historyPanel.prev.onClick = prevHistoryPage
  historyPanel.next.onClick = nextHistoryPage

  historyPage = msg:getU8()

  if historyPage == 1 then
    historyLimit = msg:getU8()
    historyTotal = msg:getU16()
  end

  historyPanel.pages:setText(string.format("Page %d / %d", historyPage,
    math.max(1, math.ceil(historyTotal / historyLimit))))

  local historyCount = msg:getU8()

  if historyCount == 0 then
    historyPanel.prev:disable()
    historyPanel.next:disable()
  end

  for i = 1, historyCount do
    local date = msg:getU32()
    local positiveBalance = msg:getU8() == 1
    local balance = msg:getU64()
    local message = msg:getString()
    local currency = msg:getU8()

    if not positiveBalance then
      balance = -balance
    end

    table.insert(GameStore.History, { date = date, balance = balance, message = message, currency = currency })
  end

  updateHistoryTable()
end

function parseHistoryNew(msg)
  local date = msg:getU32()
  local positiveBalance = msg:getU8() == 1
  local balance = msg:getU64()
  local message = msg:getString()
  local currency = msg:getU8()

  if not GameStore.History then
    return
  end

  if not positiveBalance then
    balance = -balance
  end

  table.insert(GameStore.History, 1, { date = date, balance = balance, message = message, currency = currency })
  historyTotal = historyTotal + 1

  if historyTotal > historyLimit then
    historyPanel.next:enable()
  end

  updateHistoryTable()
end

function parseProductUpdate(msg)
  local productId = msg:getU16()
  local categoryId = msg:getU8()
  local subCategoryId = msg:getU8()

  local currency = msg:getU8()
  local cost = 0
  local amount = 0
  local bulk = msg:getU8() == 1
  local bulks = 0
  if bulk then
    cost = {}
    amount = {}
    bulks = msg:getU8()
    for j = 1, bulks do
      cost[j] = msg:getU64()
      amount[j] = msg:getU16()
    end
  else
    cost = msg:getU64()
    amount = msg:getU16()
  end

  GameStore.Products[productId].bulk = bulk
  GameStore.Products[productId].cost = cost
  GameStore.Products[productId].amount = amount
  GameStore.Products[productId].currency = currency

  local widget = categoryWidgets.sub[categoryId].panels[subCategoryId].list["product" .. productId]
  setProductPrice(widget, bulk, cost, currency, GameStore.Products[productId].owned)
end

function parseProductOwned(msg)
  local productId = msg:getU16()
  GameStore.Products[productId].owned = msg:getU8() == 1

  if not ownedSort then
    ownedSort = scheduleEvent(
      function()
        local currentTab = window.tabBar:getCurrentTab()
        if currentTab then
          if currentTab.tabPanel.left then
            local categoryId = currentTab.categoryId
            local subCategoryId = currentTab.tabPanel.left.tabBar:getCurrentTab().subCategoryId
            sortProducts(categoryId, subCategoryId)
          end
        end
        ownedSort = nil
      end, 100
    )
  end
end

function parseOwnedProducts(msg)
  local productsSize = msg:getU32()

  for i = 1, productsSize do
    local productId = msg:getU16()
    local owned = msg:getU8() == 1
    if GameStore.Products[productId] then
      GameStore.Products[productId].owned = owned
    end
  end
end

function onCategoryChange(tabBar, tabButton)
  if not tabButton then
    return
  end

  if tabButton.tabPanel == historyPanel then
    if not GameStore.History then
      sendExtended("fetchHistory", 1)
    end
    return
  end

  if not tabButton.categoryId then
    return
  end

  local categoryId = tabButton.categoryId
  local leftPanel = tabButton.tabPanel.left
  local subCategoryId = leftPanel.tabBar:getCurrentTab().subCategoryId

  if not GameStore.Categories[categoryId].products[subCategoryId] then
    sendExtended("fetchProducts", { categoryId = categoryId, subCategoryId = subCategoryId })
  end

  -- sorting
  if isSortingSet(SortTypes.PRICE_LOWER) then
    leftPanel.sort:setCurrentOption("Price Lower")
  elseif isSortingSet(SortTypes.PRICE_HIGHER) then
    leftPanel.sort:setCurrentOption("Price Higher")
  elseif isSortingSet(SortTypes.ALPHABETICAL) then
    leftPanel.sort:setCurrentOption("Alphabetical")
  end

  leftPanel.sale:setChecked(isSortingSet(SortTypes.ON_SALE))

  if leftPanel.owned then
    leftPanel.owned:setChecked(isSortingSet(SortTypes.OWNED))
  end

  leftPanel.currencyPoints:setChecked(isSortingSet(SortTypes.CURRENCY_POINTS))
  leftPanel.currencyGold:setChecked(isSortingSet(SortTypes.CURRENCY_GOLD))
  leftPanel.currencyItem:setChecked(isSortingSet(SortTypes.CURRENCY_ITEM))

  leftPanel.afford:setChecked(isSortingSet(SortTypes.CAN_AFFORD))

  sortProducts(categoryId, subCategoryId)
end

function onSubCategoryChange(tabBar, tabButton)
  if not tabButton then
    return
  end

  local categoryId = tabBar.categoryId
  local subCategoryId = tabButton.subCategoryId

  if not GameStore.Categories[categoryId].products[subCategoryId] then
    sendExtended("fetchProducts", { categoryId = categoryId, subCategoryId = subCategoryId })
  else
    sortProducts(categoryId, subCategoryId)
  end
end

function onSearch(widget, newText, oldText)
  local tabBar = widget:getParent().tabBar
  local categoryId = tabBar.categoryId
  local subCategoryId = tabBar:getCurrentTab().subCategoryId
  local products = GameStore.Categories[categoryId].products[subCategoryId]

  if not products then
    return
  end

  sortProducts(categoryId, subCategoryId)
end

function onSortChange(widget, text, data)
  local tabBar = widget:getParent().tabBar
  local categoryId = tabBar.categoryId
  local subCategoryId = tabBar:getCurrentTab().subCategoryId

  sorting = clearSorting(SortTypes.PRICE_LOWER)
  sorting = clearSorting(SortTypes.PRICE_HIGHER)
  sorting = clearSorting(SortTypes.ALPHABETICAL)

  sorting = setSorting(data)

  sortProducts(categoryId, subCategoryId)
end

function onShowOnSale(widget, checked)
  if checked then
    sorting = setSorting(SortTypes.ON_SALE)
  else
    sorting = clearSorting(SortTypes.ON_SALE)
  end

  local tabBar = widget:getParent().tabBar
  local categoryId = tabBar.categoryId
  local subCategoryId = tabBar:getCurrentTab().subCategoryId
  local products = GameStore.Categories[categoryId].products[subCategoryId]

  if not products then
    return
  end

  sortProducts(categoryId, subCategoryId)
end

function onShowOwned(widget, checked)
  if checked then
    sorting = setSorting(SortTypes.OWNED)
  else
    sorting = clearSorting(SortTypes.OWNED)
  end

  local tabBar = widget:getParent().tabBar
  local categoryId = tabBar.categoryId
  local subCategoryId = tabBar:getCurrentTab().subCategoryId
  local products = GameStore.Categories[categoryId].products[subCategoryId]

  if not products then
    return
  end

  sortProducts(categoryId, subCategoryId)
end

function onCurrencyChange(widget, checked)
  if not checked then
    sorting = clearSorting(widget.sortType)
  else
    sorting = setSorting(widget.sortType)
  end

  local tabBar = widget:getParent().tabBar
  local categoryId = tabBar.categoryId
  local subCategoryId = tabBar:getCurrentTab().subCategoryId

  sortProducts(categoryId, subCategoryId)
end

function onCanAffordChange(widget, checked)
  if not checked then
    sorting = clearSorting(SortTypes.CAN_AFFORD)
  else
    sorting = setSorting(SortTypes.CAN_AFFORD)
  end

  local tabBar = widget:getParent().tabBar
  local categoryId = tabBar.categoryId
  local subCategoryId = tabBar:getCurrentTab().subCategoryId

  sortProducts(categoryId, subCategoryId)
end

function isProductVisible(product, search)
  if isSortingSet(SortTypes.ON_SALE) and not product.sale then
    return false
  end

  if isSortingSet(SortTypes.OWNED) then
    if product.owned then
      return true
    end
  elseif product.owned then
    return false
  end

  if isSortingSet(SortTypes.CAN_AFFORD) then
    local cost = 0
    if product.bulk then
      cost = product.cost[1]
    else
      cost = product.cost
    end

    if product.currency == Currencies.POINTS then
      if GameStore.points < cost then
        return false
      end
    elseif product.currency == Currencies.GOLD then
      if GameStore.gold < cost then
        return false
      end
    elseif product.currency == Currencies.ITEM then
      if GameStore.items < cost then
        return false
      end
    end
  end

  local passed = (not isSortingSet(SortTypes.CURRENCY_POINTS) and not isSortingSet(SortTypes.CURRENCY_GOLD) and not isSortingSet(SortTypes.CURRENCY_ITEM))
  if isSortingSet(SortTypes.CURRENCY_POINTS) and product.currency == Currencies.POINTS then
    passed = true
  end

  if isSortingSet(SortTypes.CURRENCY_GOLD) and product.currency == Currencies.GOLD then
    passed = true
  end

  if isSortingSet(SortTypes.CURRENCY_ITEM) and product.currency == Currencies.ITEM then
    passed = true
  end

  if passed then
    if search:len() >= 3 then
      if product.name:lower():find(search) then
        passed = true
      else
        passed = false
      end
    else
      passed = true
    end
  end

  return passed
end

function sortProducts(categoryId, subCategoryId)
  local products = GameStore.Categories[categoryId].products[subCategoryId]

  if not products then
    return
  end

  if isSortingSet(SortTypes.PRICE_LOWER) then
    table.sort(products, function(a, b)
      local prodA, prodB = GameStore.Products[a], GameStore.Products[b]

      if prodA.bulk then
        if prodB.bulk then
          return prodA.cost[1] < prodB.cost[1]
        end

        return prodA.cost[1] < prodB.cost
      end

      if prodB.bulk then
        if prodA.bulk then
          return prodA.cost[1] < prodB.cost[1]
        end

        return prodA.cost < prodB.cost[1]
      end

      return prodA.cost < prodB.cost
    end)
  elseif isSortingSet(SortTypes.PRICE_HIGHER) then
    table.sort(products, function(a, b)
      local prodA, prodB = GameStore.Products[a], GameStore.Products[b]

      if prodA.bulk then
        if prodB.bulk then
          return prodA.cost[1] > prodB.cost[1]
        end

        return prodA.cost[1] > prodB.cost
      end

      if prodB.bulk then
        if prodA.bulk then
          return prodA.cost[1] > prodB.cost[1]
        end

        return prodA.cost > prodB.cost[1]
      end

      return prodA.cost > prodB.cost
    end)
  elseif isSortingSet(SortTypes.ALPHABETICAL) then
    table.sort(products, function(a, b)
      local prodA, prodB = GameStore.Products[a], GameStore.Products[b]
      return prodA.name < prodB.name
    end)
  end

  local serachInput = categoryWidgets.panels[categoryId].left.search
  local search = serachInput:getText():trim():lower()
  local list = categoryWidgets.sub[categoryId].panels[subCategoryId].list
  local layout = list:getLayout()

  layout:disableUpdates()
  for i = #products, 1, -1 do
    local productId = products[i]
    local productWidget = list["product" .. productId]

    list:moveChildToIndex(productWidget, 1)
  end

  for _, productId in ipairs(products) do
    local productWidget = list["product" .. productId]
    local product = GameStore.Products[productId]
    productWidget:setVisible(isProductVisible(product, search))
  end

  layout:enableUpdates()
  layout:update()

  local atLeastOneVisible = false
  for _, productId in ipairs(products) do
    local productWidget = list["product" .. productId]
    if productWidget:isVisible() then
      atLeastOneVisible = true
      break
    end
  end

  if atLeastOneVisible then
    categoryWidgets.sub[categoryId].panels[subCategoryId].list:setText("")
  else
    categoryWidgets.sub[categoryId].panels[subCategoryId].list:setText("No products here.")
  end
end

function onBundleClicked(widget)
  local bundleId = widget.bundleId

  local bundle = GameStore.Bundles[bundleId]
  if not bundle then
    return
  end

  purchaseWindow.preview.item:hide()
  purchaseWindow.preview.outfit:hide()

  purchaseWindow.preview.image:setImageSource("/images/store/" .. bundle.image)
  purchaseWindow.preview.image:show()

  purchaseWindow.info.name:setText(bundle.name)
  purchaseWindow.description.label:setText(bundle.description)

  purchaseWindow.info.amount.boxes:destroyChildren()
  if amountGroup then
    amountGroup:destroy()
    amountGroup = nil
  end

  purchaseWindow.info.price:setText(comma_value(bundle.cost))
  if bundle.currency == Currencies.POINTS then
    purchaseWindow.info.pointsCurrency:show()
    purchaseWindow.info.goldCurrency:hide()
    purchaseWindow.info.itemCurrency:hide()
  elseif bundle.currency == Currencies.GOLD then
    purchaseWindow.info.pointsCurrency:hide()
    purchaseWindow.info.goldCurrency:show()
    purchaseWindow.info.itemCurrency:hide()
  elseif bundle.currency == Currencies.ITEM then
    purchaseWindow.info.pointsCurrency:hide()
    purchaseWindow.info.goldCurrency:hide()
    purchaseWindow.info.itemCurrency:show()
  end
  purchaseWindow.info.amount:hide()

  purchaseWindow.confirmBtn.onClick = function()
    sendExtended("purchaseBundle", bundleId)
    purchaseWindow:hide()
  end

  purchaseWindow:show()
end

function onProductClicked(widget)
  local productId = widget.productId

  local product = GameStore.Products[productId]
  if not product then
    return
  end

  purchaseWindow.preview.item:hide()
  purchaseWindow.preview.outfit:hide()
  purchaseWindow.preview.image:hide()

  if product.type == ProductTypes.ITEM then
    purchaseWindow.preview.item:setItemId(product.icon)
    purchaseWindow.preview.item:show()
  elseif product.type == ProductTypes.MOUNT then
    purchaseWindow.preview.outfit:setOutfit({ type = product.icon })
    purchaseWindow.preview.outfit:setCenter(true)
    purchaseWindow.preview.outfit:show()
  elseif product.type == ProductTypes.OUTFIT then
    local player = g_game.getLocalPlayer()
    local outfit = player:getOutfit()
    outfit.type = product.icon
    outfit.auxType = 0
    outfit.addons = 3
    purchaseWindow.preview.outfit:setOutfit(outfit)
    purchaseWindow.preview.outfit:setAnimate(true)
    purchaseWindow.preview.outfit:show()
  elseif product.type == ProductTypes.IMAGE then
    purchaseWindow.preview.image:setImageSource("/images/store/" .. product.icon)
    purchaseWindow.preview.image:show()
  elseif product.type == ProductTypes.WINGS then
    local player = g_game.getLocalPlayer()
    local outfit = player:getOutfit()
    outfit.wings = product.icon
    outfit.auxType = 0
    purchaseWindow.preview.outfit:setOutfit(outfit)
    purchaseWindow.preview.outfit:setAnimate(true)
    purchaseWindow.preview.outfit:show()
  elseif product.type == ProductTypes.AURA then
    local player = g_game.getLocalPlayer()
    local outfit = player:getOutfit()
    outfit.aura = product.icon
    outfit.auxType = 0
    purchaseWindow.preview.outfit:setOutfit(outfit)
    purchaseWindow.preview.outfit:setAnimate(true)
    purchaseWindow.preview.outfit:show()
  elseif product.type == ProductTypes.SHADER then
    local player = g_game.getLocalPlayer()
    local outfit = player:getOutfit()
    outfit.shader = product.icon
    outfit.auxType = 0
    purchaseWindow.preview.outfit:setOutfit(outfit)
    purchaseWindow.preview.outfit:setAnimate(true)
    purchaseWindow.preview.outfit:show()
  end

  purchaseWindow.info.name:setText(product.name)
  purchaseWindow.description.label:setText(product.description)

  purchaseWindow.info.amount.boxes:destroyChildren()
  if amountGroup then
    amountGroup:destroy()
    amountGroup = nil
  end

  if product.amount ~= 0 then
    purchaseWindow.info.amount:show()
    if product.bulk then
      amountGroup = UIRadioGroup.create()
      for i = 1, #product.amount do
        local box = g_ui.createWidget("CheckBoxRound", purchaseWindow.info.amount.boxes)
        box:setText("x" .. product.amount[i])
        box.amountId = i
        amountGroup:addWidget(box)
      end
      amountGroup.onSelectionChange = function(group, selected)
        purchaseWindow.info.price:setText(comma_value(product.cost[selected.amountId]))
      end
      amountGroup:selectWidget(amountGroup:getFirstWidget())
    else
      local box = g_ui.createWidget("CheckBoxRound", purchaseWindow.info.amount.boxes)
      box:setText("x" .. product.amount)
      box:setChecked(true)
      purchaseWindow.info.price:setText(comma_value(product.cost))
    end
  else
    purchaseWindow.info.price:setText(comma_value(product.cost))
    purchaseWindow.info.amount:hide()
  end

  setProductCurrency(purchaseWindow.info, product.currency)

  purchaseWindow.confirmBtn.onClick = function()
    sendExtended("purchase",
      { productId = productId, amount = amountGroup and amountGroup:getSelectedWidget().amountId or 1 })
    purchaseWindow:hide()
  end

  purchaseWindow:show()
end

function cancelPurchase()
  purchaseWindow:hide()
end

function confirmAnimation()
  local animationPhase = 0
  local loop = false
  local delay = 120
  local timer = 0
  local duration = 2000
  local stop = false
  periodicalEvent(function()
      local w = (animationPhase % 13) * 108
      successWindow.animation:setImageClip(w .. " 0 108 108")
      animationPhase = animationPhase + 1

      if animationPhase >= 12 then
        loop = true
      end

      if loop then
        if animationPhase > 12 then
          animationPhase = 11
        end
      end

      timer = timer + delay

      if timer >= duration then
        stop = true
        successWindow:hide()
        show()
      end
    end,
    function() return successWindow and not stop end, delay, delay
  )
end

function updateHistoryTable()
  local from = (historyPage - 1) * historyLimit + 1
  local to = math.min(historyTotal, historyLimit * historyPage)

  if to > #GameStore.History then
    to = #GameStore.History
  end

  historyPanel.table.content:destroyChildren()
  for i = from, to do
    local history = GameStore.History[i]
    local widget = g_ui.createWidget("StoreHistoryEntry", historyPanel.table.content)
    widget.date:setText(os.date("%Y-%m-%d %H:%M:%S", history.date))

    local absBalance = math.abs(history.balance)
    local balanceText
    if absBalance > 10 ^ 12 then
      balanceText = string.format("%s%sB", history.balance > 0 and "+" or "-",
        comma_value(math.floor(history.balance / 10 ^ 9)))
    elseif absBalance > 10 ^ 9 then
      balanceText = string.format("%s%sM", history.balance > 0 and "+" or "-",
        comma_value(math.floor(history.balance / 10 ^ 6)))
    else
      balanceText = string.format("%s%s", history.balance > 0 and "+" or "-", comma_value(absBalance))
    end
    widget.balance:setText(balanceText)

    if history.balance > 0 then
      widget.balance:setColor("#519f3a")
    else
      widget.balance:setColor("#b74847")
    end
    widget.message:setText(history.message)

    if history.currency == Currencies.POINTS then
      widget.pointsCurrency:show()
      widget.goldCurrency:hide()
      widget.itemCurrency:hide()
    elseif history.currency == Currencies.GOLD then
      widget.pointsCurrency:hide()
      widget.goldCurrency:show()
      widget.itemCurrency:hide()
    elseif history.currency == Currencies.ITEM then
      widget.pointsCurrency:hide()
      widget.goldCurrency:hide()
      widget.itemCurrency:show()
    end
  end

  local pages = math.ceil(historyTotal / historyLimit)
  if pages == 1 then
    historyPanel.prev:disable()
    historyPanel.next:disable()
  end
end

function prevHistoryPage()
  if historyPage == 1 then
    return
  end

  historyPage = historyPage - 1
  historyPanel.pages:setText(string.format("Page %d / %d", historyPage, math.ceil(historyTotal / historyLimit)))

  if historyPage == 1 then
    historyPanel.prev:disable()
  else
    historyPanel.prev:enable()
  end

  historyPanel.next:enable()

  if #GameStore.History < (historyPage * historyLimit) then
    sendExtended("fetchHistory", historyPage)
  else
    updateHistoryTable()
  end
end

function nextHistoryPage()
  local lastPage = math.ceil(historyTotal / historyLimit)
  if historyPage == lastPage then
    return
  end

  historyPage = historyPage + 1
  historyPanel.pages:setText(string.format("Page %d / %d", historyPage, lastPage))

  if historyPage == lastPage then
    historyPanel.next:disable()
  else
    historyPanel.next:enable()
  end

  historyPanel.prev:enable()

  if #GameStore.History < (historyPage * historyLimit) then
    sendExtended("fetchHistory", historyPage)
  else
    updateHistoryTable()
  end
end

function updateGiftValue()
  giftWindow.amount:setText(comma_value(giftWindow.amountBar:getValue()))
end

function showGift()
  giftWindow.giftable:setText(comma_value(GameStore.points))
  giftWindow.amountBar.onValueChange = updateGiftValue
  giftWindow.amountBar:setMinimum(1)
  giftWindow.amountBar:setMaximum(GameStore.points)
  giftWindow.amountBar:setValue(1)
  giftWindow:show()
end

function hideGift()
  giftWindow:hide()
end

function sendGift()
  local receipient = giftWindow.input:getText():trim()

  if receipient:len() < 3 then
    return
  end

  local amount = giftWindow.amountBar:getValue()
  if amount < 1 or amount > GameStore.points then
    return
  end

  sendExtended("gift", { target = receipient, amount = amount })
end

function createProductWidget(productType, icon, parent, small)
  local player = g_game.getLocalPlayer()
  local outfit = player:getOutfit()

  local widget = nil
  if productType == ProductTypes.ITEM then
    widget = g_ui.createWidget("StoreItemEntry", parent)
    widget.item:setItemId(icon)
  elseif productType == ProductTypes.MOUNT then
    widget = g_ui.createWidget(small and "StoreCreatureSmallEntry" or "StoreCreatureEntry", parent)
    widget.outfit:setOutfit({ type = icon })
    widget.outfit:setCenter(true)
  elseif productType == ProductTypes.OUTFIT then
    widget = g_ui.createWidget(small and "StoreCreatureSmallEntry" or "StoreCreatureEntry", parent)
    outfit.auxType = 0
    outfit.addons = 3
    outfit.type = icon
    outfit.aura = 0
    outfit.wings = 0
    outfit.shader = "outfit_default"
    widget.outfit:setOutfit(outfit)
    widget.outfit:setCenter(true)
  elseif productType == ProductTypes.IMAGE then
    widget = g_ui.createWidget("StoreImageEntry", parent)
    widget.image:setImageSource("/images/store/" .. icon)
  elseif productType == ProductTypes.WINGS then
    widget = g_ui.createWidget(small and "StoreCreatureSmallEntry" or "StoreCreatureEntry", parent)
    outfit.auxType = 0
    outfit.type = icon
    outfit.aura = 0
    outfit.wings = 0
    outfit.shader = "outfit_default"
    widget.outfit:setOutfit(outfit)
    widget.outfit:setAnimate(true)
  elseif productType == ProductTypes.AURA then
    widget = g_ui.createWidget(small and "StoreCreatureSmallEntry" or "StoreCreatureEntry", parent)
    outfit.auxType = 0
    outfit.type = icon
    outfit.aura = 0
    outfit.wings = 0
    outfit.shader = "outfit_default"
    widget.outfit:setOutfit(outfit)
    widget.outfit:setAnimate(true)
  elseif productType == ProductTypes.SHADER then
    widget = g_ui.createWidget(small and "StoreCreatureSmallEntry" or "StoreCreatureEntry", parent)
    outfit.auxType = 0
    outfit.shader = icon
    outfit.wings = 0
    outfit.aura = 0
    widget.outfit:setOutfit(outfit)
    widget.outfit:setCenter(true)
  end

  return widget
end

function setProductCurrency(widget, currency)
  if currency == Currencies.POINTS then
    widget.pointsCurrency:show()
    widget.goldCurrency:hide()
    widget.itemCurrency:hide()
  elseif currency == Currencies.GOLD then
    widget.goldCurrency:show()
    widget.pointsCurrency:hide()
    widget.itemCurrency:hide()
  elseif currency == Currencies.ITEM then
    widget.itemCurrency:show()
    widget.goldCurrency:hide()
    widget.pointsCurrency:hide()
  end
end

function setProductPrice(widget, bulk, cost, currency, owned)
  setProductCurrency(widget, currency)

  if owned then
    widget.price:setText("Owned")
    return
  end

  local price = bulk and cost[1] or cost
  local text
  if price > 10 ^ 12 then
    text = comma_value(math.floor(price / 10 ^ 9)) .. "B"
  elseif price > 10 ^ 9 then
    text = comma_value(math.floor(price / 10 ^ 6)) .. "M"
  else
    text = comma_value(price)
  end

  widget.price:setText(text)
end

function getCoins()
--g_platform.openUrl(DONATION_URL) -- AQUI CASO QUEIRA DEIXAR O LINK PRO DONATE
  modules.game_payment.show()
end

function sendExtended(action, data)
  local protocolGame = g_game.getProtocolGame()
  if protocolGame then
    protocolGame:sendExtendedOpcode(EXTENDED_OPCODE, json.encode({ action = action, data = data }))
  end
end

function toggle()
  if not window then
    return
  end

  if windowButton:isOn() then
    hide()
  else
    show()
  end
end

function show()
  if not window then
    return
  end

  if not GameStore.loaded then
    sendExtended("fetchBase", GameStore.Products ~= nil)
  else
    sendExtended("fetchCurrency")
  end

  window:show()
  window:raise()
  windowButton:setOn(true)
end

function hide()
  if not window then
    return
  end

  window:hide()
  windowButton:setOn(false)
end

function setSorting(flag)
  return bit.bor(sorting, bit.lshift(1, flag))
end

function clearSorting(flag)
  return bit.band(sorting, bit.bnot(bit.lshift(1, flag)))
end

function isSortingSet(flag)
  return bit.band(sorting, bit.lshift(1, flag)) ~= 0
end
