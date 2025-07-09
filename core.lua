-- Creamos un "frame" o marco invisible. Es una buena práctica tener un objeto principal para nuestro addon.
local addonFrame = CreateFrame("Frame", "AzerothianLedgerFrame")

-- Registramos un evento. Queremos que nuestro código se ejecute cuando el addon se haya cargado.
addonFrame:RegisterEvent("ADDON_LOADED")

-- Creamos una función que se ejecutará cuando el evento ocurra.
local function onEvent(self, event, addonName)
  -- Nos aseguramos de que el addon que se ha cargado es el nuestro, y no otro.
  if addonName == "AzerothianLedger" then
    -- Imprimimos nuestro mensaje de bienvenida en la ventana de chat por defecto.
    -- |cff... es un código de color (amarillo), y |r lo resetea al color normal.
    DEFAULT_CHAT_FRAME:AddMessage("|cffffe569Azerothian Ledger:|r Addon cargado correctamente. ¡A hacer oro!")
    
    -- Una vez que el mensaje se ha mostrado, ya no necesitamos escuchar este evento.
    -- Esto es una buena práctica para no malgastar recursos.
    self:UnregisterEvent("ADDON_LOADED")
  end
end

-- Le decimos a nuestro frame que use la función "onEvent" para manejar los eventos que registre.
addonFrame:SetScript("OnEvent", onEvent)