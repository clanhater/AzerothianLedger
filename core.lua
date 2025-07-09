-- core.lua - Versión completa de la Fase 1

-- 1. INICIALIZACIÓN DE LA BASE DE DATOS
------------------------------------------
AzerothianLedgerDB = {} -- Esta variable será guardada por WoW

local dbFrame = CreateFrame("Frame")
dbFrame:RegisterEvent("PLAYER_LOGIN")
dbFrame:SetScript("OnEvent", function(self, event)
    if AzerothianLedgerDB == nil then AzerothianLedgerDB = {} end
    if AzerothianLedgerDB.recipes == nil then AzerothianLedgerDB.recipes = {} end
    if AzerothianLedgerDB.materialPrices == nil then AzerothianLedgerDB.materialPrices = {} end
    print("Base de datos de Azerothian Ledger inicializada.")
    self:UnregisterEvent("PLAYER_LOGIN")
end)

-- 2. REFERENCIAS Y FUNCIONES DE LA UI
---------------------------------------
local mainFrame = AL_MainFrame
local addRecipeButton = AL_AddRecipeButton

-- Función para mostrar/ocultar la ventana
function ToggleMainFrame()
    if mainFrame:IsShown() then
        HideUIPanel(mainFrame)
    else
        ShowUIPanel(mainFrame)
    end
end

-- Comando de chat
SLASH_AZEROTHIANLEDGER1 = "/al"
SLASH_AZEROTHIANLEDGER2 = "/ledger"
SlashCmdList["AZEROTHIANLEDGER"] = ToggleMainFrame

-- Hacer la ventana movible
mainFrame:SetMovable(true)
mainFrame:EnableMouse(true)
mainFrame:RegisterForDrag("LeftButton")
mainFrame:SetScript("OnDragStart", mainFrame.StartMoving)
mainFrame:SetScript("OnDragStop", mainFrame.StopMovingOrSizing)

-- 3. LÓGICA DE RECETAS
-----------------------

-- Esta función se llamará para refrescar la lista de recetas en la ventana
function AL_UpdateRecipeList()
    -- (Esto lo implementaremos en una fase posterior para mostrar la lista. Por ahora, es un placeholder.)
    print("Refrescando lista de recetas (función placeholder).")
end

-- Función para guardar una nueva receta
function AL_SaveNewRecipe(recipeName, materials)
    if not recipeName or recipeName == "" then
        print("Error: El nombre de la receta no puede estar vacío.")
        return
    end
    if not materials or #materials == 0 then
        print("Error: La receta debe tener al menos un material.")
        return
    end

    -- Usamos el nombre de la receta como clave única
    AzerothianLedgerDB.recipes[recipeName] = materials
    print("|cffffe569Receta guardada:|r " .. recipeName)
    
    -- Refrescamos la lista para que aparezca la nueva receta
    AL_UpdateRecipeList()
end

-- Cuando se hace clic en el botón "Añadir Receta"
addRecipeButton:SetScript("OnClick", function()
    -- Usamos un diálogo emergente de WoW para pedir los datos
    StaticPopupDialogs["AL_ADD_RECIPE"] = {
        text = "Añadir Nueva Receta",
        button1 = "Guardar",
        button2 = "Cancelar",
        hasEditBox = true,
        maxLetters = 50,
        OnShow = function(self)
            self.editBox:SetLabel("Nombre del Objeto:")
            self.editBox:SetText("")
        end,
        OnAccept = function(self)
            local recipeName = self.editBox:GetText()
            -- Por ahora, como no tenemos un formulario para materiales,
            -- vamos a añadir una receta de prueba con materiales fijos.
            -- Esto nos permite probar la lógica de guardado.
            local sampleMaterials = {
                { name = "Barra de cobalto", quantity = 12 },
                { name = "Tierra cristalizada", quantity = 1 }
            }
            AL_SaveNewRecipe(recipeName, sampleMaterials)
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
    }
    -- Mostramos el diálogo
    StaticPopup_Show("AL_ADD_RECIPE")
end)


-- 4. MENSAJE DE BIENVENIDA
---------------------------
local welcomeFrame = CreateFrame("Frame")
welcomeFrame:RegisterEvent("ADDON_LOADED")
welcomeFrame:SetScript("OnEvent", function(self, event, addonName)
    if addonName == "AzerothianLedger" then
        DEFAULT_CHAT_FRAME:AddMessage("|cffffe569Azerothian Ledger:|r Cargado. Escribe |cffffff00/al|r o |cffffff00/ledger|r para abrir/cerrar la ventana.")
        self:UnregisterEvent("ADDON_LOADED")
    end
end)