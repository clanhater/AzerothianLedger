-- core.lua - Versión Completa tras Fase 3

-- 1. INICIALIZACIÓN DE LA BASE DE DATOS
------------------------------------------
AzerothianLedgerDB = {}

local dbFrame = CreateFrame("Frame")
dbFrame:RegisterEvent("PLAYER_LOGIN")
dbFrame:SetScript("OnEvent", function(self, event)
    if AzerothianLedgerDB == nil then AzerothianLedgerDB = {} end
    if AzerothianLedgerDB.recipes == nil then AzerothianLedgerDB.recipes = {} end
    if AzerothianLedgerDB.materialCosts == nil then AzerothianLedgerDB.materialCosts = {} end
    if AzerothianLedgerDB.salesHistory == nil then AzerothianLedgerDB.salesHistory = {} end
    
    print("Base de datos de Azerothian Ledger inicializada.")
    self:UnregisterEvent("PLAYER_LOGIN")
end)

-- 2. REFERENCIAS A LA UI Y FUNCIONES BÁSICAS
-----------------------------------------------
local mainFrame = AL_MainFrame
local addRecipeButton = AL_AddRecipeButton
local addPurchaseButton = AL_AddPurchaseButton
local costDetailsText = AL_CostDetailsText
local farmingTimer = AL_FarmingTimerFrame
local salesHistoryFrame = AL_SalesHistoryFrame
local salesHistoryButton = AL_SalesHistoryButton

function AL_ToggleMainFrame()
    if mainFrame:IsShown() then HideUIPanel(mainFrame) else ShowUIPanel(mainFrame) end
end
SLASH_AZEROTHIANLEDGER1 = "/al"; SlashCmdList["AZEROTHIANLEDGER"] = AL_ToggleMainFrame
SLASH_ALFARM1 = "/alfarm"; SlashCmdList["ALFARM"] = function() if farmingTimer:IsShown() then farmingTimer:Hide() else farmingTimer:Show() end end

mainFrame:SetMovable(true); mainFrame:EnableMouse(true); mainFrame:RegisterForDrag("LeftButton")
mainFrame:SetScript("OnDragStart", mainFrame.StartMoving); mainFrame:SetScript("OnDragStop", mainFrame.StopMovingOrSizing)

salesHistoryButton:SetScript("OnClick", function() salesHistoryFrame:Show() end)
salesHistoryFrame:SetMovable(true); salesHistoryFrame:EnableMouse(true); salesHistoryFrame:RegisterForDrag("LeftButton")
salesHistoryFrame:SetScript("OnDragStart", salesHistoryFrame.StartMoving); salesHistoryFrame:SetScript("OnDragStop", salesHistoryFrame.StopMovingOrSizing)
salesHistoryFrame:SetScript("OnShow", function() AL_UpdateSalesHistory() end)
AL_SalesHistoryScrollFrame:SetScript("OnVerticalScroll", function(self, offset) FauxScrollFrame_OnVerticalScroll(self, offset, 20, AL_UpdateSalesHistory) end)

-- 3. LÓGICA DE VISUALIZACIÓN Y CÁLCULO
-------------------------------------------
function AL_CalculateRecipeCost(recipeName)
    local recipe = AzerothianLedgerDB.recipes[recipeName]
    if not recipe then return 0 end
    local totalCost = 0
    for _, material in ipairs(recipe) do
        local materialData = AzerothianLedgerDB.materialCosts[material.name]
        if materialData and materialData.totalQuantity > 0 then
            totalCost = totalCost + (material.quantity * (materialData.totalCost / materialData.totalQuantity))
        end
    end
    return totalCost
end

function AL_DisplayRecipeCost(recipeName)
    local recipe = AzerothianLedgerDB.recipes[recipeName]
    if not recipe then return end
    local costText = "|cffffd100"..recipeName.."|r\n\n"
    for _, material in ipairs(recipe) do
        local matName = material.name
        local matQty = material.quantity
        local materialData = AzerothianLedgerDB.materialCosts[matName]
        local pricePerUnit = 0
        local priceSource = "|cff808080(Sin datos)|r"
        if materialData and materialData.totalQuantity and materialData.totalQuantity > 0 then
            pricePerUnit = materialData.totalCost / materialData.totalQuantity
            priceSource = "|cff00ff00(Compra)|r"
        end
        local lineCost = matQty * pricePerUnit
        local g, s, c = floor(lineCost / 10000), floor(mod(lineCost, 10000) / 100), mod(lineCost, 100)
        costText = costText .. string.format("%d x %s: %dg %ds %dc %s\n", matQty, matName, g, s, c, priceSource)
    end
    local totalCost = AL_CalculateRecipeCost(recipeName)
    local g, s, c = floor(totalCost / 10000), floor(mod(totalCost, 10000) / 100), mod(totalCost, 100)
    costText = costText .. "\n|cffffff00Coste Total: " .. string.format("%dg %ds %dc", g, s, c) .. "|r"
    costDetailsText:SetText(costText)
end

function AL_UpdateRecipeList()
    local recipeNames = {}
    for name, _ in pairs(AzerothianLedgerDB.recipes) do table.insert(recipeNames, name) end
    table.sort(recipeNames)
    FauxScrollFrame_Update(AL_RecipeListScrollFrame, #recipeNames, 20, 20)
    for i = 1, 20 do
        local index = i + FauxScrollFrame_GetOffset(AL_RecipeListScrollFrame)
        local button = _G["AL_RecipeListScrollFrameButton"..i]
        if not button then
            button = CreateFrame("Button", "AL_RecipeListScrollFrameButton"..i, AL_RecipeListScrollFrame.ScrollChild, "AL_RecipeListLineTemplate")
            button:SetPoint("TOPLEFT", 0, -(i - 1) * 20)
        end
        if recipeNames[index] then
            local recipeName = recipeNames[index]
            _G[button:GetName().."Text"]:SetText(recipeName)
            button:SetScript("OnMouseUp", function(self, mouseButton)
                if mouseButton == "LeftButton" then
                    AL_DisplayRecipeCost(recipeName)
                elseif mouseButton == "RightButton" then
                    StaticPopupDialogs["AL_REGISTER_SALE"] = { text = "Registrar venta de: |cffffd100" .. recipeName .. "|r", button1 = "Guardar", button2 = "Cancelar", hasEditBox = true,
                        OnShow = function(self) self.editBox:SetLabel("Precio de Venta (en cobre):") end,
                        OnAccept = function(self)
                            local salePrice = tonumber(self.editBox:GetText())
                            if salePrice and salePrice > 0 then
                                StaticPopupDialogs["AL_SALE_CUSTOMER"] = { text = "Nombre del Cliente (Opcional)", button1 = "Aceptar", button2 = "Saltar", hasEditBox = true,
                                    OnAccept = function(self_cust) AL_RegisterSale(recipeName, salePrice, self_cust.editBox:GetText()) end,
                                    OnCancel = function() AL_RegisterSale(recipeName, salePrice, nil) end,
                                    timeout = 0, whileDead = true, hideOnEscape = true,
                                }
                                StaticPopup_Show("AL_SALE_CUSTOMER")
                            else
                                print("|cffff0000Error:|r El precio de venta debe ser un número válido.")
                            end
                        end,
                        timeout = 0, whileDead = true, hideOnEscape = true,
                    }
                    StaticPopup_Show("AL_REGISTER_SALE")
                end
            end)
            button:Show()
        else
            button:Hide()
        end
    end
end
AL_RecipeListScrollFrame:SetScript("OnVerticalScroll", function(self, offset) FauxScrollFrame_OnVerticalScroll(self, offset, 20, AL_UpdateRecipeList) end)
mainFrame:SetScript("OnShow", AL_UpdateRecipeList)

function AL_UpdateSalesHistory()
    local history = AzerothianLedgerDB.salesHistory
    table.sort(history, function(a, b) return a.date > b.date end)
    FauxScrollFrame_Update(AL_SalesHistoryScrollFrame, #history, 20, 20)
    for i = 1, 20 do
        local index = i + FauxScrollFrame_GetOffset(AL_SalesHistoryScrollFrame)
        local lineFrame = _G["AL_SalesHistoryLine"..i]
        if not lineFrame then
            lineFrame = CreateFrame("Frame", "AL_SalesHistoryLine"..i, AL_SalesHistoryScrollFrame.ScrollChild)
            lineFrame:SetSize(540, 20); lineFrame:SetPoint("TOPLEFT", 0, -(i - 1) * 20)
            lineFrame.name = lineFrame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall"); lineFrame.name:SetPoint("LEFT", 5, 0)
            lineFrame.customer = lineFrame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall"); lineFrame.customer:SetPoint("LEFT", 180, 0)
            lineFrame.price = lineFrame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall"); lineFrame.price:SetPoint("LEFT", 280, 0)
            lineFrame.cost = lineFrame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall"); lineFrame.cost:SetPoint("LEFT", 380, 0)
            lineFrame.profit = lineFrame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall"); lineFrame.profit:SetPoint("LEFT", 480, 0)
        end
        local record = history[index]
        if record then
            local function formatMoney(amount)
                local color = amount >= 0 and "|cff00ff00" or "|cffff0000"
                amount = abs(amount)
                local g, s, c = floor(amount / 10000), floor(mod(amount, 10000) / 100), mod(amount, 100)
                return string.format("%s%dg %ds %dc|r", color, g, s, c)
            end
            lineFrame.name:SetText(record.name); lineFrame.customer:SetText(record.customer)
            lineFrame.price:SetText(formatMoney(record.price)); lineFrame.cost:SetText(formatMoney(record.cost)); lineFrame.profit:SetText(formatMoney(record.profit))
            lineFrame:Show()
        else
            lineFrame:Hide()
        end
    end
end

-- 4. LÓGICA DE ENTRADA DE DATOS
----------------------------------
function AL_RegisterSale(recipeName, salePrice, customerName)
    local cost = AL_CalculateRecipeCost(recipeName)
    local profit = salePrice - cost
    local saleRecord = { name = recipeName, price = salePrice, cost = cost, profit = profit, customer = customerName or "N/A", date = date("%Y-%m-%d %H:%M"), }
    table.insert(AzerothianLedgerDB.salesHistory, saleRecord)
    local g, s, c = floor(profit / 10000), floor(mod(profit, 10000) / 100), mod(profit, 100)
    print(string.format("|cffffe569Venta Registrada:|r %s. Ganancia: |cffffff00%dg %ds %dc|r", recipeName, g, s, c))
end

function AL_SaveNewRecipe(recipeName, materials)
    recipeName = recipeName:match("^%s*(.-)%s*$")
    if not recipeName or recipeName == "" then print("|cffff0000Error:|r El nombre de la receta no puede estar vacío.") return end
    if not materials or #materials == 0 then print("|cffff0000Error:|r La receta debe tener al menos un material.") return end
    AzerothianLedgerDB.recipes[recipeName] = materials
    print("|cffffe569Receta guardada:|r " .. recipeName)
    AL_UpdateRecipeList()
end

addRecipeButton:SetScript("OnClick", function()
    StaticPopupDialogs["AL_ADD_RECIPE_V2"] = { text = "Añadir Nueva Receta", button1 = "Guardar", button2 = "Cancelar", hasEditBox = true, maxLetters = 50,
        OnShow = function(self) self.editBox:SetLabel("Nombre del Objeto:") self.editBox:SetText("") end,
        OnAccept = function(self)
            local recipeName = self.editBox:GetText()
            StaticPopupDialogs["AL_ADD_MATERIALS"] = { text = "Introduce los materiales para: " .. recipeName, button1 = "Aceptar", button2 = "Cancelar", hasEditBox = true, maxLetters = 200,
                OnShow = function(s) s.editBox:SetLabel("Formato: Material1,Cant;Material2,Cant") end,
                OnAccept = function(self_mats)
                    local materialsText = self_mats.editBox:GetText()
                    local materialsTable = {}
                    for mat_str in string.gmatch(materialsText, "([^;]+)") do
                        local name, qty = mat_str:match("([^,]+),%s*(%d+)")
                        if name and qty then table.insert(materialsTable, { name = name:match("^%s*(.-)%s*$"), quantity = tonumber(qty) }) end
                    end
                    AL_SaveNewRecipe(recipeName, materialsTable)
                end,
                timeout = 0, whileDead = true, hideOnEscape = true,
            }
            StaticPopup_Show("AL_ADD_MATERIALS")
        end,
        timeout = 0, whileDead = true, hideOnEscape = true,
    }
    StaticPopup_Show("AL_ADD_RECIPE_V2")
end)

addPurchaseButton:SetScript("OnClick", function()
    StaticPopupDialogs["AL_ADD_PURCHASE"] = { text = "Registrar Compra", button1 = "Guardar", button2 = "Cancelar", hasEditBox = true,
        OnShow = function(self) self.editBox:SetLabel("Formato: Nombre Material, Cantidad, Precio Total (en cobre)") end,
        OnAccept = function(self)
            local inputText = self.editBox:GetText()
            local matName, qty, totalCost = inputText:match("([^,]+),%s*(%d+),%s*(%d+)")
            if matName and qty and totalCost then
                matName = matName:match("^%s*(.-)%s*$"); qty = tonumber(qty); totalCost = tonumber(totalCost)
                if not AzerothianLedgerDB.materialCosts[matName] then AzerothianLedgerDB.materialCosts[matName] = { totalQuantity = 0, totalCost = 0 } end
                local data = AzerothianLedgerDB.materialCosts[matName]
                data.totalQuantity = data.totalQuantity + qty; data.totalCost = data.totalCost + totalCost
                print(string.format("Compra registrada: %d x %s por %d de cobre.", qty, matName, totalCost))
            else
                print("|cffff0000Error:|r Formato incorrecto. Usa: Nombre, Cantidad, PrecioTotalEnCobre")
            end
        end,
        timeout = 0, whileDead = true, hideOnEscape = true,
    }
    StaticPopup_Show("AL_ADD_PURCHASE")
end)

-- 5. LÓGICA DEL CRONÓMETRO DE FARMEO
-----------------------------------------
local farmStartTime = 0; local isFarming = false
function AL_FarmingTimer_OnUpdate(self, elapsed) if isFarming then local diff = GetTime() - farmStartTime; local h = floor(diff / 3600); local m = floor(mod(diff, 3600) / 60); local s = floor(mod(diff, 60)); AL_FarmingTimerFrameText:SetText(string.format("%02d:%02d:%02d", h, m, s)) end end
farmingTimer:SetScript("OnUpdate", AL_FarmingTimer_OnUpdate)
farmingTimer:SetMovable(true); farmingTimer:EnableMouse(true); farmingTimer:RegisterForDrag("LeftButton"); farmingTimer:SetScript("OnDragStart", farmingTimer.StartMoving); farmingTimer:SetScript("OnDragStop", farmingTimer.StopMovingOrSizing)
AL_FarmingTimerFrameStartStopButton:SetScript("OnClick", function(self) if isFarming then isFarming = false; self:SetText("Iniciar"); local duration = GetTime() - farmStartTime; print("Sesión de farmeo terminada. Duración: " .. floor(duration/60) .. " minutos.") else isFarming = true; farmStartTime = GetTime(); self:SetText("Detener") end end)
AL_FarmingTimerFrameResetButton:SetScript("OnClick", function() isFarming = false; farmStartTime = 0; AL_FarmingTimerFrameText:SetText("00:00:00"); AL_FarmingTimerFrameStartStopButton:SetText("Iniciar") end)

-- 6. MENSAJE DE BIENVENIDA
---------------------------
local welcomeFrame = CreateFrame("Frame"); welcomeFrame:RegisterEvent("ADDON_LOADED")
welcomeFrame:SetScript("OnEvent", function(self, event, addonName)
    if addonName == "AzerothianLedger" then
        DEFAULT_CHAT_FRAME:AddMessage("|cffffe569Azerothian Ledger:|r Cargado. Usa |cffffff00/al|r para la ventana y |cffffff00/alfarm|r para el cronómetro.")
        self:UnregisterEvent("ADDON_LOADED")
    end
end)