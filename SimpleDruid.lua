-------------------------------------------------
-- Constants & Configuration
-------------------------------------------------
local VERSION = "1.3"
local DEFAULT_FONT = "Fonts\\FRIZQT__.TTF"

local textures = {
    { key = "Default", name = "Default", path = "Interface\\TARGETINGFRAME\\UI-StatusBar" },
    { key = "Raid",    name = "Raid",    path = "Interface\\RaidFrame\\Raid-Bar-Hp-Fill" },
    { key = "Flat",    name = "Flat",    path = "Interface\\BUTTONS\\WHITE8X8" },
}

local DEFAULT_TEXTURE = textures[1].path

-------------------------------------------------
-- Saved Variables & Defaults
-------------------------------------------------
SimpleDruid_Config = SimpleDruid_Config or {}
local function InitSettings()
    local defaults = {
        locked = false,
        scale = 1.0,
        width = 200,
        height = 20,
        fontSize = 12,
        texture = DEFAULT_TEXTURE,
        point = "CENTER",
        posX = 0,
        posY = -200,
        barColor = { r = 0, g = 0.8, b = 0, a = 1 },
        useGradient = false,
        showMana = true,
        showAstral = true,
    }
    for k, v in pairs(defaults) do
        if SimpleDruid_Config[k] == nil then SimpleDruid_Config[k] = v end
    end
end

-------------------------------------------------
-- Frame Creation Helper
-------------------------------------------------
local function CreatePowerBar(name, parent, color)
    local pb = CreateFrame("StatusBar", name, parent)
    pb:SetStatusBarTexture(DEFAULT_TEXTURE)
    pb:SetStatusBarColor(color.r, color.g, color.b)
    
    local bg = pb:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0, 0, 0, 0.4)
    
    local text = pb:CreateFontString(nil, "OVERLAY")
    text:SetPoint("CENTER")
    pb.text = text
    
    return pb
end

-------------------------------------------------
-- Main Frame Setup
-------------------------------------------------
local main = CreateFrame("Frame", "SimpleDruid_MainFrame", UIParent)
main:SetSize(200, 100)
main:SetMovable(true)
main:EnableMouse(true)
main:RegisterForDrag("LeftButton")
main:SetClampedToScreen(true)

local health = CreatePowerBar("SimpleDruid_HealthBar", main, { r = 0, g = 0.8, b = 0 })
health:SetPoint("TOP", main, "TOP", 0, 0)

local mana = CreatePowerBar("SimpleDruid_ManaBar", main, { r = 0, g = 0.5, b = 1 })
mana:SetPoint("TOP", health, "BOTTOM", 0, -4)

local astral = CreatePowerBar("SimpleDruid_AstralBar", main, { r = 0.3, g = 0.7, b = 1 })
astral:SetPoint("TOP", mana, "BOTTOM", 0, -4)

-------------------------------------------------
-- Drag & Save Position
-------------------------------------------------
main:SetScript("OnDragStart", function(self)
    if not SimpleDruid_Config.locked then self:StartMoving() end
end)

main:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local point, _, _, x, y = self:GetPoint()
    SimpleDruid_Config.point = point
    SimpleDruid_Config.posX = x
    SimpleDruid_Config.posY = y
end)

-------------------------------------------------
-- Apply All Settings (Visibility logic here)
-------------------------------------------------
local function ApplySettings()
    main:SetScale(SimpleDruid_Config.scale)
    main:ClearAllPoints()
    main:SetPoint(SimpleDruid_Config.point, UIParent, SimpleDruid_Config.point, SimpleDruid_Config.posX, SimpleDruid_Config.posY)

    for _, bar in ipairs({health, mana, astral}) do
        bar:SetSize(SimpleDruid_Config.width, SimpleDruid_Config.height)
        bar:SetStatusBarTexture(SimpleDruid_Config.texture)
        bar.text:SetFont(DEFAULT_FONT, SimpleDruid_Config.fontSize, "OUTLINE")
    end

    if not SimpleDruid_Config.useGradient then
        local c = SimpleDruid_Config.barColor
        health:SetStatusBarColor(c.r, c.g, c.b)
    end

    mana:SetShown(SimpleDruid_Config.showMana)
    
    -- Check spec: 1 is Balance
    local spec = GetSpecialization()
    if SimpleDruid_Config.showAstral and spec == 1 then
        astral:Show()
    else
        astral:Hide()
    end
    
    main:Show()
end

-------------------------------------------------
-- Resource Updates
-------------------------------------------------
local function UpdateResources()
    local hp, maxHp = UnitHealth("player"), UnitHealthMax("player")
    health:SetMinMaxValues(0, maxHp)
    health:SetValue(hp)
    
    if SimpleDruid_Config.useGradient then
        local pct = (maxHp > 0) and (hp/maxHp) or 1
        local r, g = (pct > 0.5 and (1-pct)*2 or 1), (pct > 0.5 and 1 or pct*2)
        health:SetStatusBarColor(r, g, 0)
    end
    health.text:SetText(string.format("%d / %d", hp, maxHp))

    if SimpleDruid_Config.showMana then
        local mp, maxMp = UnitPower("player", Enum.PowerType.Mana), UnitPowerMax("player", Enum.PowerType.Mana)
        mana:SetMinMaxValues(0, maxMp)
        mana:SetValue(mp)
        mana.text:SetText(string.format("Mana: %d%%", (maxMp > 0 and (mp/maxMp * 100) or 0)))
    end

    if astral:IsShown() then
        local ap, maxAp = UnitPower("player", Enum.PowerType.LunarPower), UnitPowerMax("player", Enum.PowerType.LunarPower)
        astral:SetMinMaxValues(0, maxAp)
        astral:SetValue(ap)
        astral.text:SetText(string.format("Astral: %d", ap))
    end
end

-------------------------------------------------
-- Settings Panel
-------------------------------------------------
local function RegisterSettings()
    local category = Settings.RegisterVerticalLayoutCategory("SimpleDruid")

    local function AddToggle(var, name)
        local set = Settings.RegisterAddOnSetting(category, var, var, SimpleDruid_Config, "boolean", name, SimpleDruid_Config[var])
        set:SetValueChangedCallback(ApplySettings)
        Settings.CreateCheckbox(category, set)
    end

    AddToggle("locked", "Lock Position")
    AddToggle("useGradient", "Health Gradient")
    AddToggle("showMana", "Show Mana Bar")
    AddToggle("showAstral", "Show Astral Bar")

    local colorSet = Settings.RegisterAddOnSetting(category, "barColor", "barColor", SimpleDruid_Config, "color", "Health Color", CreateColor(0, 0.8, 0, 1))
    colorSet:SetValueChangedCallback(ApplySettings)
    if Settings.CreateColorPicker then Settings.CreateColorPicker(category, colorSet) end

    local function AddSlider(name, var, min, max, step, isDec)
        local setting = Settings.RegisterAddOnSetting(category, var, var, SimpleDruid_Config, "number", name, SimpleDruid_Config[var])
        setting:SetValueChangedCallback(ApplySettings)
        local opt = Settings.CreateSliderOptions(min, max, step)
        opt:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, function(v) 
            return isDec and string.format("%.2f", v) or math.floor(v) 
        end)
        Settings.CreateSlider(category, setting, opt)
    end

    AddSlider("Scale", "scale", 0.5, 2.0, 0.05, true)
    AddSlider("Width", "width", 100, 400, 5, false)
    AddSlider("Height", "height", 10, 50, 1, false)
    AddSlider("Font Size", "fontSize", 8, 30, 1, false)

    local textureSet = Settings.RegisterAddOnSetting(category, "texture", "texture", SimpleDruid_Config, "string", "Bar Texture", DEFAULT_TEXTURE)
    textureSet:SetValueChangedCallback(ApplySettings)
    Settings.CreateDropdown(category, textureSet, function()
        local container = Settings.CreateControlTextContainer()
        for _, tex in ipairs(textures) do container:Add(tex.path, tex.name) end
        return container:GetData()
    end)

    Settings.RegisterAddOnCategory(category)
end

-------------------------------------------------
-- Initialization & Commands
-------------------------------------------------
SLASH_SIMPLEDRUID1 = "/sd"
SlashCmdList["SIMPLEDRUID"] = function(msg)
    if msg == "reset" then
        SimpleDruid_Config.point = "CENTER"
        SimpleDruid_Config.posX = 0
        SimpleDruid_Config.posY = -200
        ApplySettings()
        print("|cFF00FF00SimpleDruid: Position Reset.|r")
    else
        Settings.OpenToCategory("SimpleDruid")
    end
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_LOGIN" then
        local _, class = UnitClass("player")
        if class ~= "DRUID" then return end

        InitSettings()
        ApplySettings()
        RegisterSettings()
        
        self:RegisterUnitEvent("UNIT_HEALTH", "player")
        self:RegisterUnitEvent("UNIT_MAXHEALTH", "player")
        self:RegisterUnitEvent("UNIT_POWER_FREQUENT", "player")
        self:RegisterUnitEvent("UNIT_MAXPOWER", "player")
        self:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
        
        UpdateResources()
        print("|cFFFFD100SimpleDruid v" .. VERSION .. " loaded.|r Type |cFF00FF00/sd|r for options and |cFF00FF00/sd reset|r to preform a addon reset.")
    
    elseif event == "PLAYER_SPECIALIZATION_CHANGED" then
        -- This forces the Astral bar to show/hide immediately when switching specs
        ApplySettings()
        UpdateResources()
    else
        UpdateResources()
    end
end)
