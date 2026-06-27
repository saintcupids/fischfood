local Players      = game:GetService("Players")
local UIS          = game:GetService("UserInputService")
local RS           = game:GetService("RunService")
local HttpService  = game:GetService("HttpService")

local function getLP()        return Players.LocalPlayer end
local function getCharacter() local lp = getLP(); return lp and lp.Character end
local function getHRP()       local c = getCharacter(); return c and c:FindFirstChild("HumanoidRootPart") end

local hasUnsafe = type(memory_read) == "function"
if not hasUnsafe then
    notify("Enable Unsafe LuaU in Matcha settings — memory reads required.", "ZeroDeath fisch", 6)
end

local function execName()
    local ok, n = pcall(identifyexecutor)
    return ok and n or "?"
end

local RP   = {}
local TUNE = {}
local TP   = {}

RP.trackerLabels = { "Predict", "Spam", "Hybrid" }
RP.trackerValues = { "predict", "spam", "hybrid" }

local OFFSETS = {

    FakeDataModelPointer       = 126874152,
    FakeDataModelToDataModel   = 464,
    VisualEnginePointer        = 134340528,
    VisualEngineToDataModel1   = 2704,
    VisualEngineToDataModel2   = 464,
    LocalPlayer                = 312,

    Name                       = 176,
    ClassDescriptor            = 24,
    ClassDescriptorToClassName = 8,
    Children                   = 120,
    Parent                     = 112,
    StringLength               = 16,

    TextLabelText              = 3488,
    TextLabelVisible           = 1453,
    FrameVisible               = 1453,
    ScreenGuiEnabled           = 1220,
    FramePositionX             = 1296,
    FrameSizeX                 = 1328,
    GuiObjectRotation          = 392,
}

local OFFSETS_OVERRIDE_PATHS = {
    "C:/matcha/workspace/zerodeath_offsets.json",
}

local function tryLoadOffsetsOverride()
    if type(readfile) ~= "function" or type(isfile) ~= "function" then return end
    for _, p in ipairs(OFFSETS_OVERRIDE_PATHS) do
        local okExists, exists = pcall(isfile, p)
        if okExists and exists then
            local ok, json = pcall(readfile, p)
            if ok and json then
                local ok2, parsed = pcall(function() return HttpService:JSONDecode(json) end)
                if ok2 and type(parsed) == "table" and parsed.zerodeath_override == true then

                    local nested = parsed.Offsets or parsed
                    local rename = {
                        {"FakeDataModel",  "Pointer",            "FakeDataModelPointer"},
                        {"FakeDataModel",  "RealDataModel",      "FakeDataModelToDataModel"},
                        {"VisualEngine",   "Pointer",            "VisualEnginePointer"},
                        {"VisualEngine",   "FakeDataModel",      "VisualEngineToDataModel1"},
                        {"FakeDataModel",  "RealDataModel",      "VisualEngineToDataModel2"},
                        {"Player",         "LocalPlayer",        "LocalPlayer"},
                        {"Instance",       "Name",               "Name"},
                        {"Instance",       "ClassDescriptor",    "ClassDescriptor"},
                        {"Instance",       "ClassName",          "ClassDescriptorToClassName"},
                        {"Instance",       "ChildrenStart",      "Children"},
                        {"Instance",       "Parent",             "Parent"},
                        {"Misc",           "StringLength",       "StringLength"},
                        {"GuiObject",      "Text",               "TextLabelText"},
                        {"GuiObject",      "Visible",            "TextLabelVisible"},
                        {"GuiObject",      "Visible",            "FrameVisible"},
                        {"GuiObject",      "ScreenGui_Enabled",  "ScreenGuiEnabled"},
                        {"GuiObject",      "Position",           "FramePositionX"},
                        {"GuiObject",      "Size",               "FrameSizeX"},
                        {"GuiObject",      "Rotation",           "GuiObjectRotation"},
                    }
                    for _, r in ipairs(rename) do
                        local cat = nested[r[1]]
                        if cat and cat[r[2]] then OFFSETS[r[3]] = cat[r[2]] end
                    end
                    print("[ZeroDeath] Offsets loaded from " .. p)
                    return
                end
            end
        end
    end
end
tryLoadOffsetsOverride()

local function _index(o, k) return o[k] end
local function _setIndex(o, k, v) o[k] = v end

local function readPtr(addr)
    if not addr or addr <= 4096 then return nil end
    local ok, v = pcall(memory_read, "uintptr_t", addr)
    return (ok and v and v > 4096) and v or nil
end

local function readFloat(addr)
    if not addr or addr <= 4096 then return 0.0 end
    local ok, v = pcall(memory_read, "float", addr)
    return (ok and v) or 0.0
end

local function readInt(addr)
    if not addr or addr <= 4096 then return 0 end
    local ok, v = pcall(memory_read, "int32", addr)
    return (ok and v) or 0
end

local function readByte(addr)
    if not addr or addr <= 4096 then return 0 end
    local ok, v = pcall(memory_read, "byte", addr)
    return (ok and v) or 0
end

local function instAddr(inst)
    if not inst then return nil end
    local ok, a = pcall(_index, inst, "Address")
    a = (ok and a) and tonumber(a) or nil
    return (a and a > 4096) and a or nil
end

local function readFramePos(frame)
    local a = instAddr(frame); if not a then return 0, 0, 0, 0 end
    local base = a + OFFSETS.FramePositionX
    return readFloat(base + 0x0), readInt(base + 0x4), readFloat(base + 0x8), readInt(base + 0xC)
end

local function readFrameSize(frame)
    local a = instAddr(frame); if not a then return 0, 0, 0, 0 end
    local base = a + OFFSETS.FrameSizeX
    return readFloat(base + 0x0), readInt(base + 0x4), readFloat(base + 0x8), readInt(base + 0xC)
end

local function isScreenGuiEnabled(gui)
    if not gui then return false end

    local ok, v = pcall(_index, gui, "Enabled")
    if ok and type(v) == "boolean" then return v end

    local a = instAddr(gui); if not a then return true end
    return readByte(a + OFFSETS.ScreenGuiEnabled) ~= 0
end

local function isGuiVisible(inst)
    if not inst then return false end
    local ok, v = pcall(_index, inst, "Visible")
    if ok and type(v) == "boolean" then return v end
    local a = instAddr(inst); if not a then return true end
    return readByte(a + OFFSETS.FrameVisible) ~= 0
end

local function readGuiText(inst)
    if not inst then return "" end
    local ok, v = pcall(_index, inst, "Text")
    if ok and type(v) == "string" and v ~= "" then return v end

    local ok2, v2 = pcall(_index, inst, "Value")
    if ok2 and type(v2) == "string" then return v2 end
    return ""
end

local SETTINGS_PATH = "C:/matcha/workspace/zerodeath_fisch.json"

local DEFAULTS = {

    tracker_mode           = "predict",

    cast_mode              = "short",
    cast_power_custom      = 96.0,
    cast_timeout_ms        = 15000,
    pre_cast_delay_ms      = 0,
    post_cast_delay_ms     = 150,
    cast_on_timeout        = 1,

    auto_reel_only         = 0,

    show_status_hud        = 1,
    hud_x                  = 16,
    hud_y                  = 150,

    debug_logging          = 0,

    fishing_action_delay_ms = 0,
    completion_threshold    = 99.7,
    shake_interval_ms       = 25,

    watchdog_enabled        = 1,
    watchdog_stall_sec      = 20,

    lullaby_mode           = "prismatic",

    auto_appraise_enabled  = 0,
    auto_appraise_mutation = "",
    auto_appraise_mutations = "",
    auto_appraise_click_x  = "",
    auto_appraise_click_y  = "",
    appraise_delay_ms      = 100,

    auto_appraise_shiny     = 0,
    auto_appraise_sparkling = 0,
    auto_appraise_tiny      = 0,
    auto_appraise_small     = 0,
    auto_appraise_big       = 0,
    auto_appraise_giant     = 0,

    auto_totem_enabled     = 0,
    auto_totem_day         = "None",
    auto_totem_night       = "None",
    auto_totem_mode        = "cycle",
    auto_totem_interval_sec= 900,

    webhook_url                    = "",
    webhook_enabled                = 0,
    webhook_summary_interval_min   = 30,
    webhook_summary_fish           = 1,
    webhook_summary_success_rate   = 1,
    webhook_summary_rod            = 1,
    webhook_summary_config         = 1,
    webhook_summary_totem_state    = 1,
    webhook_summary_totem_pops     = 1,
    webhook_summary_session_time   = 1,
    webhook_summary_cast_timeouts  = 1,
    webhook_alert_totem_failed     = 1,

    webhook_summary_fish_per_hour  = 1,
    webhook_summary_tracker        = 1,
    webhook_summary_cycle          = 1,
    webhook_summary_activity       = 1,
    webhook_summary_mem            = 0,

    webhook_user_id                = "",

    webhook_alert_start            = 1,
    webhook_alert_stop             = 1,
    webhook_alert_stall            = 1,
    webhook_stall_minutes          = 10,
    webhook_ping_on_alerts         = 0,
    webhook_milestone              = 0,
    webhook_milestone_every        = 100,

    hunt_alerts_enabled            = 0,
    hunt_alerts_selected           = "",

    auto_weather_enabled   = 0,
    weather_target         = "none",
    weather_totem          = "",
    weather_cooldown_sec   = 90,

    hunt_detect_enabled    = 0,
    hunt_detect_target     = "",
    hunt_continue_after    = 1,
    hunt_teleport_on_click = 1,

    auto_recharge_enabled  = 0,
    recharge_relic         = "enchant",
    recharge_threshold     = 90,

    auto_enchant_enabled   = 0,
    enchant_target_enchant = "none",
    enchant_target_exalted = "none",
    enchant_target_twisted = "none",
    enchant_target_cosmic  = "none",

    track_daily_shop       = 1,
    track_sunken_chest     = 1,
    track_orca_migration   = 1,

    hk_start_macro   = 0x70,
    hk_stop_appraise = 0x71,
    hk_fix_attach    = 0x72,
    hk_reload_macro  = 0x73,
    hk_appraise      = 0x74,
    hk_toggle_menu   = 0x2E,
}

local MAIN = {}
for k, v in pairs(DEFAULTS) do MAIN[k] = v end

local function saveSettings()
    if type(writefile) ~= "function" then return end
    local ok, json = pcall(function() return HttpService:JSONEncode(MAIN) end)
    if ok and json then pcall(writefile, SETTINGS_PATH, json) end
end

local function loadSettings()
    if type(isfile) ~= "function" then return end
    local okExists, exists = pcall(isfile, SETTINGS_PATH)
    if not (okExists and exists) then return end
    local ok, body = pcall(readfile, SETTINGS_PATH)
    if not (ok and body) then return end
    local ok2, parsed = pcall(function() return HttpService:JSONDecode(body) end)
    if not (ok2 and type(parsed) == "table") then return end
    for k, v in pairs(parsed) do
        if DEFAULTS[k] ~= nil then MAIN[k] = v end
    end
end
loadSettings()

local WEBHOOK_URL_PATH = "C:/matcha/workspace/zerodeath_webhook.txt"

local function isValidWebhookUrl(u)
    if type(u) ~= "string" then return false end
    return u:find("^https://[%w%.]-discord[%w%.]-%.com/api/webhooks/") ~= nil
        or u:find("^https://discordapp%.com/api/webhooks/") ~= nil
end

local function loadWebhookUrlFromFile()
    if type(isfile) ~= "function" or type(readfile) ~= "function" then return false end
    local okExists, exists = pcall(isfile, WEBHOOK_URL_PATH)
    if not (okExists and exists) then return false end
    local ok, body = pcall(readfile, WEBHOOK_URL_PATH)
    if not (ok and body) then return false end
    local url, uid = nil, ""
    for line in (body .. "\n"):gmatch("([^\r\n]*)[\r\n]") do
        line = line:gsub("%s+", "")
        if line ~= "" and line:sub(1, 1) ~= "#" then
            if not url then url = line
            elseif uid == "" then uid = line end
        end
    end
    url = url or ""
    if url == "" or not isValidWebhookUrl(url) then return false end
    uid = uid:gsub("[^%d]", "")
    local changed = (url ~= MAIN.webhook_url) or (uid ~= (MAIN.webhook_user_id or ""))
    MAIN.webhook_url     = url
    MAIN.webhook_user_id = uid
    if changed then saveSettings() end
    return changed
end

local function getWorkspaceRoot()
    return game:GetService("Workspace")
end

local function getPlayerGui()
    local lp = getLP(); if not lp then return nil end
    return lp:FindFirstChildOfClass("PlayerGui") or lp:FindFirstChild("PlayerGui")
end

local function findChild(parent, name)
    if not parent then return nil end
    local ok, v = pcall(parent.FindFirstChild, parent, name)
    return ok and v or nil
end

local function findDescendantFrameByName(root, targetName)
    if not root then return nil end
    local queue, head = { root }, 1
    while head <= #queue do
        local cur = queue[head]; head = head + 1
        local ok, ch = pcall(cur.GetChildren, cur)
        if ok and ch then
            for _, c in ipairs(ch) do
                if c.Name == targetName and c.ClassName == "Frame" then return c end
                table.insert(queue, c)
            end
        end
        if head > 8192 then return nil end
    end
    return nil
end

local function getCharacterModel()
    local lp = getLP(); if not lp then return nil end
    local ws = getWorkspaceRoot()
    return ws and findChild(ws, lp.Name) or lp.Character
end

local function getHotbarGui()
    local pg = getPlayerGui(); if not pg then return nil end
    local bp = findChild(pg, "backpack"); if not bp then return nil end
    return findChild(bp, "hotbar")
end

local KNOWN_RODS = {
    "Pinion's Aria", "Tranquility Rod", "Rod Of The Eternal King",
    "Rod Of The Depths", "Rod Of Time", "Flimsy Rod", "Training Rod",
    "Plastic Rod", "Steady Rod", "Reinforced Rod", "Phoenix Rod",
    "Mythical Rod", "No-Life Rod", "Sunken Rod", "Trident Rod",
    "Kings Rod", "Wisdom Rod", "Toxinburst Rod", "The Lost Rod",
    "Riptide Rod", "Lucid Rod", "Celestial Rod", "Seasons Rod",
    "Krampus's Rod", "Precision Rod", "Resourceful Rod", "Toxic Spire Rod",
    "Gardenkeeper Rod", "Voyager Rod", "Vineweaver Rod", "Dreambreaker Rod",
    "Bellona's Waraxe", "Masterline Rod", "Requiem", "Splitbranch Twig", "MiguRod",
    "Lullaby",
}

local function normalizeRodText(s)
    s = s or ""
    s = s:gsub("\r", "\n")
    s = s:gsub("<[^>]+>", "")

    s = s:gsub("<[^>]*$", "")
    s = s:gsub("[ \t]+", " ")
    s = s:gsub("\n+", "\n")
    return (s:gsub("^%s*(.-)%s*$", "%1"))
end

local function extractPureRodName(text)
    text = normalizeRodText(text)
    if text == "" then return "" end
    for _, rod in ipairs(KNOWN_RODS) do
        if text:find(rod, 1, true) then return rod end
    end
    for line in text:gmatch("[^\n]+") do
        line = line:gsub("^%s*(.-)%s*$", "%1")
        if line:lower():find("%f[%w]rod%f[%W]") or line == "Pinion's Aria" then
            return line
        end
    end
    return ""
end

local function getHotbarRodName()
    local hotbar = getHotbarGui(); if not hotbar then return "" end
    local fallback = ""
    local ok, kids = pcall(hotbar.GetChildren, hotbar)
    if not ok then return "" end
    for _, slot in ipairs(kids) do
        if slot.ClassName == "ImageButton" and slot.Name == "ItemTemplate" then
            local nameInst = findChild(slot, "ItemName")
            if nameInst then
                local t = normalizeRodText(readGuiText(nameInst))
                local pure = extractPureRodName(t)
                if pure ~= "" then return pure end
                if t ~= "" and fallback == "" then fallback = t end
            end
        end
    end
    return fallback
end

local function isTranquilityRod(t)   return (t or ""):lower():find("tranquility", 1, true) ~= nil end

function RP.classifyRod(text)
    text = (text or ""):lower()
    if text == "" then return "default" end
    if text:find("bellona", 1, true) and text:find("waraxe", 1, true) then return "bellona" end
    if text:find("masterline",   1, true) then return "masterline" end
    if text:find("tranquility",  1, true) then return "tranquility" end
    if text:find("pinion",       1, true) then return "pinion" end
    if text:find("dreambreaker", 1, true) then return "dreambreaker" end
    if text:find("requiem",      1, true) then return "requiem" end
    if text:find("splitbranch",  1, true) and text:find("twig", 1, true) then return "splitbranch" end
    if text:find("migu",         1, true) then return "migu" end
    if text:find("lullaby",      1, true) then return "lullaby" end
    return "default"
end

RP.ALL_RODS = {
    "Abyssal Specter Rod","Acidgrinder","Adventurer's Rod","Anchor n' Chain","Antler Rod","Apollo's Sunshot","Arctic Rod","Astraeus Serenade","Astral Rod","Astralhook Rod",
    "Auric Rod","Aurora Rod","Avalanche Rod","Axe of Rhoads","Azure Of Lagoon","Bat Whisperer Rod","Bellona's Waraxe","Blade Of Glorp","Blazebringer Rod","Bloomspire",
    "Bloomspire: Blooming Splendor","Bloomspire: Slumbering Elegance","Bloomspire: Twisted Toxins","Bone Blade","Boreal Rod","Brick Built Rod","Brick Rod","Brine-Infused Rod","Brother's Rod","Buddy Bond Rod",
    "Bunnybloom Caster","Candy Cane Rod","Carbon Rod","Carrot Rod","Castbound","Celestial Rod","Cerebra","Cerulean Fang Rod","Challenger's Rod","Champions Rod",
    "Christmas Tree Rod","Chrysalis","Cinder Block Rod","Cinderstring","Clickbait Caster","Clover Rod","Coral Rod","Cornucopia Rod","Cryolash","Crystalized Rod",
    "Cupid's Bow","Cupid's Embrace","Dave Rod","Daybreaker Rod","Dead Man's Rod","Decayed Rod","Demon-Slayer","Depthseeker Rod","Destiny Rod","Dreambreaker",
    "Dusekkar Rod","Duskwire","Eardrum","Egg Rod","Eidolon Rod","Elder Mossripper","Electric Guitar","Ethereal Prism Rod","Event Horizon Rod","Evil Pitchfork",
    "Experimental Rod","Fabulous Rod","Fallen Rod","Fallen Snowblade","Fang of the Eclipse","Fast Rod","Firefly Rod","Firework Rod","Fischer's Rod","Fischmas Rod",
    "Fish Photographer","Fixer's Rod","Flimsy Rod","Fortune Rod","Free Spirit Rod","Friendly Rod","Frog Rod","Frost Warden Rod","Frostbane Rod","Frostfire Rod",
    "Fungal Rod","Gardenkeeper Rod","Gingerbread Rod","Great Dreamer Rod","Great Rod of Oscar","Hades' Soul-Scythe","Haunted Rod","Heaven's Rod","Ice Warpers Rod","Igneous Rupturer",
    "Jack-o-Blazer","Jinglestar Rod","Katana Rod","Kings Rod","Kraken Rod","Krampus's Rod","Leprechaun Line","Leviathan's Fang Rod","Lobster Rod","Long Rod",
    "Lucid Rod","Lucky Rod","Lullaby","Luminescent Oath","Maelstrom","Magma Rod","Magnet Rod","Masterline Rod","Merchant Rod","Merlin's Staff",
    "Microphone Rod","Midas Rod","MiguRod","Mission Specialist's Rod","Mythical Rod","Nates Blade","Necrotic Rod","New Years Rod","Nico's Yarncaster","NilCaster",
    "No-Life Rod","Noctone","Nocturnal Rod","North Pole","North-Star Rod","Olympian Godbreaker","Onirifalx","Original No-Life Rod","Paintbrush","Paleontologist's Rod",
    "Paper Fan Rod","Part","Patriot Rod","Pen Rod","Peppermint Rod","Phoenix Rod","Pinion's Aria","Plaguereaver","Plastic Rod","Polaris Serenade",
    "Popsicle Rod","Poseidon Rod","Poseidon's Lance","Precision Rod","Rainbow Cluster Rod","Random Rod","Rapid Rod","Reinforced Rod","Relic Rod","Remembrance",
    "Requiem","Resourceful Rod","Riptide Rod","Rod Of The Depths","Rod Of The Eternal King","Rod Of The Exalted One","Rod Of The Forgotten Fang","Rod Of The Zenith","Rod Of Time","Rod of the Cosmos",
    "Rose Rend","Rose Rod","Ruinous Oath","SOULREAPER","Sanguine Spire","Santa's Miracle Rod","Scarlet Ravager","Scarlet Spincaster Rod","Scurvy Rod","Seasons Rod",
    "Seraphic Rod","Shamrock Rod","Silly Fun Happy Rod","Smurf Rod","Sovereign Doombringer","Spirit of the Forest","Spiritbinder","Splitbranch Twig","Spooky Rod","Steady Rod",
    "Steampunk Rod","Stone Hammer","Stone Rod","Summit Rod","Sunken Rod","Superstar Rod","Sweet-Stinger","Sword of Darkness","Tempest Rod","Test Rod",
    "Thalassar's Ruin","The Boom Ball","The Lost Rod","Tidal Wave Rod","Tidemourner","Toxic Spire Rod","Toxinburst Rod","Training Rod","Tranquility Rod","Treasure Rod",
    "Trident Rod","Tryhard Rod","Upside-Down Rod","Verdant Oath","Verdant Shear Rod","View Smasher","Vinefang Rod","Vineweaver Rod","Volcanic Rod","Voyager Rod",
    "Wicked Fang Rod","Wildflower Rod","Wind Elemental","Wingkeeper","Wingripper","Wisdom Rod","Zeus Rod","Zeus's Thundermaul",
}
function RP.isKnownRod(name)
    name = (name or ""):lower()
    for _, r in ipairs(RP.ALL_RODS) do if r:lower() == name then return true end end
    return false
end

local VK = {
    F1 = 0x70, F2 = 0x71, F3 = 0x72, F4 = 0x73, F5 = 0x74, F6 = 0x75,
    Enter = 0x0D, Esc = 0x1B, Space = 0x20, Backslash = 0xDC,
    D1 = 0x31, D2 = 0x32, D3 = 0x33, D4 = 0x34,
    D5 = 0x35, D6 = 0x36, D7 = 0x37, D8 = 0x38, D9 = 0x39, D0 = 0x30,
    T  = 0x54, A = 0x41, S = 0x53, D = 0x44, F = 0x46,
    Shift = 0x10, G = 0x47, E = 0x45,
}

local ROD_KIND = "default"

local function tapKey(vk, holdMs)
    keypress(vk)
    task.wait((holdMs or 30) / 1000)
    keyrelease(vk)
end

local function sendEnter() tapKey(VK.Enter, 20) end
local function sendT()     tapKey(VK.T, 30) end
local function activateUiNav() tapKey(VK.Backslash, 20) end

local function slotVK(slotKey)
    if slotKey == "" or slotKey == nil then return nil end
    local s = tostring(slotKey)
    if s == "0" then return VK.D0 end
    local n = tonumber(s)
    if n and n >= 1 and n <= 9 then return ({VK.D1,VK.D2,VK.D3,VK.D4,VK.D5,VK.D6,VK.D7,VK.D8,VK.D9})[n] end
    if #s == 1 then
        local upper = s:upper():byte()
        if upper >= 65 and upper <= 90 then return upper end
    end
    return nil
end

local function selectHotbarSlot(slotKey)
    local vk = slotVK(slotKey); if not vk then return false end
    tapKey(vk, 25)
    task.wait(0.075)
    return true
end

local function robloxActive()
    if type(isrbxactive) ~= "function" then return true end
    local ok, v = pcall(isrbxactive)
    return (not ok) or (v ~= false)
end

local mouseHeld = false
local lastActionAt = 0

function RP.actionDelay()
    local base = MAIN.fishing_action_delay_ms or 0
    if ROD_KIND == "requiem" and base < 160 then return 160 end
    return base
end

local function holdMouse(force)
    if mouseHeld then return end
    local delay = RP.actionDelay()
    if not force and delay > 0 and lastActionAt ~= 0 and (tick()*1000 - lastActionAt) < delay then return end
    mouse1press()
    mouseHeld = true
    lastActionAt = tick() * 1000
end

local function releaseMouse(force)
    if not mouseHeld then return end
    local delay = RP.actionDelay()
    if not force and delay > 0 and lastActionAt ~= 0 and (tick()*1000 - lastActionAt) < delay then return end
    mouse1release()
    mouseHeld = false
    lastActionAt = tick() * 1000
end

RP.mouse2Held = false
function RP.holdMouse2()    if RP.mouse2Held then return end; mouse2press();   RP.mouse2Held = true  end
function RP.releaseMouse2() if not RP.mouse2Held then return end; mouse2release(); RP.mouse2Held = false end

local function clickOnce()
    mouse1press(); task.wait(0.04); mouse1release()
end

local function reliableScreenClick(x, y)
    pcall(mousemoveabs, 0, math.floor(x + 0.5), math.floor(y + 0.5))
    task.wait(0.03)
    clickOnce()
end

function RP.readAbsCenter(inst)
    if not inst then return nil end
    local okP, pos  = pcall(_index, inst, "AbsolutePosition")
    local okS, size = pcall(_index, inst, "AbsoluteSize")
    if not (okP and pos and okS and size) then return nil end
    local okx, sx = pcall(_index, pos, "X")
    local oky, sy = pcall(_index, pos, "Y")
    local okw, sw = pcall(_index, size, "X")
    local okh, sh = pcall(_index, size, "Y")
    if not (okx and oky and okw and okh and sx and sy and sw and sh) then return nil end
    if sw <= 1 or sh <= 1 then return nil end
    return math.floor(sx + sw / 2 + 0.5), math.floor(sy + sh / 2 + 0.5)
end

local Macro = {
    phase                  = "OFF",
    powerPercent           = "",
    progressPercent        = "",
    castThreshold          = 96.0,
    castWaitTimeoutMs      = 15000,
    fishingEndGraceMs      = 100,
    castStartedAt          = 0,
    castReleasedAt         = 0,
    castBarSeen            = false,
    fishingLostAt          = 0,
    completionReached      = false,
    outcomeResolved        = false,
    fishCaughtCount        = 0,
    fishLostCount          = 0,
    castTimeoutCount       = 0,
    totemPopCount          = 0,
    shakingIntervalMs      = 25,
    lastShakedAt           = 0,
    ActivatedUiNav         = false,
    cycleEnabled           = false,
    totemState             = "IDLE",
    totemRetryCount        = 0,
    totemWaitStartedAt     = 0,
    lastTotemSuccessAt     = 0,
    lastTotemAttemptAt     = 0,
    totemPending           = false,
    totemBlockedUntilCatchEnd = false,
    totemNightCovered      = false,
    totemDeployedCycle     = "",
    weatherDeployActive    = false,
    lastWeatherAt          = 0,
    totemNeedsRodReequip   = false,

    wdSig                  = "",
    wdSignalAt             = 0,
    wdRecoveryAt           = 0,
    wdRodCheckAt           = 0,
    wdRodStreak            = 0,
    wdRodEquipAt           = 0,

    fhHoldStartedAt        = 0,
    fhMotionAt             = 0,
    fhLastFish             = nil,
    fhLastBar              = nil,
    fhLastProg             = nil,

    hadMetricsLastTick     = false,
    fishInputReadyAt       = 0,
    startupActive          = false,
    startupStartedAt       = 0,
    startupStartFish       = nil,
    totemNeedsSettleDelay  = false,

    reelGui      = nil,
    reelBar      = nil,
    fishInst     = nil,
    playerbar    = nil,
    progressBar  = nil,
    powerBar     = nil,
    reelVerifiedAt = 0,

    castChargeLastPct  = nil,
    castChargeMotionAt = 0,

    appraiseSubvalues      = nil,
    appraiseLastClickAt    = 0,
    appraiseWaitStartedAt  = 0,
    appraiseSubvaluesRetryCount   = 0,
    appraiseSubvaluesLastRetryAt  = 0,
    appraiseStartCoins     = "",
    appraiseEndCoins       = "",
    appraiseState          = "IDLE",
    appraiseLastError      = "",

    reelSessionActive     = false,
    reelSessionStartedAt  = 0,
    reelMissingAt         = 0,
    reelLastContextAt     = 0,
}

local ROD = ""
local DreambreakerActive = false

local WebhookSession = {
    startedAt = 0, lastSummaryAt = 0,
    wasRunning = false,
    lastCatchCount = 0, lastCatchAt = 0, stallAlerted = false,
    lastMilestone = 0,
}

local function clearMacroPhaseCache()
    Macro.reelGui = nil; Macro.reelBar = nil; Macro.fishInst = nil
    Macro.playerbar = nil; Macro.progressBar = nil; Macro.powerBar = nil
    Macro.appraiseSubvalues = nil
    Macro.appraiseState = "IDLE"
    Macro.appraiseLastClickAt = 0
    Macro.appraiseWaitStartedAt = 0
    Macro.appraiseStartCoins = ""
    Macro.appraiseEndCoins = ""
    Macro.appraiseLastError = ""
end

local function getReelGui()
    local pg = getPlayerGui(); if not pg then return nil end
    return findChild(pg, "reel")
end

local function reelGuiVisible(reel)
    reel = reel or getReelGui()
    if not reel then return false end
    local bar = findChild(reel, "bar")
    return bar and findChild(bar, "fish") and findChild(bar, "playerbar") and true or false
end

local function instNameIs(inst, expected)
    if not inst then return false end
    local ok, n = pcall(_index, inst, "Name")
    return ok and n == expected
end

local reelCtx = {}
local function getReelBarContext()
    local reel = getReelGui()

    if not reel then
        Macro.reelBar = nil; Macro.fishInst = nil; Macro.playerbar = nil
        Macro.progressBar = nil; Macro.reelVerifiedAt = 0
        return nil
    end
    if Macro.reelBar and Macro.fishInst and Macro.playerbar then

        local nowMs = tick() * 1000
        if nowMs - Macro.reelVerifiedAt >= 500 then
            if instNameIs(Macro.reelBar, "bar")
               and instNameIs(Macro.fishInst, "fish")
               and instNameIs(Macro.playerbar, "playerbar") then
                Macro.reelVerifiedAt = nowMs
            else
                Macro.reelBar = nil; Macro.fishInst = nil; Macro.playerbar = nil
                Macro.progressBar = nil
            end
        end
        if Macro.reelBar then
            reelCtx.bar = Macro.reelBar; reelCtx.fish = Macro.fishInst; reelCtx.playerbar = Macro.playerbar
            return reelCtx
        end
    end
    local barFrame = findChild(reel, "bar"); if not barFrame then return nil end
    Macro.reelBar   = barFrame
    Macro.fishInst  = findChild(barFrame, "fish")
    Macro.playerbar = findChild(barFrame, "playerbar")
    if not (Macro.fishInst and Macro.playerbar) then
        Macro.reelBar = nil; return nil
    end
    Macro.reelVerifiedAt = tick() * 1000
    reelCtx.bar = barFrame; reelCtx.fish = Macro.fishInst; reelCtx.playerbar = Macro.playerbar
    return reelCtx
end

local function hasActiveFishingContext(ctx)
    ctx = ctx or getReelBarContext()
    return ctx and ctx.fish and ctx.playerbar and true or false
end

function RP.reelMetricsSane(ctx)
    if not ctx or not ctx.bar or not ctx.fish or not ctx.playerbar then return false end
    local ok0, bp = pcall(_index, ctx.bar, "AbsolutePosition")
    local ok1, bs = pcall(_index, ctx.bar, "AbsoluteSize")
    local ok2, fp = pcall(_index, ctx.fish, "AbsolutePosition")
    local ok3, fs = pcall(_index, ctx.fish, "AbsoluteSize")
    local ok4, pp = pcall(_index, ctx.playerbar, "AbsolutePosition")
    local ok5, ps = pcall(_index, ctx.playerbar, "AbsoluteSize")
    if not (ok0 and ok1 and ok2 and ok3 and ok4 and ok5 and bp and bs and fp and fs and pp and ps) then return false end
    local bx, bwpx = bp.X, bs.X
    if not bx or not bwpx or bwpx <= 1 then return false end
    local fc = ((fp.X + fs.X * 0.5) - bx) / bwpx
    local bc = ((pp.X + ps.X * 0.5) - bx) / bwpx
    local bw = ps.X / bwpx
    if MAIN.debug_logging == 1 then Macro.dbgFc, Macro.dbgBc, Macro.dbgBw = fc, bc, bw end
    return fc == fc and bc == bc and bw == bw and fc >= -0.5 and fc <= 1.5 and bc >= -0.5 and bc <= 1.5 and bw > 0 and bw <= 2.0
end

function RP.findDesc(root, name, depth)
    if not root or (depth or 0) > 6 then return nil end
    local ok, ch = pcall(root.GetChildren, root)
    if not ok or not ch then return nil end
    for _, c in ipairs(ch) do
        if c.Name == name then return c end
    end
    for _, c in ipairs(ch) do
        local d = RP.findDesc(c, name, (depth or 0) + 1)
        if d then return d end
    end
    return nil
end

function RP.shakeButtonInst()
    local pg = getPlayerGui(); if not pg then return nil end

    local gui = findChild(pg, "shakeui")
    if not gui or not isScreenGuiEnabled(gui) then return nil end
    local safe = findChild(gui, "safezone") or RP.findDesc(gui, "safezone") or gui
    local btn  = findChild(safe, "button")  or RP.findDesc(safe, "button")
    if not btn then return nil end
    local ok, cls = pcall(_index, btn, "ClassName")
    if not (ok and cls == "ImageButton") then return nil end
    if not isGuiVisible(btn) then return nil end
    return btn
end

function RP.shakeButtonVisible()
    return RP.shakeButtonInst() ~= nil
end

local function getReelProgressContext()

    local reel = getReelGui(); if not reel then Macro.progressBar = nil; return nil end
    local controlBar = Macro.reelBar or findChild(reel, "bar")
    if not controlBar then return nil end
    local progressFrame = findChild(controlBar, "progress"); if not progressFrame then return nil end
    local progressBar   = findChild(progressFrame, "bar");   if not progressBar then return nil end
    return { reel = reel, controlBar = controlBar, progressBar = progressBar }
end

local function readProgressBarPercent(frame)

    local x = readFrameSize(frame)
    if x ~= x or x == math.huge or x == -math.huge or x < -0.05 or x > 1.5 then
        return nil
    end
    return math.max(0.0, math.min(100.0, x * 100.0))
end

local function getFishingCompletionPercent()
    local ctx = getReelProgressContext()
    if not ctx or not ctx.progressBar then return nil end
    return readProgressBarPercent(ctx.progressBar)
end

local function resolvePowerBar()

    local char = getCharacterModel(); if not char then return nil end
    local hrp  = findChild(char, "HumanoidRootPart"); if not hrp then return nil end
    local powerGui = findChild(hrp, "power"); if not powerGui then return nil end
    return findDescendantFrameByName(powerGui, "bar")
end

local function readPowerBarPercent(frame)

    local a = instAddr(frame); if not a then return nil end
    local scaleY = readFloat(a + OFFSETS.FrameSizeX + 0x8)
    if scaleY ~= scaleY or scaleY == math.huge or scaleY == -math.huge
       or scaleY < -0.05 or scaleY > 1.5 then
        return nil
    end
    return math.max(0.0, math.min(100.0, scaleY * 100.0))
end

local function resolveCastThreshold()
    local mode = MAIN.cast_mode
    if mode == "short"  then return 28.0 end
    if mode == "custom" then return math.max(1.0, math.min(100.0, (MAIN.cast_power_custom or 96) + 0.0)) end
    return 96.0
end

local function getTranquilityGui()
    local pg = getPlayerGui(); return pg and findChild(pg, "TranquilityRodRhythmGame") or nil
end
local function getTranquilityRoot()
    local g = getTranquilityGui(); return g and findChild(g, "RhythmGame") or nil
end
local function getTranquilityLaneContainer(root)
    root = root or getTranquilityRoot(); return root and findChild(root, "LaneContainer") or nil
end
local function getTranquilityHealthFill(root)
    root = root or getTranquilityRoot(); if not root then return nil end
    local hb = findChild(root, "HealthBar"); return hb and findChild(hb, "Fill") or nil
end
local function readTranquilityProgressPercent(root)
    local fill = getTranquilityHealthFill(root); if not fill then return nil end
    return readProgressBarPercent(fill)
end

local function getNoteContainer()
    local ctx = getReelBarContext()
    if not ctx or not ctx.bar then return nil end
    return findChild(ctx.bar, "noteContainer")
end

local function readNotePosition(frame)
    local x, ox, y, oy = readFramePos(frame)
    return { sx = x, ox = ox, sy = y, oy = oy }
end

local function getActiveNoteTarget()
    local nc = getNoteContainer(); if not nc then return nil end
    local best, bestY = nil, -999999.0
    for _, nm in ipairs({"note1", "note2"}) do
        local n = findChild(nc, nm)
        if n then
            local p = readNotePosition(n)
            if p.sy <= 0.55 and p.sy >= -30 and p.sy > bestY then
                bestY = p.sy; best = { sx = p.sx, sy = p.sy }
            end
        end
    end
    return best
end

RP.pinion = { notesCaught = 0, noteCounted = false, resonanceActive = false }

function RP.pinionReset()
    RP.pinion.notesCaught = 0; RP.pinion.noteCounted = false; RP.pinion.resonanceActive = false
end

function RP.pinionAdjust(fishCenter, barCenter, barWidth)
    local note = getActiveNoteTarget()
    if not note then return fishCenter end
    if note.sy < -19.5 then return fishCenter end

    local P = RP.pinion
    if not P.noteCounted and note.sy >= -0.8 and note.sy <= 0.53 then
        local hw = barWidth / 2
        local inBar = note.sx >= barCenter - hw - 0.1 and note.sx <= barCenter + hw + 0.1
        if inBar then
            P.noteCounted = true
            P.notesCaught = P.notesCaught + 1
        else
            P.notesCaught = 0
            P.resonanceActive = false
            P.noteCounted = true
        end
    end
    if note.sy < -8 then P.noteCounted = false end
    if P.notesCaught >= 7 then P.resonanceActive = true end

    if P.resonanceActive then return note.sx end

    local distance = math.abs(note.sx - fishCenter)
    if distance > barWidth then return note.sx end
    return (fishCenter + note.sx) / 2
end

TUNE.predict = {
    Kp = 1.25, Ki = 0.06, Kd = 1.85, PdClamp = 34.0, IntegralClamp = 130.0,
    BarRatioFromSide = 0.6, CenterZoneRatio = 0.05,
    CenterPulsePeriodS = 0.024, CenterPulseHoldS = 0.1, CenterReleaseBlipS = 0.006,
    CenterWeakPeriodS = 0.026, CenterWeakHoldS = 0.006,
    OnThreshold = 7.0, OffThreshold = 3.5,
    UsePrediction = true, FishPredT = 0.165, BarPredT = 0.028, RightMoveLeadT = 0.085,
    FishVelAlpha = 0.82, BarVelAlpha = 0.78, PositionAlpha = 0.9, ControlAlpha = 0.94,
}

TUNE.hybrid = {
    EdgeBoundary = 0.1, CloseThreshold = 0.0055, PredictionStrength = 13.0,
    Resilience = 0.0, EnableHardCorrection = true,
    Kp = 2.7, Ki = 0.08, Kd = 3.6, PdClamp = 48.0, IntegralClamp = 130.0,
    BarRatioFromSide = 0.6, CenterZoneRatio = 0.05,
    CenterPulsePeriodS = 0.016, CenterPulseHoldS = 0.013, CenterReleaseBlipS = 0.006,
    CenterWeakPeriodS = 0.017, CenterWeakHoldS = 0.01,
    OnThreshold = 3.5, OffThreshold = 1.4,
    UsePrediction = false, FishPredT = 0.23, BarPredT = 0.045, RightMoveLeadT = 0.16,
    HoldAcceleration = 0.62, ReleaseAcceleration = -0.3, MaxVelocity = 1.05,
    FishVelAlpha = 0.9, BarVelAlpha = 0.86, PositionAlpha = 0.98, ControlAlpha = 0.99,
}

TUNE.spam = {
    CloseThreshold = 0.01, DerivativeGain = 0.55, EdgeBoundary = 0.1,
    NeutralDutyCycle = 0.5, PredictionStrength = 7.5, ProportionalGain = 0.42,
    Resilience = 0.0, VelocityDamping = 38,
}

local function clampn(v, lo, hi) if v < lo then return lo elseif v > hi then return hi else return v end end
local function posmod(v, m)
    m = math.max(0.001, m)
    local r = v % m
    if r < 0 then r = r + m end
    return r
end

local Controller = {}
Controller.__index = Controller

function Controller.new()
    return setmetatable({
        lastPlayerbarPos = nil,
        lastFishPos      = nil,
        pwmAccumulator   = 0.0,
        kind             = "default",
        button           = "lmb",

        hasLastFrame         = false,
        lastTime             = 0.0,
        prevFishX            = 0.0,
        prevBarCenter        = 0.0,
        fishVelEma           = 0.0,
        barVelEma            = 0.0,
        smoothFishX          = 0.0,
        smoothBarCenter      = 0.0,
        smoothControl        = 0.0,
        errorIntegral        = 0.0,
        centerPulseReleaseUntil = 0.0,

        wasInStableZone      = false,
        stableHybridUntil    = 0.0,
        trackingWarmupUntil  = 0.0,
        lastBarRaw           = nil,
        lastFishRaw          = nil,
    }, Controller)
end

function Controller:Reset()
    self.lastPlayerbarPos = nil
    self.lastFishPos      = nil
    self.pwmAccumulator   = 0.0
    self.hasLastFrame     = false
    self.lastTime         = 0.0
    self.prevFishX        = 0.0
    self.prevBarCenter    = 0.0
    self.fishVelEma       = 0.0
    self.barVelEma        = 0.0
    self.smoothFishX      = 0.0
    self.smoothBarCenter  = 0.0
    self.smoothControl    = 0.0
    self.errorIntegral    = 0.0
    self.centerPulseReleaseUntil = 0.0
    self.wasInStableZone  = false
    self.stableHybridUntil = 0.0
    self.trackingWarmupUntil = os.clock() + 0.2
    self.lastBarRaw       = nil
    self.lastFishRaw      = nil
end

function Controller:GetFishPosition(ctx)
    ctx = ctx or getReelBarContext()
    if not ctx or not ctx.bar or not ctx.fish then return nil end
    local ok0, bp = pcall(_index, ctx.bar, "AbsolutePosition")
    local ok1, bs = pcall(_index, ctx.bar, "AbsoluteSize")
    local ok2, fp = pcall(_index, ctx.fish, "AbsolutePosition")
    local ok3, fs = pcall(_index, ctx.fish, "AbsoluteSize")
    if not (ok0 and ok1 and ok2 and ok3 and bp and bs and fp and fs and bs.X and bs.X > 1) then return nil end
    local fishCenter = ((fp.X + fs.X * 0.5) - bp.X) / bs.X
    if ROD_KIND == "pinion" and ctx.playerbar then
        local ok4, pp = pcall(_index, ctx.playerbar, "AbsolutePosition")
        local ok5, ps = pcall(_index, ctx.playerbar, "AbsoluteSize")
        if ok4 and ok5 and pp and ps then
            local bc = ((pp.X + ps.X * 0.5) - bp.X) / bs.X
            local bw = ps.X / bs.X; if bw < 0.001 then bw = 0.001 end
            fishCenter = RP.pinionAdjust(fishCenter, bc, bw)
        end
    end
    return fishCenter
end

function Controller:GetPlayerbarPosition(ctx)
    ctx = ctx or getReelBarContext()
    if not ctx or not ctx.bar or not ctx.playerbar then return nil end
    local ok0, bp = pcall(_index, ctx.bar, "AbsolutePosition")
    local ok1, bs = pcall(_index, ctx.bar, "AbsoluteSize")
    local ok2, pp = pcall(_index, ctx.playerbar, "AbsolutePosition")
    local ok3, ps = pcall(_index, ctx.playerbar, "AbsoluteSize")
    if not (ok0 and ok1 and ok2 and ok3 and bp and bs and pp and ps and bs.X and bs.X > 1) then return nil end
    return ((pp.X + ps.X * 0.5) - bp.X) / bs.X
end

function Controller:IsInverted()
    if not DreambreakerActive then return false end
    local p = getFishingCompletionPercent()
    if not p then return false end
    return p >= 40.0
end

function Controller:Hold()
    local inv = self:IsInverted()
    if self.button == "rmb" then
        if inv then RP.releaseMouse2() else RP.holdMouse2() end
    else
        if inv then releaseMouse() else holdMouse() end
    end
end
function Controller:Release()
    local inv = self:IsInverted()
    if self.button == "rmb" then
        if inv then RP.holdMouse2() else RP.releaseMouse2() end
    else
        if inv then holdMouse() else releaseMouse() end
    end
end

local function isIndicatorSafe(ctx)
    ctx = ctx or getReelBarContext()
    if not (ctx and ctx.playerbar and ctx.fish) then return nil end
    local ppx = readFramePos(ctx.playerbar)
    local psx = readFrameSize(ctx.playerbar)
    local fpx = readFramePos(ctx.fish)
    local fsx = readFrameSize(ctx.fish)
    local fishCenter = fpx + (fsx / 2)
    local halfWidth  = psx / 2
    local safeLeft   = ppx - halfWidth
    local safeRight  = ppx + halfWidth
    return fishCenter >= safeLeft and fishCenter <= safeRight
end

function Controller:UpdateSpam(ctx)
    ctx = ctx or getReelBarContext()
    local safe = isIndicatorSafe(ctx)
    if safe == nil then self:Release(); return end

    local fishPos      = self:GetFishPosition(ctx)
    local playerbarPos = self:GetPlayerbarPosition(ctx)
    if not (fishPos and playerbarPos) then return end

    if self.lastPlayerbarPos == nil then self.lastPlayerbarPos = playerbarPos end
    if self.lastFishPos      == nil then self.lastFishPos      = fishPos      end

    local playerbarVel = playerbarPos - self.lastPlayerbarPos
    self.lastPlayerbarPos = playerbarPos
    local fishVel      = fishPos - self.lastFishPos
    self.lastFishPos   = fishPos
    self.obsFish, self.obsBar = fishPos, playerbarPos

    local err = fishPos - playerbarPos
    local edge = TUNE.spam.EdgeBoundary
    if playerbarPos < edge       then self:Hold();    return end
    if playerbarPos > 1 - edge   then self:Release(); return end

    local predicted     = playerbarPos + (playerbarVel * (TUNE.spam.PredictionStrength * (1.0 - TUNE.spam.Resilience)))
    local predictedErr  = fishPos - predicted
    local close         = TUNE.spam.CloseThreshold
    local sameSideAfter = (err * predictedErr) > 0
    local approaching   = (err * playerbarVel) > 0
    local remaining     = math.max(0.0, math.abs(err) - close)
    local brake         = math.abs(playerbarVel) * 8
    local needsPreSlow  = approaching and (brake >= remaining)

    if math.abs(err) > close and sameSideAfter and not needsPreSlow then
        if err > 0 then self:Hold() else self:Release() end
        return
    end

    local neutral = TUNE.spam.NeutralDutyCycle
    local targetDuty

    if needsPreSlow and brake > 0 then
        local urgency = 1.0 - math.min(1.0, remaining / brake)
        if err > 0 then
            targetDuty = neutral * (1.0 - urgency)
        else
            targetDuty = neutral + ((1.0 - neutral) * urgency)
        end
    else
        local kP = TUNE.spam.ProportionalGain
        local kD = TUNE.spam.DerivativeGain
        local kV = TUNE.spam.VelocityDamping
        local adj = (kP * err) + (kD * fishVel) - (kV * playerbarVel)
        targetDuty = math.max(0.0, math.min(1.0, neutral + adj))
    end

    self.pwmAccumulator = self.pwmAccumulator + targetDuty
    if self.pwmAccumulator >= 1.0 then
        self.pwmAccumulator = self.pwmAccumulator - 1.0
        self:Hold()
    else
        self:Release()
    end
end

function Controller:_metrics(ctx)
    ctx = ctx or getReelBarContext()
    if not (ctx and ctx.bar and ctx.fish and ctx.playerbar) then return nil end
    local ok0, bp = pcall(_index, ctx.bar, "AbsolutePosition")
    local ok1, bs = pcall(_index, ctx.bar, "AbsoluteSize")
    local ok2, fp = pcall(_index, ctx.fish, "AbsolutePosition")
    local ok3, fs = pcall(_index, ctx.fish, "AbsoluteSize")
    local ok4, pp = pcall(_index, ctx.playerbar, "AbsolutePosition")
    local ok5, ps = pcall(_index, ctx.playerbar, "AbsoluteSize")
    if not (ok0 and ok1 and ok2 and ok3 and ok4 and ok5 and bp and bs and fp and fs and pp and ps and bs.X and bs.X > 1) then return nil end
    local fishCenter = ((fp.X + fs.X * 0.5) - bp.X) / bs.X
    local barCenter = ((pp.X + ps.X * 0.5) - bp.X) / bs.X
    local barWidth = ps.X / bs.X
    if fishCenter ~= fishCenter or barCenter ~= barCenter then return nil end
    if barWidth ~= barWidth or barWidth < 0.001 then barWidth = 0.001 end
    if ROD_KIND == "pinion" then fishCenter = RP.pinionAdjust(fishCenter, barCenter, barWidth) end
    self.obsFish, self.obsBar = fishCenter, barCenter
    return fishCenter, barCenter, barWidth
end

function Controller:UpdatePredict(ctx)
    ctx = ctx or getReelBarContext()
    local fishCenter, barCenter, barWidth01 = self:_metrics(ctx)
    if not fishCenter then self:Release(); return end

    local s = TUNE.predict
    local now = os.clock()
    local dt = self.hasLastFrame and math.max(0.001, now - self.lastTime) or 0.016
    local fishX    = fishCenter * 1000.0
    local bar      = barCenter * 1000.0
    local barWidth = math.max(1.0, barWidth01 * 1000.0)

    if not self.hasLastFrame then
        self.smoothFishX = fishX; self.smoothBarCenter = bar
        self.prevFishX = fishX;   self.prevBarCenter = bar
        self.lastTime = now;      self.hasLastFrame = true
    else
        local alpha = clampn(s.PositionAlpha, 0.2, 0.92)
        self.smoothFishX     = alpha * fishX + (1.0 - alpha) * self.smoothFishX
        self.smoothBarCenter = alpha * bar   + (1.0 - alpha) * self.smoothBarCenter
    end

    local fishVel = (self.smoothFishX - self.prevFishX) / dt
    local barVel  = (self.smoothBarCenter - self.prevBarCenter) / dt
    self.fishVelEma = s.FishVelAlpha * fishVel + (1.0 - s.FishVelAlpha) * self.fishVelEma
    self.barVelEma  = s.BarVelAlpha  * barVel  + (1.0 - s.BarVelAlpha)  * self.barVelEma
    self.prevFishX = self.smoothFishX
    self.prevBarCenter = self.smoothBarCenter
    self.lastTime = now

    local err
    if s.UsePrediction then
        local baseError = self.smoothFishX - self.smoothBarCenter
        local fishLead = clampn(self.fishVelEma * s.FishPredT, -math.max(2.0, barWidth * 0.18), math.max(2.0, barWidth * 0.18))
        local barLead  = clampn(self.barVelEma  * s.BarPredT,  -math.max(2.0, barWidth * 0.12), math.max(2.0, barWidth * 0.12))
        local predictedError = self.smoothFishX + 0.5 * fishLead - (self.smoothBarCenter + 0.35 * barLead)
        err = 0.65 * baseError + 0.35 * predictedError
    else
        err = self.smoothFishX - self.smoothBarCenter
    end

    if self.fishVelEma > 0 and err > -barWidth * 0.1 then
        err = err + clampn(self.fishVelEma * s.RightMoveLeadT, 0, math.max(2.0, barWidth * 0.22))
    end

    err = err + clampn(barWidth * 0.035, 1.5, 5.0)
    self.errorIntegral = clampn(self.errorIntegral + err * dt, -s.IntegralClamp, s.IntegralClamp)

    local sideMargin = barWidth * s.BarRatioFromSide
    local clampV = math.max(s.PdClamp > 0 and s.PdClamp or 30.0, s.OnThreshold + 1.0)
    local rawControl
    if self.smoothFishX < sideMargin then
        rawControl = -clampV
    elseif self.smoothFishX > 1000.0 - sideMargin then
        rawControl = clampV
    else
        local relVel = self.fishVelEma - self.barVelEma
        rawControl = s.Kp * err + s.Ki * self.errorIntegral + s.Kd * relVel
        if s.PdClamp > 0 then rawControl = clampn(rawControl, -s.PdClamp, s.PdClamp) end
    end

    self.smoothControl = s.ControlAlpha * rawControl + (1.0 - s.ControlAlpha) * self.smoothControl
    local control = self.smoothControl
    self.dbgErr, self.dbgControl = err, control

    local hold
    local centerZone = math.max(2.0, barWidth * s.CenterZoneRatio)
    if math.abs(err) <= centerZone then
        if now < self.centerPulseReleaseUntil then
            hold = false
        elseif control > s.OnThreshold then
            hold = posmod(now, s.CenterPulsePeriodS) < math.max(0.001, s.CenterPulseHoldS)
            if hold then self.centerPulseReleaseUntil = now + math.max(0, s.CenterReleaseBlipS) end
        elseif control < -s.OnThreshold then
            hold = false
        elseif control > 0 then
            hold = posmod(now, s.CenterWeakPeriodS) < math.max(0.001, s.CenterWeakHoldS)
        else
            hold = false
        end
    else
        if control > s.OnThreshold then hold = true
        elseif control < -s.OnThreshold then hold = false
        else hold = false end
    end

    if hold then self:Hold() else self:Release() end
end

function Controller:_hybridEma(fishCenter, barCenter, now, s)
    local fishX = fishCenter * 1000.0
    local barC  = barCenter * 1000.0
    local dt = self.hasLastFrame and math.max(0.001, now - self.lastTime) or 0.016
    if not self.hasLastFrame then
        self.smoothFishX = fishX; self.smoothBarCenter = barC
        self.prevFishX = fishX;   self.prevBarCenter = barC
        self.lastTime = now;      self.hasLastFrame = true
        return
    end
    local alpha = clampn(s.PositionAlpha, 0.2, 0.92)
    self.smoothFishX     = alpha * fishX + (1.0 - alpha) * self.smoothFishX
    self.smoothBarCenter = alpha * barC  + (1.0 - alpha) * self.smoothBarCenter
    local fishVel = (self.smoothFishX - self.prevFishX) / dt
    local barVel  = (self.smoothBarCenter - self.prevBarCenter) / dt
    self.fishVelEma = s.FishVelAlpha * fishVel + (1.0 - s.FishVelAlpha) * self.fishVelEma
    self.barVelEma  = s.BarVelAlpha  * barVel  + (1.0 - s.BarVelAlpha)  * self.barVelEma
    local maxv = math.max(1.0, s.MaxVelocity * 1000.0)
    self.barVelEma = clampn(self.barVelEma, -maxv, maxv)
    self.prevFishX = self.smoothFishX
    self.prevBarCenter = self.smoothBarCenter
    self.lastTime = now
end

function Controller:_hybridComputeFine(fishCenter, barCenter, barWidth01, now, s)
    local fishX = fishCenter * 1000.0
    local barC  = barCenter * 1000.0
    local barWidth = math.max(1.0, barWidth01 * 1000.0)
    local dt = self.hasLastFrame and math.max(0.001, now - self.lastTime) or 0.016

    if not self.hasLastFrame then
        self.smoothFishX = fishX; self.smoothBarCenter = barC
        self.prevFishX = fishX;   self.prevBarCenter = barC
        self.lastTime = now;      self.hasLastFrame = true
    else
        local alpha = clampn(s.PositionAlpha, 0.2, 0.92)
        self.smoothFishX     = alpha * fishX + (1.0 - alpha) * self.smoothFishX
        self.smoothBarCenter = alpha * barC  + (1.0 - alpha) * self.smoothBarCenter
    end

    local fishVelRaw = (self.smoothFishX - self.prevFishX) / dt
    local barVelRaw  = (self.smoothBarCenter - self.prevBarCenter) / dt
    self.fishVelEma = s.FishVelAlpha * fishVelRaw + (1.0 - s.FishVelAlpha) * self.fishVelEma
    self.barVelEma  = s.BarVelAlpha  * barVelRaw  + (1.0 - s.BarVelAlpha)  * self.barVelEma
    local maxv = math.max(1.0, s.MaxVelocity * 1000.0)
    self.barVelEma = clampn(self.barVelEma, -maxv, maxv)
    self.prevFishX = self.smoothFishX
    self.prevBarCenter = self.smoothBarCenter
    self.lastTime = now

    local err
    if s.UsePrediction then
        local baseError = self.smoothFishX - self.smoothBarCenter
        local fishLead = clampn(self.fishVelEma * s.FishPredT, -math.max(2.0, barWidth * 0.18), math.max(2.0, barWidth * 0.18))
        local holdingForPred = self.smoothControl > 0
        local measuredAccel = (holdingForPred and s.HoldAcceleration or s.ReleaseAcceleration) * 1000.0
        local predictedBarVel = clampn(self.barVelEma + measuredAccel * s.BarPredT, -maxv, maxv)
        local barLead = clampn(predictedBarVel * s.BarPredT, -math.max(2.0, barWidth * 0.12), math.max(2.0, barWidth * 0.12))
        local predictedError = self.smoothFishX + 0.25 * fishLead - (self.smoothBarCenter + 0.175 * barLead)
        err = 0.65 * baseError + 0.35 * predictedError
    else
        err = self.smoothFishX - self.smoothBarCenter
    end

    if self.fishVelEma > 0 and err > -barWidth * 0.1 then
        err = err + clampn(self.fishVelEma * s.RightMoveLeadT, 0, math.max(2.0, barWidth * 0.22))
    end

    err = err + clampn(barWidth * 0.035, 1.5, 5.0)
    self.errorIntegral = clampn(self.errorIntegral + err * dt, -s.IntegralClamp, s.IntegralClamp)

    local sideMargin = barWidth * s.BarRatioFromSide
    local clampV = math.max(s.PdClamp > 0 and s.PdClamp or 30.0, s.OnThreshold + 1.0)
    local rawControl
    if self.smoothFishX < sideMargin then
        rawControl = -clampV
    elseif self.smoothFishX > 1000.0 - sideMargin then
        rawControl = clampV
    else
        local relVel = self.fishVelEma - self.barVelEma
        rawControl = s.Kp * err + s.Ki * self.errorIntegral + s.Kd * relVel
        if s.PdClamp > 0 then rawControl = clampn(rawControl, -s.PdClamp, s.PdClamp) end
    end

    self.smoothControl = s.ControlAlpha * rawControl + (1.0 - s.ControlAlpha) * self.smoothControl
    local control = self.smoothControl

    local centerZone = math.max(2.0, barWidth * s.CenterZoneRatio)
    local desiredHold
    if math.abs(err) <= centerZone then
        local enteringStable = not self.wasInStableZone
        self.wasInStableZone = true
        if enteringStable then self.stableHybridUntil = now + 3.0 end

        if now < self.stableHybridUntil then
            if control > s.OnThreshold then desiredHold = true
            elseif control < -s.OnThreshold then desiredHold = false
            else desiredHold = false end
        else
            if now < self.centerPulseReleaseUntil then
                desiredHold = false
            elseif control > s.OnThreshold then
                local h = posmod(now, s.CenterPulsePeriodS) < math.max(0.001, s.CenterPulseHoldS)
                if h then self.centerPulseReleaseUntil = now + math.max(0, s.CenterReleaseBlipS) end
                desiredHold = h
            elseif control < -s.OnThreshold then
                desiredHold = false
            else
                desiredHold = (control > 0) and (posmod(now, s.CenterWeakPeriodS) < math.max(0.001, s.CenterWeakHoldS))
            end
        end
    else
        self.wasInStableZone = false
        if control > s.OnThreshold then desiredHold = true
        elseif control < -s.OnThreshold then desiredHold = false
        else desiredHold = false end
    end

    return desiredHold
end

function Controller:UpdateHybrid(ctx)
    ctx = ctx or getReelBarContext()
    local fishCenter, barCenter, barWidth01 = self:_metrics(ctx)
    if not fishCenter then self:Release(); return end

    local s = TUNE.hybrid
    local now = os.clock()

    if self.lastBarRaw  == nil then self.lastBarRaw  = barCenter end
    if self.lastFishRaw == nil then self.lastFishRaw = fishCenter end
    local playerbarVelocity = barCenter - self.lastBarRaw
    self.lastBarRaw  = barCenter
    self.lastFishRaw = fishCenter

    local err = fishCenter - barCenter

    if now < self.trackingWarmupUntil then
        self:_hybridEma(fishCenter, barCenter, now, s)
        local warmupDeadzone = math.max(0.015, barWidth01 * 0.04)
        local hold = err > warmupDeadzone
        if hold then self:Hold() else self:Release() end
        return
    end

    if barCenter < s.EdgeBoundary then
        self:_hybridEma(fishCenter, barCenter, now, s); self:Hold(); return
    end
    if barCenter > 1.0 - s.EdgeBoundary then
        self:_hybridEma(fishCenter, barCenter, now, s); self:Release(); return
    end

    if s.EnableHardCorrection and math.abs(err) > s.CloseThreshold then
        local predictionScale = s.PredictionStrength * (1.0 - s.Resilience)
        local predicted = barCenter + playerbarVelocity * predictionScale
        local predictedError = fishCenter - predicted
        local sameSide = (err * predictedError) > 0
        local approaching = (err * playerbarVelocity) > 0
        local remaining = math.max(0.0, math.abs(err) - s.CloseThreshold)
        local brakeLookahead = math.abs(playerbarVelocity) * 8.0
        local needsPreSlow = approaching and (brakeLookahead >= remaining)
        if sameSide and not needsPreSlow then
            self:_hybridEma(fishCenter, barCenter, now, s)
            if err > 0 then self:Hold() else self:Release() end
            return
        end
    end

    local hold = self:_hybridComputeFine(fishCenter, barCenter, barWidth01, now, s)
    if hold then self:Hold() else self:Release() end
end

function Controller:Update(ctx)
    local mode = MAIN.tracker_mode
    if mode == "predict" then
        return self:UpdatePredict(ctx)
    elseif mode == "hybrid" then
        return self:UpdateHybrid(ctx)
    end
    return self:UpdateSpam(ctx)
end

function RP.getAllReelContexts()
    local pg = getPlayerGui(); if not pg then return {} end
    local out = {}
    local ok, kids = pcall(pg.GetChildren, pg)
    if not ok or not kids then return out end
    for _, ch in ipairs(kids) do
        if ch.Name == "reel" and isScreenGuiEnabled(ch) then
            local bar = findChild(ch, "bar")
            if bar and isGuiVisible(bar) then
                local fish = findChild(bar, "fish")
                local pbar = findChild(bar, "playerbar")
                if fish and pbar and isGuiVisible(fish) and isGuiVisible(pbar) then
                    local x = 0
                    local okP, pos = pcall(_index, bar, "AbsolutePosition")
                    if okP and pos then
                        local okx, px = pcall(_index, pos, "X")
                        if okx and px then x = px end
                    end
                    table.insert(out, { bar = bar, fish = fish, playerbar = pbar, x = x })
                end
            end
        end
    end
    table.sort(out, function(a, b) return a.x < b.x end)
    return out
end

RP.migu = { wasVisible = false, fired = false, fireAt = 0 }

function RP.handleMiguShift()
    local M = RP.migu
    if ROD_KIND ~= "migu" then
        M.wasVisible = false; M.fired = false; M.fireAt = 0
        return
    end
    local reel = getReelGui()
    local ca = reel and findDescendantFrameByName(reel, "counterAttack") or nil
    local visible = (ca and isGuiVisible(ca)) and true or false
    local now = tick() * 1000
    if visible and not M.wasVisible then
        M.wasVisible = true; M.fired = false; M.fireAt = now + 480
        return
    end
    if (not visible) and M.wasVisible then
        M.wasVisible = false; M.fired = false; M.fireAt = 0
        return
    end
    if not visible then return end
    if (not M.fired) and M.fireAt ~= 0 and now >= M.fireAt then
        tapKey(VK.Shift, 30)
        M.fired = true
    end
end

RP.split = { lastClickAt = 0 }

function RP.findSplitbranchTarget()
    local pg = getPlayerGui(); if not pg then return nil end
    local fs = findChild(pg, "FishSelection"); if not fs then return nil end
    local queue, head = { fs }, 1
    while head <= #queue do
        local cur = queue[head]; head = head + 1
        local cls = cur.ClassName or ""
        if cls:find("Button", 1, true) and isGuiVisible(cur) then
            local ok, desc = pcall(cur.GetDescendants, cur)
            if ok and desc then
                for _, d in ipairs(desc) do
                    if (d.ClassName or ""):find("Text", 1, true) then
                        local t = (readGuiText(d) or ""):gsub("%s+", "")
                        if t ~= "" then return cur end
                    end
                end
            end
        end
        local ok2, ch = pcall(cur.GetChildren, cur)
        if ok2 and ch then for _, c in ipairs(ch) do table.insert(queue, c) end end
        if head > 4096 then break end
    end
    return nil
end

function RP.handleSplitbranch()
    if ROD_KIND ~= "splitbranch" then return end
    local now = tick() * 1000
    if now - RP.split.lastClickAt < 700 then return end
    local target = RP.findSplitbranchTarget(); if not target then return end
    local cx, cy = RP.readAbsCenter(target); if not cx then return end
    reliableScreenClick(cx, cy)
    RP.split.lastClickAt = now
end

function RP.getMasterlineOverlayRodNames()
    local pg = getPlayerGui(); if not pg then return {} end
    local hud = findChild(pg, "hud"); if not hud then return {} end
    local frame    = findChild(hud, "Frame")
    local safezone = (frame and findChild(frame, "safezone")) or findChild(hud, "safezone")
    if not safezone then return {} end
    local statuses = findChild(safezone, "statuses"); if not statuses then return {} end

    local masterline
    local ok, kids = pcall(statuses.GetChildren, statuses)
    if ok and kids then
        for _, c in ipairs(kids) do
            if (c.Name or ""):lower():sub(1, 10) == "masterline" then masterline = c; break end
        end
    end
    if not masterline then return {} end

    local tooltip = findChild(masterline, "tooltip"); if not tooltip then return {} end
    local text = normalizeRodText(readGuiText(tooltip))
    if text == "" then return {} end

    local names = {}
    for line in text:gmatch("[^\n]+") do
        line = line:gsub("^%s*•?%s*(.-)%s*$", "%1")
        if line ~= "" then table.insert(names, line) end
    end
    return names
end

function RP.resolveMasterlineKind()
    for _, name in ipairs(RP.getMasterlineOverlayRodNames()) do
        local k = RP.classifyRod(name)
        if k ~= "default" and k ~= "masterline" then return k end
    end
    return "masterline"
end

RP.lullabyModes      = { "prismatic", "resistant", "quickening", "strengthening", "fortuitous" }
RP.lullabyModeLabels = { "Prismatic", "Resistant", "Quickening", "Strengthening", "Fortuitous" }
RP.lullabyBoxes = {
    prismatic     = { {0, 28}, {148, 180} },
    resistant     = { {0, 18}, {80, 100}, {163, 180} },
    quickening    = { {15, 70} },
    strengthening = { {82, 104} },
    fortuitous    = { {116, 180} },
}
RP.lullaby = { inside = { false, false, false }, lastClickAt = 0 }
RP.lullabyMinIntervalMs = 90

function RP.readRotation(inst)
    local a = instAddr(inst); if not a then return nil end
    local ok, v = pcall(memory_read, "float", a + OFFSETS.GuiObjectRotation)
    if ok and type(v) == "number" then return v end
    return nil
end

function RP.getMetronomeTicker()
    local reel = getReelGui();            if not reel then return nil end
    local bar = findChild(reel, "bar");   if not bar then return nil end
    local det = findChild(bar, "Details");if not det then return nil end
    local met = findChild(det, "Metronome"); if not met then return nil end
    return findChild(met, "Ticker")
end

RP._metroRot   = nil
RP._metroMoveAt = 0
function RP.metronomeActive()

    if not reelGuiVisible() then RP._metroRot = nil; return false end
    local t = RP.getMetronomeTicker()
    if not t then RP._metroRot = nil; return false end
    local r = RP.readRotation(t)
    if not r then return false end
    local now = tick() * 1000
    if RP._metroRot == nil or math.abs(r - RP._metroRot) >= 0.5 then
        RP._metroRot = r; RP._metroMoveAt = now
    end
    return (now - RP._metroMoveAt) <= 600
end

function RP.handleLullaby()
    local ticker = RP.getMetronomeTicker()
    if not ticker then
        RP.lullaby.inside[1] = false; RP.lullaby.inside[2] = false; RP.lullaby.inside[3] = false
        return
    end
    local r = RP.readRotation(ticker); if not r then return end
    local boxes = RP.lullabyBoxes[MAIN.lullaby_mode] or RP.lullabyBoxes.prismatic
    local now = tick() * 1000
    for i = 1, 3 do
        local b = boxes[i]
        if b then
            local inside = (r >= b[1] and r <= b[2])

            if inside and not RP.lullaby.inside[i]
               and (now - RP.lullaby.lastClickAt) >= RP.lullabyMinIntervalMs then
                mouse1press(); task.wait(0.03); mouse1release()
                RP.lullaby.lastClickAt = tick() * 1000
            end
            RP.lullaby.inside[i] = inside
        else
            RP.lullaby.inside[i] = false
        end
    end
end

local function resolveWorldStatuses()
    local lp = getLP(); if not lp then return nil end
    local pg = getPlayerGui(); if not pg then return nil end
    local hud = findChild(pg, "hud"); if not hud then return nil end
    local sz  = findChild(hud, "safezone"); if not sz then return nil end
    return findChild(sz, "worldstatuses")
end

local function getWorldStatusText(name)
    local ws = resolveWorldStatuses(); if not ws then return "" end
    local sa = findChild(ws, name);    if not sa then return "" end
    local lb = findChild(sa, "label"); if not lb then return "" end
    local t  = readGuiText(lb)
    return normalizeRodText(t)
end

local function readHotbarItemName(slot)
    local nameInst = findChild(slot, "ItemName"); if not nameInst then return "" end
    return normalizeRodText(readGuiText(nameInst))
end

local function readHotbarItemSlotKey(slot)
    local ok, kids = pcall(slot.GetChildren, slot); if not ok then return "" end
    for _, c in ipairs(kids) do
        if c.ClassName == "TextLabel" and c.Name == "TextLabel" then
            return normalizeRodText(readGuiText(c))
        end
    end
    return ""
end

local function findHotbarItemByName(itemName)
    local hotbar = getHotbarGui(); if not hotbar then return nil end
    local ok, kids = pcall(hotbar.GetChildren, hotbar); if not ok then return nil end
    for _, s in ipairs(kids) do
        if s.ClassName == "ImageButton" and s.Name == "ItemTemplate" then
            if readHotbarItemName(s) == itemName then return s end
        end
    end
    return nil
end

local function getHotbarItemSlotKey(itemName)
    local s = findHotbarItemByName(itemName); if not s then return "" end
    return readHotbarItemSlotKey(s)
end

local function getHotbarTotems()
    local out, seen = {}, {}
    local hotbar = getHotbarGui(); if not hotbar then return out end
    local ok, kids = pcall(hotbar.GetChildren, hotbar); if not ok then return out end
    for _, s in ipairs(kids) do
        if s.ClassName == "ImageButton" and s.Name == "ItemTemplate" then
            local nm = readHotbarItemName(s)
            if nm ~= "" and nm:find("Totem", 1, true) and not seen[nm] then
                seen[nm] = true; table.insert(out, nm)
            end
        end
    end
    return out
end

local function getEquippedToolName()
    local char = getCharacterModel(); if not char then return "" end
    local ok, kids = pcall(char.GetChildren, char); if not ok then return "" end
    for _, c in ipairs(kids) do
        if c.ClassName == "Tool" then return c.Name end
    end
    return ""
end

local function isAnythingEquipped()  return getEquippedToolName() ~= "" end

local function isRodEquipped()
    local equipped = getEquippedToolName(); if equipped == "" then return false end
    local el = equipped:lower()

    if el:find("rod", 1, true) or el:find("aria", 1, true) or el:find("castbound", 1, true) then
        return true
    end

    if ROD ~= "" then
        local sel = normalizeRodText(ROD):lower()
        if sel ~= "" and (sel == el or el:find(sel, 1, true) or sel:find(el, 1, true)) then
            return true
        end
    end
    return false
end

local function ensureRodEquipped()
    if isRodEquipped() then return true end
    return selectHotbarSlot("1")
end

local function tryUseHotbarItem(itemName)
    local slotKey = getHotbarItemSlotKey(itemName)
    if slotKey == "" then return false end
    for _ = 1, 2 do
        local before = getEquippedToolName()
        if before ~= itemName then
            if not selectHotbarSlot(slotKey) then return false end
            task.wait(0.175)
        end
        clickOnce()
        task.wait(0.1)
        local after = getEquippedToolName()
        if after == itemName or before == itemName then return true end
        task.wait(0.125)
    end
    return false
end

local function postWebhook(url, payload)
    if not url or url == "" then return 0 end
    local ok, resp = pcall(function()
        return game:HttpPost(url .. "?with_components=true", payload, "application/json")
    end)
    if ok then return 200 end
    return 0
end

local function joinLines(lines)
    return table.concat(lines, "\n")
end

local function getWebhookAccentColor() return 0x37c8b4 end

local function formatRuntime(ms)
    if ms < 0 then ms = 0 end
    local s = math.floor(ms / 1000)
    local h = math.floor(s / 3600)
    local m = math.floor((s % 3600) / 60)
    local sec = s % 60
    if h > 0 then return string.format("%dh %dm %ds", h, m, sec) end
    if m > 0 then return string.format("%dm %ds", m, sec) end
    return string.format("%ds", sec)
end

local function getTotemStateText()
    if MAIN.auto_totem_enabled == 0 then return "Disabled" end
    local d = MAIN.auto_totem_day or "None"
    local n = MAIN.auto_totem_night or "None"
    if MAIN.auto_totem_mode == "interval" then
        return string.format("Interval %ds (Day:%s / Night:%s)", MAIN.auto_totem_interval_sec, d, n)
    end
    return string.format("On cycle (Day:%s / Night:%s)", d, n)
end

local function buildSummaryPayload()
    local now      = tick() * 1000
    local runtime  = WebhookSession.startedAt > 0 and (now - WebhookSession.startedAt) or 0
    local running  = Macro.cycleEnabled and Macro.phase ~= "OFF"
    local pname = "Player"
    pcall(function() pname = Players.LocalPlayer.Name or "Player" end)

    local inner = {}
    local function line(s) table.insert(inner, { type = 10, content = s }) end
    local function sep()   table.insert(inner, { type = 14 }) end
    local function section(lines) if #lines > 0 then sep(); line(joinLines(lines)) end end

    line(string.format("## %s ZeroDeath fisch — %s", running and "🟢" or "🟡", running and "ACTIVE" or "IDLE"))
    line("**Player:** " .. pname)

    if MAIN.webhook_summary_session_time == 1 then
        local nextMs = math.max(0, (math.max(1, MAIN.webhook_summary_interval_min) * 60000) - (now - WebhookSession.lastSummaryAt))
        section({ string.format("⏱️ **Uptime:** %s    •    **Next update:** %s", formatRuntime(runtime), formatRuntime(nextMs)) })
    end

    local caught, lost = Macro.fishCaughtCount, Macro.fishLostCount
    local catches = {}
    if MAIN.webhook_summary_fish == 1 then
        catches[#catches + 1] = string.format("🎣 **Caught:** %d      ❌ **Lost:** %d", caught, lost)
    end
    if MAIN.webhook_summary_success_rate == 1 then
        local total = caught + lost
        catches[#catches + 1] = string.format("✅ **Success:** %.1f%%", total > 0 and (caught / total) * 100.0 or 0)
    end
    if MAIN.webhook_summary_fish_per_hour == 1 then
        local hrs = runtime / 3600000
        catches[#catches + 1] = string.format("📈 **Fish/hour:** %.1f", hrs > 0.0001 and (caught / hrs) or 0)
    end
    if MAIN.webhook_summary_cast_timeouts == 1 then
        catches[#catches + 1] = string.format("⏳ **Cast timeouts:** %d", Macro.castTimeoutCount)
    end
    if MAIN.webhook_summary_totem_pops == 1 then
        catches[#catches + 1] = string.format("🗿 **Totems popped:** %d", Macro.totemPopCount)
    end
    section(catches)

    local setup = {}
    if MAIN.webhook_summary_rod == 1 then
        setup[#setup + 1] = "🪝 **Rod:** " .. (ROD ~= "" and ROD or "---")
    end
    if MAIN.webhook_summary_tracker == 1 then
        setup[#setup + 1] = "🎛️ **Tracker:** " .. (MAIN.tracker_mode or "?")
    end
    if MAIN.webhook_summary_cycle == 1 then
        local c = (getWorldStatusText("4_cycle") or ""):lower()
        setup[#setup + 1] = "🌗 **Cycle:** " .. (c:find("night", 1, true) and "Night" or (c:find("day", 1, true) and "Day" or "?"))
    end
    if MAIN.webhook_summary_totem_state == 1 then
        setup[#setup + 1] = "🪄 **Auto Totem:** " .. getTotemStateText()
    end
    section(setup)

    local health = {}
    if MAIN.webhook_summary_activity == 1 then
        health[#health + 1] = "💤 **Activity:** " .. (running and Macro.phase or "Idle")
    end
    if MAIN.webhook_summary_mem == 1 and type(gcinfo) == "function" then
        local okM, kb = pcall(gcinfo)
        if okM and kb then health[#health + 1] = string.format("🧠 **Lua:** %d KB", math.floor(kb)) end
    end
    section(health)

    local payload = {
        flags = 32768,
        components = { { type = 17, accent_color = getWebhookAccentColor(), components = inner } }
    }
    return HttpService:JSONEncode(payload)
end

local function sendSummaryWebhook()
    if MAIN.webhook_enabled == 0 then return end
    local url = MAIN.webhook_url; if url == "" then return end

    if WebhookSession.startedAt == 0 then
        WebhookSession.startedAt     = tick() * 1000
        WebhookSession.lastSummaryAt = tick() * 1000
    end
    local interval = math.max(1, MAIN.webhook_summary_interval_min) * 60 * 1000
    if (tick()*1000 - WebhookSession.lastSummaryAt) < interval then return end
    postWebhook(url, buildSummaryPayload())
    WebhookSession.lastSummaryAt = tick() * 1000
end

local function sendInstantAlert(title, desc, color, ping)
    if MAIN.webhook_enabled == 0 then return end
    local url = MAIN.webhook_url; if url == "" then return end
    color = color or getWebhookAccentColor()
    local content = "## " .. title
    if desc and desc ~= "" then content = content .. "\n" .. desc end
    local mentioned = false
    if ping and MAIN.webhook_ping_on_alerts == 1 and (MAIN.webhook_user_id or "") ~= "" then
        content = "<@" .. MAIN.webhook_user_id .. "> " .. content
        mentioned = true
    end
    local payload = {
        flags = 32768,
        components = { { type = 17, accent_color = color, components = { { type = 10, content = content } } } }
    }
    if mentioned then payload.allowed_mentions = { parse = { "users" } } end
    postWebhook(url, HttpService:JSONEncode(payload))
end

local function processWebhookEvents()
    if MAIN.webhook_enabled == 0 or MAIN.webhook_url == "" then return end
    local now = tick() * 1000
    local running = Macro.cycleEnabled and Macro.phase ~= "OFF"

    if running ~= WebhookSession.wasRunning then
        WebhookSession.wasRunning = running
        if running then
            WebhookSession.lastCatchCount = Macro.fishCaughtCount
            WebhookSession.lastCatchAt    = now
            WebhookSession.stallAlerted   = false
            WebhookSession.lastMilestone  = math.floor(Macro.fishCaughtCount / math.max(1, MAIN.webhook_milestone_every))
            if MAIN.webhook_alert_start == 1 then
                sendInstantAlert("🟢 ZeroDeath Started", "Fishing session started.", nil, true)
            end
        elseif MAIN.webhook_alert_stop == 1 then
            sendInstantAlert("🔴 ZeroDeath Stopped", "Fishing session stopped.", 0xe06c6c, true)
        end
    end
    if not running then return end

    if Macro.fishCaughtCount ~= WebhookSession.lastCatchCount then
        WebhookSession.lastCatchCount = Macro.fishCaughtCount
        WebhookSession.lastCatchAt    = now
        WebhookSession.stallAlerted   = false
        if MAIN.webhook_milestone == 1 then
            local every = math.max(1, MAIN.webhook_milestone_every)
            local lvl = math.floor(Macro.fishCaughtCount / every)
            if lvl > WebhookSession.lastMilestone and Macro.fishCaughtCount > 0 then
                WebhookSession.lastMilestone = lvl
                sendInstantAlert("🏆 Milestone", string.format("Caught **%d** fish!", Macro.fishCaughtCount), 0xffcc55, true)
            end
        end
    end

    if MAIN.webhook_alert_stall == 1 and not WebhookSession.stallAlerted and WebhookSession.lastCatchAt > 0 then
        if (now - WebhookSession.lastCatchAt) >= math.max(1, MAIN.webhook_stall_minutes) * 60000 then
            WebhookSession.stallAlerted = true
            sendInstantAlert("⚠️ Possible Stall",
                string.format("No catches in **%d min** — the macro may be stuck.", MAIN.webhook_stall_minutes),
                0xffaa00, true)
        end
    end
end

local HD = { seen = {}, seenCount = 0, primed = false, ec = nil }

HD.hunts = {

    { "Olympian Devil",             "has been summoned",          true  },
    { "Ancient Megalodon",          "has been spotted",           true  },
    { "Phantom Megalodon",          "has been spotted",           true  },
    { "Ancient Kraken",             "has been spotted",           true  },
    { "Profane Leviathan",          "has been summoned",          true  },
    { "Skeletal Leviathan",         "stirs",                      true  },
    { "Awakened Omnithal",          "manifests",                  true  },
    { "Ancient Goldwraith",         "awakens",                    true  },
    { "Colossal Ancient Dragon",    "has begun",                  true  },
    { "Colossal Blue Dragon",       "has begun",                  true  },
    { "Colossal Ethereal Dragon",   "has begun",                  true  },
    { "Livyatan",                   nil,                          true  },
    { "Mosasaurus",                 nil,                          false },
    { "Megalodon",                  "has been spotted",           false },
    { "Kraken",                     "has been spotted",           false },
    { "Leviathan",                  "has been summoned",          false },
    { "Tidecrasher Archon",         "stirs",                      false },
    { "Kerauno Wyrm",               "has emerged",                false },
    { "Legionnaire Lamprey",        "stirs",                      false },
    { "Magician Narwhal",           "has been spotted",           false },
    { "Narwhal",                    "has been spotted",           false },
    { "Beluga",                     "has been spotted",           false },
    { "Mosslurker",                 "has been spotted",           false },
    { "Great White Shark",          "has been spotted",           false },
    { "Great Hammerhead Shark",     "has been spotted",           false },
    { "Whale Shark",                "has been spotted",           false },
    { "Megamouth Shark",            nil,                          false },
    { "Wyvern",                     "has been spotted",           false },
    { "Ancestral Pliosaur",         "stalks",                     false },
    { "Pliosaur",                   "stalks",                     false },
    { "Plesiosaur",                 "prowls",                     false },
    { "Colossus Reef Titan",        "awakens",                    false },
    { "Reef Titan",                 "awakens",                    false },
    { "Elder Mossjaw",              "has emerged",                false },
    { "Mossjaw",                    "has emerged",                false },
    { "Flower Guardian",            "has appeared",               false },
    { "Toxic Guardian",             "has appeared",               false },
    { "Frostwyrm",                  "stirs",                      false },
    { "Scylla",                     "has begun",                  false },
    { "Sovereign Surge",            nil,                          false },
    { "Sovereign Storm",            nil,                          false },
    { "Sovereign Reckoning",        nil,                          false },
    { "Wisp Haunt",                 "The spirits have converged", false },
    { "Soul Scourge",               "The dark spirits surge",     false },
    { "Styx Angler",                "stirs in the dark waters",   false },
    { "Storm Flood",                "The waters are rising",      false },
    { "Solar Chorus",               "blazes through",             false },
    { "Helios Sunray",              "blazes through",             false },
    { "War Surge",                  "The waters run red",         false },
    { "Orca Migration",             "has begun",                  false },
    { "Whale Migration",            "has begun",                  false },
    { "Humpback Whale",             "has begun",                  false },
    { "Ashclaw",                    "Roslit Volcano",             false },
    { "Bloop Fish",                 "has emerged",                false },
    { "Sunken Chests",              nil,                          false },
    { "Earthquake",                 nil,                          false },
}

table.sort(HD.hunts, function(a, b) return #a[1] > #b[1] end)

function HD.matchHunt(textLower, sel)
    for _, h in ipairs(HD.hunts) do
        if sel[h[1]] then
            if textLower:find(h[1]:lower(), 1, true) then
                local phrase = h[2]
                if not phrase or phrase == "" or textLower:find(phrase:lower(), 1, true) then
                    return h[1]
                end
            end
        end
    end
    return nil
end

function HD.selectedSet()
    local set = {}
    for n in (MAIN.hunt_alerts_selected or ""):gmatch("[^,]+") do
        n = n:gsub("^%s*(.-)%s*$", "%1")
        if n ~= "" then set[n] = true end
    end
    return set
end
function HD.selectedList()
    local out = {}
    for n in (MAIN.hunt_alerts_selected or ""):gmatch("[^,]+") do
        n = n:gsub("^%s*(.-)%s*$", "%1")
        if n ~= "" then out[#out + 1] = n end
    end
    return out
end

function HD.allNames()
    local out = {}
    for _, h in ipairs(HD.hunts) do out[#out + 1] = h[1] end
    table.sort(out)
    return out
end

function HD.findDesc(root, name)
    local ok, desc = pcall(root.GetDescendants, root)
    if not (ok and desc) then return nil end
    for _, d in ipairs(desc) do
        local okn, nm = pcall(_index, d, "Name")
        if okn and nm == name then return d end
    end
    return nil
end

function HD.collectChatTexts()
    local out = {}
    local function scanInto(root)
        local ok, desc = pcall(root.GetDescendants, root)
        if not (ok and desc) then return end
        for _, d in ipairs(desc) do
            local okc, cls = pcall(_index, d, "ClassName")
            if okc and cls == "TextLabel" then
                local txt = readGuiText(d)
                if txt and txt ~= "" then out[#out + 1] = txt end
            end
        end
    end

    if not HD.ec then
        local okc, cg = pcall(function() return game:GetService("CoreGui") end)
        if okc and cg then HD.ec = HD.findDesc(cg, "ExperienceChat") end
    end
    if HD.ec then
        local okp = pcall(_index, HD.ec, "Name")
        if okp then scanInto(HD.ec) else HD.ec = nil end
    end

    local pg = getPlayerGui()
    if pg then
        local chat = findChild(pg, "Chat") or findChild(pg, "ChatGui")
        if chat then scanInto(chat) end
    end
    return out
end

function HD.scan()
    if MAIN.hunt_alerts_enabled ~= 1 then HD.primed = false; return end
    if MAIN.webhook_enabled ~= 1 or MAIN.webhook_url == "" then return end
    local texts = HD.collectChatTexts()
    if #texts == 0 then return end
    if HD.seenCount > 400 then HD.seen = {}; HD.seenCount = 0 end
    local sel = HD.selectedSet()
    for _, t in ipairs(texts) do
        if not HD.seen[t] then
            HD.seen[t] = true; HD.seenCount = HD.seenCount + 1

            if HD.primed then
                local name = HD.matchHunt(t:lower(), sel)
                if name then
                    sendInstantAlert("🎯 Hunt: " .. name, t, 0xffaa33, true)
                end
            end
        end
    end
    HD.primed = true
end

local APPRAISE_FIXED_RETRY_MS = 500
local APPRAISE_SUBVALUES_MAX_RETRIES = 5

local function appraiseBaseList()
    local out = {}
    local s = MAIN.auto_appraise_mutations or ""
    if s == "" then s = MAIN.auto_appraise_mutation or "" end
    for m in s:gmatch("[^,]+") do
        m = m:gsub("^%s*(.-)%s*$", "%1")
        if m ~= "" and m ~= "None" then out[#out + 1] = m end
    end
    return out
end

local function findDescendant(root, name, depth)
    if not root or depth <= 0 then return nil end
    local target = name:lower()
    local okC, kids = pcall(root.GetChildren, root)
    if not okC or not kids then return nil end
    for _, ch in ipairs(kids) do
        local okN, nm = pcall(_index, ch, "Name")
        if okN and type(nm) == "string" and nm:lower() == target then return ch end
    end
    for _, ch in ipairs(kids) do
        local hit = findDescendant(ch, name, depth - 1)
        if hit then return hit end
    end
    return nil
end

local function resolveFishInfoSubvalues()
    local char = getCharacterModel(); if not char then return nil end

    local fi   = findChild(char, "fishinfo")
    local info = fi and findChild(fi, "Info")
    local sv   = info and findChild(info, "Subvalues")

    if not sv then sv = findDescendant(char, "Subvalues", 6) end
    Macro.appraiseSubvalues = sv
    return sv
end

local function normalizeAppraiseText(t)
    t = t or ""
    t = t:gsub("\r", "\n")
    t = t:gsub("<[^>]+>", "")
    t = t:gsub("%s+", " ")
    return (t:lower():gsub("^%s*(.-)%s*$", "%1"))
end

local function collectSubvaluesText(root)
    local parts = {}

    local function walk(inst, depth)
        if depth > 8 then return end
        local ok, cls = pcall(_index, inst, "ClassName")
        cls = (ok and cls) or ""
        if cls:find("Text", 1, true) or cls:find("Value", 1, true) then
            local txt = readGuiText(inst)
            if txt ~= "" then parts[#parts + 1] = txt end
        end
        local okC, kids = pcall(inst.GetChildren, inst)
        if okC and kids then for _, ch in ipairs(kids) do walk(ch, depth + 1) end end
    end
    walk(root, 0)
    return table.concat(parts, " ")
end

local function hasDesiredMutation()
    local sv = resolveFishInfoSubvalues()
    if not sv then return nil, "Could not find fishinfo/Info/Subvalues. Hold the fish first." end
    local haystack = normalizeAppraiseText(collectSubvaluesText(sv))

    local needSize = MAIN.auto_appraise_tiny == 1 or MAIN.auto_appraise_small == 1
        or MAIN.auto_appraise_big == 1 or MAIN.auto_appraise_giant == 1
    if needSize then
        local hasSize =
            (MAIN.auto_appraise_tiny  == 1 and haystack:find("tiny",  1, true)) or
            (MAIN.auto_appraise_small == 1 and haystack:find("small", 1, true)) or
            (MAIN.auto_appraise_big   == 1 and haystack:find("big",   1, true)) or
            (MAIN.auto_appraise_giant == 1 and haystack:find("giant", 1, true))
        if not hasSize then return false end
    end

    if MAIN.auto_appraise_shiny == 1     and not haystack:find("shiny",     1, true) then return false end
    if MAIN.auto_appraise_sparkling == 1 and not haystack:find("sparkling", 1, true) then return false end

    local bases = appraiseBaseList()
    if #bases == 0 then return true end
    for _, b in ipairs(bases) do
        if haystack:find(normalizeAppraiseText(b), 1, true) then return true end
    end
    return false
end

local function readCurrentAppraiseCoins()
    local pg = getPlayerGui(); if not pg then return "" end
    local hud = findChild(pg, "hud"); if not hud then return "" end
    local sz  = findChild(hud, "safezone"); if not sz then return "" end
    local c   = findChild(sz, "coins"); if not c then return "" end
    local txt = readGuiText(c)
    local digits = (txt or ""):gsub("%D", "")
    return digits ~= "" and tonumber(digits) or ""
end

local function formatCoins(v)
    if v == "" or v == nil then return "?" end
    v = tonumber(v) or 0
    local sign = v < 0 and "-" or ""
    local s = tostring(math.abs(math.floor(v)))
    local out = ""
    while #s > 3 do
        out = "," .. s:sub(-3) .. out
        s = s:sub(1, -4)
    end
    return sign .. s .. out
end

local appraiseStatus = "Ready."
local function setAppraiseStatus(m) appraiseStatus = m end

local function appraiseTargetsText()
    local t = {}
    for _, b in ipairs(appraiseBaseList())  do table.insert(t, b) end
    if MAIN.auto_appraise_shiny     == 1    then table.insert(t, "Shiny") end
    if MAIN.auto_appraise_sparkling == 1    then table.insert(t, "Sparkling") end
    if MAIN.auto_appraise_big       == 1    then table.insert(t, "Big") end
    if MAIN.auto_appraise_giant     == 1    then table.insert(t, "Giant") end
    if MAIN.auto_appraise_tiny      == 1    then table.insert(t, "Tiny") end
    if MAIN.auto_appraise_small     == 1    then table.insert(t, "Small") end
    return #t == 0 and "target" or table.concat(t, " + ")
end

local function clickAppraisePoint()

    clickOnce()
end

local function completeAppraiseCycle(status)
    Macro.appraiseEndCoins = readCurrentAppraiseCoins()
    Macro.cycleEnabled  = false
    Macro.appraiseState = "DONE"
    Macro.phase         = "DONE"
    setAppraiseStatus(status)
    sendInstantAlert("Appraisal Finished", status)
end

local function failAppraiseCycle(msg)
    Macro.appraiseEndCoins  = readCurrentAppraiseCoins()
    Macro.cycleEnabled      = false
    Macro.appraiseState     = "FAILED"
    Macro.appraiseLastError = msg
    Macro.phase             = "FAILED"
    setAppraiseStatus(msg)
    sendInstantAlert("Appraisal Failed", msg)
end

local function startAppraiseCycle()
    if not isAnythingEquipped() then
        notify("You have to hold a fish to appraise.", "Appraise", 4); return false
    end
    local hasBase  = #appraiseBaseList() > 0
    local hasTrait = MAIN.auto_appraise_shiny == 1 or MAIN.auto_appraise_sparkling == 1
        or MAIN.auto_appraise_tiny == 1 or MAIN.auto_appraise_small == 1
        or MAIN.auto_appraise_big == 1 or MAIN.auto_appraise_giant == 1
    if not (hasBase or hasTrait) then
        setAppraiseStatus("Choose a mutation or trait.")
        notify("Choose a mutation or trait in the Appraise tab.", "Appraise", 4); return false
    end
    releaseMouse(true)
    Macro.appraiseSubvalues = nil
    Macro.appraiseLastClickAt = 0
    Macro.appraiseWaitStartedAt = 0
    Macro.appraiseSubvaluesRetryCount = 0
    Macro.appraiseSubvaluesLastRetryAt = 0
    Macro.appraiseStartCoins = ""
    Macro.appraiseEndCoins   = ""
    Macro.appraiseState      = "RESOLVING"
    Macro.appraiseLastError  = ""
    Macro.phase = "APPRAISE"
    Macro.cycleEnabled = true
    setAppraiseStatus("Resolving fish info...")
    local sv = resolveFishInfoSubvalues()
    if not sv then
        failAppraiseCycle("Could not find Subvalues. Hold the fish before starting.")
        return false
    end
    Macro.appraiseStartCoins = readCurrentAppraiseCoins()
    local has, err = hasDesiredMutation()
    if has == true then
        completeAppraiseCycle(appraiseTargetsText() .. " was already present.")
        return true
    end
    Macro.appraiseState = "CLICK_FIRST"
    setAppraiseStatus("Ready.")
    return true
end

local function stopAppraiseCycle(nextPhase, status)
    nextPhase = nextPhase or "OFF"
    status    = status or "Stopped."
    releaseMouse(true)
    Macro.cycleEnabled = false
    Macro.phase = nextPhase
    if nextPhase == "OFF" then
        Macro.appraiseState = "IDLE"
        Macro.appraiseSubvalues = nil
    else
        Macro.appraiseState = nextPhase
    end
    setAppraiseStatus(status)
end

local function updateAppraisePhase()
    local now = tick() * 1000
    local st  = Macro.appraiseState
    if st == "CLICK_FIRST" then
        setAppraiseStatus("Clicking 1/2.")
        clickAppraisePoint()
        Macro.appraiseLastClickAt = now
        Macro.appraiseState = "CLICK_SECOND"
    elseif st == "CLICK_SECOND" then
        if (now - Macro.appraiseLastClickAt) < MAIN.appraise_delay_ms then return end
        setAppraiseStatus("Clicking 2/2.")
        clickAppraisePoint()
        Macro.appraiseLastClickAt    = now
        Macro.appraiseWaitStartedAt  = now
        Macro.appraiseSubvaluesLastRetryAt = now
        Macro.appraiseState = "WAIT_RESULT"
    elseif st == "WAIT_RESULT" then
        local has, err = hasDesiredMutation()
        if has == true then
            completeAppraiseCycle("Found " .. appraiseTargetsText() .. ".")
            return
        end
        if err then
            if Macro.appraiseSubvaluesLastRetryAt > 0
               and (now - Macro.appraiseSubvaluesLastRetryAt) < APPRAISE_FIXED_RETRY_MS then return end
            Macro.appraiseSubvaluesLastRetryAt = now
            Macro.appraiseSubvaluesRetryCount  = Macro.appraiseSubvaluesRetryCount + 1
            if Macro.appraiseSubvaluesRetryCount <= APPRAISE_SUBVALUES_MAX_RETRIES then
                setAppraiseStatus(string.format("Waiting for Subvalues... %d/%d",
                    Macro.appraiseSubvaluesRetryCount, APPRAISE_SUBVALUES_MAX_RETRIES))
                return
            end
            failAppraiseCycle(err); return
        end
        Macro.appraiseSubvaluesRetryCount = 0
        Macro.appraiseSubvaluesLastRetryAt = 0
        setAppraiseStatus("Still looking for " .. appraiseTargetsText() .. ".")
        Macro.appraiseWaitStartedAt = now
        Macro.appraiseState = "WAIT_RETRY"
    elseif st == "WAIT_RETRY" then
        if (now - Macro.appraiseWaitStartedAt) < MAIN.appraise_delay_ms then return end
        setAppraiseStatus("Retrying.")
        Macro.appraiseWaitStartedAt = 0
        Macro.appraiseState = "CLICK_FIRST"
    end
end

local function getWorldFolder()
    local rs = game:GetService("ReplicatedStorage"); if not rs then return nil end
    local okW, world = pcall(rs.FindFirstChild, rs, "world")
    return (okW and world) or nil
end
local function getWorldValue(name)
    local world = getWorldFolder(); if not world then return "" end
    local okC, node = pcall(world.FindFirstChild, world, name); if not (okC and node) then return "" end
    local okV, v = pcall(_index, node, "Value")
    return (okV and type(v) == "string") and v or ""
end
local function getWorldNested(parent, child)
    local world = getWorldFolder(); if not world then return "" end
    local okP, p = pcall(world.FindFirstChild, world, parent); if not (okP and p) then return "" end
    local okC, node = pcall(p.FindFirstChild, p, child); if not (okC and node) then return "" end
    local okV, v = pcall(_index, node, "Value")
    return (okV and type(v) == "string") and v or ""
end
local function getCurrentWeather() return getWorldValue("weather") end
local function getCurrentEvent()   return getWorldValue("event")   end
local function getCurrentSeason()  return getWorldValue("season")  end

local function getGameCycleIsDay()

    local rs = game:GetService("ReplicatedStorage")
    if rs then
        local okW, world = pcall(rs.FindFirstChild, rs, "world")
        if okW and world then
            local okC, cyc = pcall(world.FindFirstChild, world, "cycle")
            if okC and cyc then
                local okV, v = pcall(_index, cyc, "Value")
                if okV and type(v) == "string" then
                    v = v:lower()
                    if v == "day"   then Macro.cycleLastKnownDay = true;  return true  end
                    if v == "night" then Macro.cycleLastKnownDay = false; return false end
                end
            end
        end
    end

    local lighting = game:GetService("Lighting")
    if lighting then
        local okT, ct = pcall(_index, lighting, "ClockTime")
        if okT and type(ct) == "number" and ct > 0 then
            local isDay = (ct >= 6 and ct < 18)
            Macro.cycleLastKnownDay = isDay
            return isDay
        end
    end

    local cycle = (getWorldStatusText("4_cycle") or ""):lower()
    if cycle:find("night", 1, true) then Macro.cycleLastKnownDay = false; return false end
    if cycle:find("day",   1, true) then Macro.cycleLastKnownDay = true;  return true  end

    if Macro.cycleLastKnownDay ~= nil then return Macro.cycleLastKnownDay end
    return true
end

local WEATHER_VALUES = {
    aurora = { "met", "Aurora Borealis" }, starfall = { "met", "Starfall" },
    rainbow = { "met", "Rainbow" },         eclipse  = { "met", "Eclipse" },
    clear = { "wx", "Clear" }, windy = { "wx", "Windy" }, rain = { "wx", "Rain" }, foggy = { "wx", "Foggy" },
    ["shiny surge"] = { "evt", "Shiny Surge" }, ["mutation surge"] = { "evt", "Mutation Surge" },
    ["night of the luminous"] = { "evt", "Night of the Luminous" },
}
local function weatherActive(key)
    local c = WEATHER_VALUES[key]; if not c then return false end
    local cur
    if c[1] == "met" then cur = getWorldNested("weather", "meteorological")
    elseif c[1] == "evt" then cur = getCurrentEvent()
    else cur = getCurrentWeather() end
    return (cur or ""):lower() == c[2]:lower()
end
local function autoWeatherEnabled()
    return MAIN.auto_weather_enabled == 1 and MAIN.weather_target ~= "none"
        and MAIN.weather_target ~= "" and MAIN.weather_totem ~= ""
end

local function isAutoWeatherDue()
    if not autoWeatherEnabled() then return false end
    if weatherActive(MAIN.weather_target) then return false end
    return (tick() * 1000 - (Macro.lastWeatherAt or 0)) >= math.max(10, MAIN.weather_cooldown_sec) * 1000
end

local function desiredTotemName()

    if Macro.weatherDeployActive and MAIN.weather_totem ~= "" then return MAIN.weather_totem end
    local name = getGameCycleIsDay() and (MAIN.auto_totem_day or "None")
                                      or  (MAIN.auto_totem_night or "None")
    return name or "None"
end

local function autoTotemRuntimeEnabled()
    if autoWeatherEnabled() then return true end
    if MAIN.auto_totem_enabled ~= 1 then return false end
    return (MAIN.auto_totem_day or "None") ~= "None"
        or (MAIN.auto_totem_night or "None") ~= "None"
end
local function autoTotemIntervalMs() return math.max(1, MAIN.auto_totem_interval_sec) * 1000 end
local function cycleStartDelayMs()   return math.max(0, MAIN.pre_cast_delay_ms) end

local function resetAutoTotemControl()
    Macro.totemState               = "IDLE"
    Macro.totemRetryCount          = 0
    Macro.totemWaitStartedAt       = 0
    Macro.totemPending             = false
    Macro.totemBlockedUntilCatchEnd= false
    Macro.totemNeedsRodReequip     = false
    Macro.totemNeedsSettleDelay    = false
end

local function isAutoTotemBoundary()
    return Macro.phase == "CASTING" and not mouseHeld and not Macro.castBarSeen
end

local function isAutoTotemDue()

    if isAutoWeatherDue() then Macro.weatherDeployActive = true; return true end
    Macro.weatherDeployActive = false
    if not autoTotemRuntimeEnabled() then return false end
    if MAIN.auto_totem_mode == "interval" then
        if desiredTotemName() == "None" then return false end
        local ref = math.max(Macro.lastTotemSuccessAt, Macro.lastTotemAttemptAt)
        return ref == 0 or (tick()*1000 - ref) >= autoTotemIntervalMs()
    end

    local cyc = getGameCycleIsDay() and "day" or "night"
    if Macro.totemDeployedCycle == cyc then return false end
    if desiredTotemName() == "None" then
        Macro.totemDeployedCycle = cyc
        return false
    end
    return true
end

local function tryUseAutoTotemItem(name)
    if not name or name == "None" then return false end
    if not tryUseHotbarItem(name) then return false end
    Macro.totemNeedsRodReequip = true
    return true
end

local controller

local function completeAutoTotemWorkflow(success)
    local needsRequip = Macro.totemNeedsRodReequip
    if Macro.weatherDeployActive then Macro.lastWeatherAt = tick() * 1000 end
    Macro.weatherDeployActive = false
    if success then
        Macro.lastTotemSuccessAt = tick() * 1000
        Macro.totemDeployedCycle = getGameCycleIsDay() and "day" or "night"
        Macro.totemPopCount      = Macro.totemPopCount + 1
    elseif MAIN.webhook_alert_totem_failed == 1 then
        sendInstantAlert("Auto Totem Failed", "The auto totem workflow could not complete successfully.")
    end
    resetAutoTotemControl()
    if needsRequip then ensureRodEquipped() end
    if not success and MAIN.auto_totem_mode == "cycle" then
        Macro.totemBlockedUntilCatchEnd = true
    end
    if Macro.cycleEnabled and Macro.phase == "CASTING" then

        Macro.castStartedAt    = tick() * 1000
        Macro.castReleasedAt   = 0
        Macro.castBarSeen      = false
        Macro.completionReached= false
        Macro.outcomeResolved  = false
        Macro.phase            = "CASTING"
    end
end

local function runAutoTotemWorkflowStep()
    local name = desiredTotemName()
    if name == "None" then

        Macro.totemDeployedCycle = getGameCycleIsDay() and "day" or "night"
        completeAutoTotemWorkflow(true)
        return
    end
    if not tryUseAutoTotemItem(name) then completeAutoTotemWorkflow(false); return end
    completeAutoTotemWorkflow(true)
end

local function beginAutoTotemWorkflow()
    Macro.powerPercent          = ""
    Macro.progressPercent       = ""
    Macro.totemPending          = false
    Macro.totemRetryCount       = 0
    Macro.totemWaitStartedAt    = 0
    Macro.lastTotemAttemptAt    = tick() * 1000
    Macro.totemNeedsRodReequip  = false
    releaseMouse()
    if controller then controller:Reset() end
    if Macro.totemNeedsSettleDelay then
        Macro.totemState         = "TOTEM_SETTLE"
        Macro.totemWaitStartedAt = tick() * 1000
        return
    end
    runAutoTotemWorkflowStep()
end

local function updateAutoTotemState()
    if Macro.totemState == "TOTEM_SETTLE" then
        if (tick()*1000 - Macro.totemWaitStartedAt) < cycleStartDelayMs() then return end
        Macro.totemNeedsSettleDelay = false
        Macro.totemWaitStartedAt    = 0
        runAutoTotemWorkflowStep()
    end
end

local function updateAutoTotem()
    if not autoTotemRuntimeEnabled() then
        if Macro.totemState ~= "IDLE" or Macro.totemPending or Macro.totemBlockedUntilCatchEnd then
            releaseMouse(); if controller then controller:Reset() end
            if Macro.totemState ~= "IDLE" and Macro.totemNeedsRodReequip then selectHotbarSlot("1") end
            resetAutoTotemControl()
        end
        return false
    end
    if Macro.totemState ~= "IDLE" then
        Macro.powerPercent = ""; Macro.progressPercent = ""
        releaseMouse(); if controller then controller:Reset() end
        updateAutoTotemState()
        return true
    end
    if not Macro.cycleEnabled then return false end
    if Macro.totemPending and isAutoTotemBoundary() then
        beginAutoTotemWorkflow(); return true
    end
    if Macro.totemBlockedUntilCatchEnd then return false end
    if isAutoTotemDue() then
        if isAutoTotemBoundary() then beginAutoTotemWorkflow(); return true end
        if not Macro.totemPending and Macro.phase ~= "OFF" then
            Macro.totemNeedsSettleDelay = true
        end
        Macro.totemPending = true
    end
    return false
end

controller = Controller.new()

controllerR = Controller.new()
controllerR.button = "rmb"

local function fishingMinigameActive()
    if isTranquilityRod(ROD) and getTranquilityLaneContainer() then return "TRANQUILITY" end
    if reelGuiVisible() and hasActiveFishingContext() then return "FISHING" end
    return nil
end

local function startMacroCycle()
    if Macro.phase == "OFF" then
        Macro.totemNightCovered = false
        Macro.totemDeployedCycle = ""
        Macro.totemPending      = false
        Macro.totemBlockedUntilCatchEnd = false
        if WebhookSession.startedAt == 0 then
            WebhookSession.startedAt    = tick() * 1000
            WebhookSession.lastSummaryAt= tick() * 1000
        end
    end
    DreambreakerActive = (ROD_KIND == "dreambreaker")
    releaseMouse()
    RP.releaseMouse2()
    controller:Reset()
    controllerR:Reset()
    RP.pinionReset()

    if not Macro.ActivatedUiNav then activateUiNav(); Macro.ActivatedUiNav = true; task.wait(0.05) end
    Macro.powerPercent      = ""
    Macro.progressPercent   = ""
    Macro.castStartedAt     = tick() * 1000
    Macro.castReleasedAt    = 0
    Macro.castBarSeen       = false
    Macro.hadMetricsLastTick = false
    Macro.fishInputReadyAt  = 0
    Macro.startupActive     = false
    Macro.fishingLostAt     = 0
    Macro.completionReached = false
    Macro.outcomeResolved   = false
    Macro.lastShakedAt      = 0
    Macro.powerBar          = nil
    Macro.castChargeLastPct  = nil
    Macro.castChargeMotionAt = 0
    Macro.castThreshold     = resolveCastThreshold()
    Macro.castWaitTimeoutMs = math.max(5000, MAIN.cast_timeout_ms)
    Macro.fishingEndGraceMs = 100
    Macro.shakingIntervalMs = MAIN.shake_interval_ms

    Macro.phase             = (MAIN.auto_reel_only == 1) and "REELWATCH" or "CASTING"
end

local function stopMacroCycle(nextPhase)
    nextPhase = nextPhase or "OFF"
    releaseMouse()
    RP.releaseMouse2()
    controller:Reset()
    controllerR:Reset()
    Macro.powerPercent    = ""
    Macro.castStartedAt   = 0
    Macro.castReleasedAt  = 0
    Macro.castBarSeen     = false
    Macro.progressPercent = ""
    Macro.fishingLostAt   = 0
    Macro.completionReached = false
    Macro.outcomeResolved   = false
    Macro.lastShakedAt    = 0
    clearMacroPhaseCache()
    Macro.phase = nextPhase
    if nextPhase == "DONE" then
        Macro.totemBlockedUntilCatchEnd = false
    elseif nextPhase == "OFF" then
        if Macro.totemState ~= "IDLE" and Macro.totemNeedsRodReequip then selectHotbarSlot("1") end
        resetAutoTotemControl()
        Macro.totemNightCovered = false
        Macro.totemDeployedCycle = ""
    end
end

local function resetReelEngine()
    releaseMouse(true); RP.releaseMouse2()
    controller:Reset(); controllerR:Reset()
    Macro.reelSessionActive = false
    Macro.reelSessionStartedAt = 0
    Macro.reelMissingAt = 0
    Macro.reelLastContextAt = 0
    Macro.hadMetricsLastTick = false
    Macro.fishInputReadyAt = 0
    Macro.startupActive = false
    Macro.startupStartedAt = 0
    Macro.startupStartFish = nil
    Macro.fhHoldStartedAt = 0
    Macro.fhMotionAt = 0
    Macro.fhLastFish = nil
    Macro.fhLastBar = nil
    Macro.fhLastProg = nil
    Macro.reelInsaneStreak = 0
    Macro.reelGui = nil; Macro.reelBar = nil; Macro.fishInst = nil
    Macro.playerbar = nil; Macro.progressBar = nil; Macro.reelVerifiedAt = 0
end

local function beginReelEngine()
    resetReelEngine()
    Macro.reelSessionActive = true
    Macro.reelSessionStartedAt = tick() * 1000
    Macro.reelLastContextAt = Macro.reelSessionStartedAt
    Macro.completionReached = false
    Macro.outcomeResolved = false
    Macro.fishingLostAt = 0
end

local function updateReelWatchPhase()
    Macro.powerPercent = ""; Macro.progressPercent = ""
    -- Passive mode: do not touch mouse input while the user casts manually.
end

local function updateCastingPhase()
    Macro.progressPercent = ""
    local delay = cycleStartDelayMs()
    if delay > 0 and (tick()*1000 - Macro.castStartedAt) < delay then return end
    holdMouse()
    if Macro.castStartedAt == 0 then Macro.castStartedAt = tick() * 1000 end
    local bar = resolvePowerBar()
    if not bar then

        local t0 = tick() * 1000
        repeat task.wait(0.002); bar = resolvePowerBar() until bar or (tick()*1000 - t0) >= 12
    end
    if not bar then
        Macro.powerPercent = "---"
        local castAgeMs = tick()*1000 - Macro.castStartedAt

        if not Macro.castBarSeen and castAgeMs >= 2000 then
            Macro.castTimeoutCount = Macro.castTimeoutCount + 1
            if MAIN.cast_on_timeout == 1 then startMacroCycle() else stopMacroCycle("OFF") end
            return
        end
        if castAgeMs >= Macro.castWaitTimeoutMs then
            Macro.castTimeoutCount = Macro.castTimeoutCount + 1
            if MAIN.cast_on_timeout == 1 then startMacroCycle() else stopMacroCycle("OFF") end
        end
        return
    end
    Macro.castBarSeen = true
    local percent = readPowerBarPercent(bar)

    if percent and percent < Macro.castThreshold and percent >= Macro.castThreshold - 15 then
        local t0 = tick() * 1000
        local peak = percent
        repeat
            task.wait(0.002)
            local p = readPowerBarPercent(bar)
            if p then
                percent = p
                if p > peak then peak = p end
                if p >= Macro.castThreshold or p <= peak - 3 then break end
            end
        until (tick()*1000 - t0) >= 45
    end
    local nowMs = tick() * 1000
    if percent then
        Macro.powerPercent = string.format("%.1f", percent)
        if percent >= Macro.castThreshold then
            releaseMouse()
            Macro.castReleasedAt = tick() * 1000
            Macro.phase = "CASTED"
            return
        end
    else

        Macro.powerPercent = "---"
    end

    local moved = (percent ~= nil) and
        (Macro.castChargeLastPct == nil or math.abs(percent - Macro.castChargeLastPct) >= 0.5)
    if moved then Macro.castChargeMotionAt = nowMs end
    Macro.castChargeLastPct = percent
    if Macro.castChargeMotionAt == 0 then Macro.castChargeMotionAt = nowMs end

    if Macro.castBarSeen and (nowMs - Macro.castChargeMotionAt) >= 1200 then
        Macro.castTimeoutCount = Macro.castTimeoutCount + 1
        if MAIN.cast_on_timeout == 1 then startMacroCycle() else stopMacroCycle("OFF") end
        return
    end
    if (nowMs - Macro.castStartedAt) >= Macro.castWaitTimeoutMs then
        Macro.castTimeoutCount = Macro.castTimeoutCount + 1
        if MAIN.cast_on_timeout == 1 then startMacroCycle() else stopMacroCycle("OFF") end
    end
end

local function updateCastedPhase()
    Macro.powerPercent = ""; Macro.progressPercent = ""
    releaseMouse()
    if Macro.castReleasedAt == 0 then Macro.castReleasedAt = tick() * 1000 end
    if (tick()*1000 - Macro.castReleasedAt) < MAIN.post_cast_delay_ms then return end
    Macro.lastShakedAt = 0
    Macro.phase = "SHAKE"
end

local function updateShakePhase()
    Macro.powerPercent = ""; Macro.progressPercent = ""
    releaseMouse()
    if isTranquilityRod(ROD) and getTranquilityLaneContainer() then
        Macro.lastShakedAt = 0; Macro.fishingLostAt = 0
        Macro.phase = "TRANQUILITY"; return
    end
    if hasActiveFishingContext() then
        Macro.lastShakedAt = 0; Macro.fishingLostAt = 0
        Macro.phase = "FISHING"; return
    end
    if Macro.lastShakedAt == 0 or (tick()*1000 - Macro.lastShakedAt) >= Macro.shakingIntervalMs then
        sendEnter()
        Macro.lastShakedAt = tick() * 1000
    end
    if Macro.castReleasedAt > 0 and (tick()*1000 - Macro.castReleasedAt) >= Macro.castWaitTimeoutMs then
        startMacroCycle()
    end
end

local function updateFishingPhase()
    Macro.powerPercent = ""
    local nowMs = tick() * 1000
    local visible = reelGuiVisible()
    local ctx = visible and getReelBarContext() or nil
    local prog = getFishingCompletionPercent()
    Macro.progressPercent = prog and tostring(math.floor(prog + 0.5)) or ""

    if not Macro.reelSessionActive then beginReelEngine() end
    if prog and prog >= MAIN.completion_threshold then Macro.completionReached = true end

    local isMetro = (ROD_KIND == "lullaby") or RP.metronomeActive()
    if MAIN.debug_logging == 1 then Macro.dbgReelVis = visible; Macro.dbgMetro = isMetro end

    if isMetro then
        Macro.reelMissingAt = 0
        Macro.reelLastContextAt = nowMs
        RP.handleLullaby()
        return
    end

    if ROD_KIND == "bellona" and visible then
        local reels = RP.getAllReelContexts()
        Macro.reelMissingAt = 0
        Macro.reelLastContextAt = nowMs
        if #reels >= 2 then
            Macro.bellonaMidX = (reels[1].x + reels[#reels].x) / 2
            controller:Update(reels[1]); controllerR:Update(reels[#reels])
        elseif #reels == 1 then
            local r = reels[1]
            if Macro.bellonaMidX and r.x > Macro.bellonaMidX then
                controllerR:Update(r); releaseMouse(); controller:Reset()
            else
                controller:Update(r); RP.releaseMouse2(); controllerR:Reset()
            end
        else
            releaseMouse(); RP.releaseMouse2()
        end
        return
    end

    if ctx and hasActiveFishingContext(ctx) then
        Macro.reelMissingAt = 0
        Macro.reelLastContextAt = nowMs

        if not Macro.hadMetricsLastTick then
            Macro.hadMetricsLastTick = true
            Macro.fishInputReadyAt = nowMs + 150
            controller:Reset()
            Macro.startupActive = (MAIN.tracker_mode == "predict")
            Macro.startupStartedAt = nowMs
            Macro.startupStartFish = controller:GetFishPosition(ctx)
        end

        if nowMs < Macro.fishInputReadyAt then
            releaseMouse()
            return
        end

        if Macro.startupActive then
            local fc = controller:GetFishPosition(ctx)
            local moved = Macro.startupStartFish and fc and math.abs(fc - Macro.startupStartFish) >= 0.0125
            if moved or (nowMs - Macro.startupStartedAt) >= 650 then
                Macro.startupActive = false
                controller:Reset()
            else
                controller:UpdateSpam(ctx)
                return
            end
        end

        controller:Update(ctx)
        return
    end

    -- Context reads can fail briefly in Matcha. Reacquire before deciding the reel ended.
    releaseMouse(); RP.releaseMouse2()
    controller:Reset(); controllerR:Reset()
    Macro.hadMetricsLastTick = false
    Macro.reelGui = nil; Macro.reelBar = nil; Macro.fishInst = nil
    Macro.playerbar = nil; Macro.progressBar = nil; Macro.reelVerifiedAt = 0

    if visible then
        if Macro.reelMissingAt == 0 then Macro.reelMissingAt = nowMs end
        if (nowMs - Macro.reelMissingAt) < 700 then return end
    else
        if Macro.reelMissingAt == 0 then Macro.reelMissingAt = nowMs end
        local endGrace = Macro.completionReached and 150 or 1200
        if (nowMs - Macro.reelMissingAt) < endGrace then return end
    end

    if not Macro.outcomeResolved then
        Macro.outcomeResolved = true
        if Macro.completionReached then Macro.fishCaughtCount = Macro.fishCaughtCount + 1
        else Macro.fishLostCount = Macro.fishLostCount + 1 end
    end
    resetReelEngine()
    Macro.phase = "DONE"
end

local function updateTranquilityPhase()
    Macro.powerPercent = ""
    local root = getTranquilityRoot()
    local prog = readTranquilityProgressPercent(root)
    Macro.progressPercent = prog and tostring(math.floor(prog + 0.5)) or ""
    if prog and prog >= MAIN.completion_threshold then Macro.completionReached = true end
    local container = root and getTranquilityLaneContainer(root) or nil
    if container then
        Macro.fishingLostAt = 0

        local lanes = { "Lane1", "Lane2", "Lane3", "Lane4" }
        local fallbackKeys = { "A", "S", "D", "F" }
        local HIT_Y_MIN, HIT_Y_MAX = 0.78, 0.90
        for i, name in ipairs(lanes) do
            local lane = findChild(container, name)
            if lane and isGuiVisible(lane) then

                local key = fallbackKeys[i]
                local kl = root and findChild(root, "KeyLabel" .. i) or nil
                if kl then
                    local t = (readGuiText(kl) or ""):gsub("^%s*(.-)%s*$", "%1")
                    if #t == 1 then key = t:upper() end
                end
                local ok, kids = pcall(lane.GetChildren, lane)
                if ok and kids then
                    for _, n in ipairs(kids) do
                        if n.Name == "Note" and n.ClassName == "ImageLabel" and isGuiVisible(n) then
                            local p = readNotePosition(n)
                            if p.sy >= HIT_Y_MIN and p.sy <= HIT_Y_MAX then
                                local vk = key:byte()
                                if vk then tapKey(vk, 20) end
                            end
                        end
                    end
                end
            end
        end
        return
    end
    if Macro.fishingLostAt == 0 then Macro.fishingLostAt = tick() * 1000 end
    if (tick()*1000 - Macro.fishingLostAt) >= Macro.fishingEndGraceMs then
        if not Macro.outcomeResolved then
            Macro.outcomeResolved = true
            if Macro.completionReached then Macro.fishCaughtCount = Macro.fishCaughtCount + 1
            else                            Macro.fishLostCount   = Macro.fishLostCount + 1 end
        end
        stopMacroCycle("DONE")
    end
end

local DBG = { buf = {}, last = nil, lastAt = 0 }
function DBG.tick()
    if MAIN.debug_logging ~= 1 then return end
    local nowMs = tick() * 1000
    local age = (Macro.castStartedAt and Macro.castStartedAt > 0)
        and (math.floor((nowMs - Macro.castStartedAt) / 100) / 10) or -1
    local fmt3 = function(v) return (type(v) == "number") and string.format("%.3f", v) or "-" end
    local fmt0 = function(v) return (type(v) == "number") and string.format("%.0f", v) or "-" end
    local C = controller
    local okA, act = pcall(robloxActive)

    local key = "ph=" .. tostring(Macro.phase)
        .. " mode=" .. tostring(MAIN.tracker_mode)
        .. " m1=" .. tostring(mouseHeld)
        .. " m2=" .. tostring(RP.mouse2Held)
        .. " pwr=" .. tostring(Macro.powerPercent)
        .. " tgt=" .. tostring(Macro.castThreshold)
        .. " prog=" .. tostring(Macro.progressPercent)
        .. " seen=" .. tostring(Macro.castBarSeen)
        .. " act=" .. tostring(okA and act)
        .. " castAge=" .. tostring(age)

        .. " reelVis=" .. tostring(Macro.dbgReelVis)
        .. " fc=" .. fmt3(Macro.dbgFc) .. " bc=" .. fmt3(Macro.dbgBc) .. " bw=" .. fmt3(Macro.dbgBw)

        .. " err=" .. fmt0(C and C.dbgErr) .. " ctrl=" .. fmt0(C and C.dbgControl)
        .. " fv=" .. fmt0(C and C.fishVelEma) .. " bv=" .. fmt0(C and C.barVelEma)
        .. " insane=" .. tostring(Macro.reelInsaneStreak or 0)
        .. " metro=" .. tostring(Macro.dbgMetro)
        .. " reels=" .. tostring(Macro.dbgReels)
        .. " caught=" .. tostring(Macro.fishCaughtCount)
        .. " lost=" .. tostring(Macro.fishLostCount)
        .. " to=" .. tostring(Macro.castTimeoutCount)
        .. " kind=" .. tostring(ROD_KIND)
        .. " totem=" .. tostring(Macro.totemState)
        .. " appr=" .. tostring(Macro.appraiseState)
        .. " rod=" .. tostring(ROD)
        .. " tool=" .. tostring(Macro.dbgTool)
    local holdMs = (Macro.fhHoldStartedAt and Macro.fhHoldStartedAt > 0) and math.floor(nowMs - Macro.fhHoldStartedAt) or 0
    local motMs  = (Macro.fhMotionAt and Macro.fhMotionAt > 0) and math.floor(nowMs - Macro.fhMotionAt) or 0
    local lostMs = (Macro.fishingLostAt and Macro.fishingLostAt > 0) and math.floor(nowMs - Macro.fishingLostAt) or 0

    local line = key .. " holdMs=" .. tostring(holdMs) .. " motMs=" .. tostring(motMs) .. " lostMs=" .. tostring(lostMs)
    local now = tick()
    if key ~= DBG.last or (now - DBG.lastAt) >= 1 then
        DBG.buf[#DBG.buf + 1] = string.format("%.2f %s", now, line)
        DBG.last = key; DBG.lastAt = now
        if #DBG.buf > 1500 then table.remove(DBG.buf, 1) end
    end
end

local function macroTick()
    DBG.tick()

    if not robloxActive() then releaseMouse(true); return end
    if Macro.phase ~= "APPRAISE" and updateAutoTotem() then return end

    if Macro.cycleEnabled and Macro.phase ~= "APPRAISE" and RP.metronomeActive() then
        Macro.phase = "FISHING"
        Macro.fishingLostAt = 0
        local prog = getFishingCompletionPercent()
        Macro.progressPercent = prog and tostring(math.floor(prog + 0.5)) or ""
        if prog and prog >= MAIN.completion_threshold then Macro.completionReached = true end
        releaseMouse()
        RP.handleLullaby()
        return
    end

    if Macro.cycleEnabled then
        local ph = Macro.phase
        if ph == "CASTING" or ph == "CASTED" or ph == "SHAKE" or ph == "REELWATCH" then
            local mg = fishingMinigameActive()
            if mg and mg ~= ph then
                beginReelEngine()
                Macro.lastShakedAt = 0; Macro.fishingLostAt = 0
                Macro.phase = mg
            elseif (ph == "CASTING" or ph == "CASTED") and RP.shakeButtonVisible() then

                releaseMouse(true)
                Macro.lastShakedAt = 0; Macro.fishingLostAt = 0
                Macro.phase = "SHAKE"
            end
        end
    end

    if Macro.cycleEnabled then
        RP.handleMiguShift()
        RP.handleSplitbranch()
    end

    if MAIN.watchdog_enabled == 1 and Macro.cycleEnabled then
        local wp = Macro.phase
        if wp ~= "OFF" and wp ~= "APPRAISE" and wp ~= "REELWATCH" and Macro.totemState == "IDLE" then
            local wnow = tick() * 1000

            local sig = wp .. Macro.powerPercent .. Macro.progressPercent
                .. Macro.fishCaughtCount .. Macro.fishLostCount
            if sig ~= Macro.wdSig then Macro.wdSig = sig; Macro.wdSignalAt = wnow end
            if Macro.wdSignalAt == 0 then Macro.wdSignalAt = wnow end

            if (wp == "FISHING" or wp == "TRANQUILITY") and fishingMinigameActive() then
                Macro.wdSignalAt = wnow
            end

            if (wp == "CASTING" or wp == "CASTED" or wp == "SHAKE")
               and wnow - Macro.wdRodCheckAt >= 1200 then
                Macro.wdRodCheckAt = wnow

                if not isAnythingEquipped() then
                    Macro.wdRodStreak = Macro.wdRodStreak + 1
                    if Macro.wdRodStreak >= 3 and wnow - Macro.wdRodEquipAt >= 1500 then
                        ensureRodEquipped(); Macro.wdRodEquipAt = wnow
                    end
                else
                    Macro.wdRodStreak = 0
                end
            end

            if (wnow - Macro.wdSignalAt) >= math.max(8, MAIN.watchdog_stall_sec) * 1000
               and (wnow - Macro.wdRecoveryAt) >= 10000 then
                Macro.wdRecoveryAt = wnow; Macro.wdSignalAt = wnow
                releaseMouse(true); RP.releaseMouse2()
                controller:Reset(); controllerR:Reset()

                clearMacroPhaseCache()
                ensureRodEquipped()
                startMacroCycle()
                notify("Watchdog: recovered from a stall.", "ZeroDeath fisch", 3)
                return
            end
        end
    end

    local p = Macro.phase
    if     p == "CASTING"     then updateCastingPhase()
    elseif p == "CASTED"      then updateCastedPhase()
    elseif p == "SHAKE"       then updateShakePhase()
    elseif p == "REELWATCH"   then updateReelWatchPhase()
    elseif p == "FISHING"     then updateFishingPhase()
    elseif p == "TRANQUILITY" then updateTranquilityPhase()
    elseif p == "DONE"        then
        if not Macro.cycleEnabled then
            stopMacroCycle("OFF")
        elseif MAIN.auto_reel_only == 1 then
            resetReelEngine()
            Macro.powerPercent = ""; Macro.progressPercent = ""
            Macro.completionReached = false; Macro.outcomeResolved = false
            Macro.phase = "REELWATCH"
        else
            startMacroCycle()
        end
    elseif p == "APPRAISE"    then updateAppraisePhase()
    end
end

local function startMacro()
    if Macro.cycleEnabled then
        Macro.cycleEnabled = false
        if Macro.phase == "APPRAISE" then stopAppraiseCycle("OFF") else stopMacroCycle("OFF") end
        notify("Macro stopped.", "ZeroDeath fisch", 2)
        return
    end
    if MAIN.auto_appraise_enabled == 1 then
        if Macro.phase == "OFF" or Macro.phase == "DONE" or Macro.phase == "FAILED" then
            startAppraiseCycle()
        end
        return
    end
    if not isAnythingEquipped() then
        sendT(); task.wait(0.2)
    end
    Macro.cycleEnabled = true
    if Macro.phase == "OFF" or Macro.phase == "DONE" or Macro.phase == "FAILED" then
        startMacroCycle()
    end
    notify("Macro started.", "ZeroDeath fisch", 2)
end

local function stopAppraisingHotkey()
    if Macro.phase == "APPRAISE" and Macro.cycleEnabled then
        stopAppraiseCycle("OFF", "Stopped by hotkey.")
    end
end

local function appraiseHotkey()
    if Macro.cycleEnabled then
        if Macro.phase == "APPRAISE" then
            stopAppraiseCycle("OFF", "Appraise stopped by hotkey.")
        else
            notify("Stop the fishing macro before appraising.", "Appraise", 3)
        end
        return
    end
    startAppraiseCycle()
end

local function fixAttach()

    clearMacroPhaseCache()
    ROD = getHotbarRodName()
    notify("Refreshed. Rod = " .. (ROD ~= "" and ROD or "?"), "ZeroDeath fisch", 3)
end

local function reloadMacro()
    stopMacroCycle("OFF")
    saveSettings()
    notify("Stopped. Re-run the script to reload.", "ZeroDeath fisch", 4)
end

TP.PLACES_PATH = "C:/matcha/workspace/zerodeath_places.json"

TP.EXCLUDE = {
    ["TeleportDelay"] = true, ["loading"] = true, ["TpSpots"] = true,
    ["Customizing"] = true, ["boatspawns"] = true,
}

TP.places = {}
TP.status = "Pick a destination."

function TP.spawnsFolder()
    local ws = getWorkspaceRoot(); if not ws then return nil end
    local world = findChild(ws, "world"); if not world then return nil end
    return findChild(world, "spawns")
end

function TP.partXYZ(inst)
    if not inst then return nil end
    local ok, p = pcall(_index, inst, "Position")
    if not (ok and p) then return nil end
    local okx, x = pcall(_index, p, "X")
    local oky, y = pcall(_index, p, "Y")
    local okz, z = pcall(_index, p, "Z")
    if not (okx and oky and okz) then return nil end
    if type(x) ~= "number" or type(y) ~= "number" or type(z) ~= "number" then return nil end
    if x ~= x or y ~= y or z ~= z then return nil end
    if x == math.huge or x == -math.huge then return nil end
    return x, y, z
end

function TP.resolveXYZ(inst, depth)
    local x, y, z = TP.partXYZ(inst)
    if x then return x, y, z end
    depth = depth or 3
    if depth <= 0 then return nil end
    local okc, children = pcall(function() return inst:GetChildren() end)
    if not (okc and children) then return nil end
    for _, c in ipairs(children) do
        local cx, cy, cz = TP.partXYZ(c)
        if cx then return cx, cy, cz end
    end
    for _, c in ipairs(children) do
        local cx, cy, cz = TP.resolveXYZ(c, depth - 1)
        if cx then return cx, cy, cz end
    end
    return nil
end

function TP.scan()
    local folder = TP.spawnsFolder()
    if not folder then
        TP.status = "world/spawns not found (are you in Fisch?)."
        return 0
    end
    local okc, children = pcall(function() return folder:GetChildren() end)
    if not (okc and children) then
        TP.status = "Could not read world/spawns children."
        return 0
    end
    local out, seen = {}, {}
    for _, c in ipairs(children) do
        local nm = "?"
        local okn, n = pcall(_index, c, "Name")
        if okn and type(n) == "string" then nm = n end
        if not TP.EXCLUDE[nm] and not seen[nm] then
            local x, y, z = TP.resolveXYZ(c, 3)
            if x then
                seen[nm] = true
                out[#out + 1] = { name = nm, x = x, y = y, z = z }
            end
        end
    end
    table.sort(out, function(a, b) return a.name < b.name end)
    TP.places = out
    TP.status = (#out > 0) and ("Found " .. #out .. " locations.")
                            or "No locations found under world/spawns."

    local okJ, js = pcall(function() return HttpService:JSONEncode(out) end)
    if okJ and js then pcall(writefile, TP.PLACES_PATH, js) end
    return #out
end

function TP.names()
    if #TP.places == 0 then return { "(scan first)" } end
    local t = {}
    for i, p in ipairs(TP.places) do t[i] = p.name end
    return t
end

function TP.byName(name)
    for _, p in ipairs(TP.places) do if p.name == name then return p end end
    return nil
end

function TP.teleport(name)
    if Macro.cycleEnabled and Macro.phase ~= "OFF" and Macro.phase ~= "DONE"
       and Macro.phase ~= "FAILED" then
        TP.status = "Stop the macro (F1) before teleporting."
        notify(TP.status, "ZeroDeath Teleport", 4)
        return false
    end
    local place = TP.byName(name)
    if not place then
        TP.status = "Pick a location first."
        notify(TP.status, "ZeroDeath Teleport", 3)
        return false
    end

    local char = getCharacterModel()
    local hrp  = char and findChild(char, "HumanoidRootPart")
    if not hrp then
        TP.status = "No character/HRP — respawn and retry."
        notify(TP.status, "ZeroDeath Teleport", 4)
        return false
    end

    local ok = pcall(function()
        hrp.CFrame = CFrame.new(place.x, place.y, place.z)
    end)
    if ok then
        TP.status = string.format("Teleported to %s (%.0f, %.0f, %.0f).",
            place.name, place.x, place.y, place.z)
        notify(TP.status, "ZeroDeath Teleport", 3)
        return true
    end
    TP.status = "Teleport write failed (CFrame blocked?)."
    notify(TP.status, "ZeroDeath Teleport", 4)
    return false
end

TP.spots = {
    altar       = CFrame.new(1296.320068359375, -808.5519409179688, -298.93817138671875),
    arch        = CFrame.new(998.966796875, 126.6849365234375, -1237.1434326171875),
    birch       = CFrame.new(1742.3203125, 138.25787353515625, -2502.23779296875),
    brine       = CFrame.new(-1794.10596, -145.849701, -3302.92358),
    deep        = CFrame.new(-1510.88672, -237.695053, -2852.90674),
    deepshop    = CFrame.new(-979.196411, -247.910156, -2699.87207),
    enchant     = CFrame.new(1296.320068359375, -808.5519409179688, -298.93817138671875),
    executive   = CFrame.new(-29.836761474609375, -250.48486328125, 199.11614990234375),
    keepers     = CFrame.new(1296.320068359375, -808.5519409179688, -298.93817138671875),
    mod_house   = CFrame.new(-30.205902099609375, -249.40594482421875, 204.0529022216797),
    moosewood   = CFrame.new(383.10113525390625, 131.2406005859375, 243.93385314941406),
    mushgrove   = CFrame.new(2501.48583984375, 127.7583236694336, -720.699462890625),
    roslit      = CFrame.new(-1476.511474609375, 130.16842651367188, 671.685302734375),
    snow        = CFrame.new(2648.67578125, 139.06605529785156, 2521.29736328125),
    snowcap     = CFrame.new(2648.67578125, 139.06605529785156, 2521.29736328125),
    spike       = CFrame.new(-1254.800537109375, 133.88555908203125, 1554.2021484375),
    statue      = CFrame.new(72.8836669921875, 138.6964874267578, -1028.4193115234375),
    sunstone    = CFrame.new(-933.259705, 128.143951, -1119.52063),
    swamp       = CFrame.new(2501.48583984375, 127.7583236694336, -720.699462890625),
    terrapin    = CFrame.new(-143.875244140625, 141.1676025390625, 1909.6070556640625),
    trident     = CFrame.new(-1479.48987, -228.710632, -2391.39307),
    vertigo     = CFrame.new(-112.007278, -492.901093, 1040.32788),
    volcano     = CFrame.new(-1888.52319, 163.847565, 329.238281),
    wilson      = CFrame.new(2938.80591, 277.474762, 2567.13379),
    wilsons_rod = CFrame.new(2879.2085, 135.07663, 2723.64233),

    ["Abyssal Zenith"]                        = CFrame.new(-13485.124, -10875.649, 70.075),
    ["Calm Zone - fishing pool"]              = CFrame.new(-4325.206, -11171.294, 3737.907),
    ["Calm Zone - spawn point"]               = CFrame.new(-4234.795, -11200.649, 1814.596),
    ["Challengers Deep"]                      = CFrame.new(-865.473, -3210.099, -814.335),
    ["Northern expedition - Cryogenic Canal"] = CFrame.new(20213.076, 854.427, 5593.708),
    ["Northern expedition - Frigid cavern"]   = CFrame.new(19721.463, 415.062, 5469.552),
    ["Northern expedition - Glacial Grotto"]  = CFrame.new(20006.215, 1137.012, 5395.009),
    ["Northern expedition - summit"]          = CFrame.new(19711.629, 183.91, 5294.101),
    ["Treasure Island"]                       = CFrame.new(8245.389, 207.2, -17204.143),
    ["Veil Of Forsaken"]                      = CFrame.new(-2654.264, -11134.451, 6790.002),
    ["Volcanic Vents"]                        = CFrame.new(-3599.561, -2244.869, 3868.001),

    ["Ancient Isle"]                          = CFrame.new(6136.2, 226.5, 301.5),
    ["Atlantis"]                              = CFrame.new(4292.1, -610.2, 1809.4),
    ["Boreal Pines"]                          = CFrame.new(21404.9, 185.1, 4052.3),
    ["Castaway Cliffs"]                       = CFrame.new(661.9, 132.8, -1713.7),
    ["Cursed Isle"]                           = CFrame.new(1857.9, 119.5, 1154.3),
    ["Everturn Forest"]                       = CFrame.new(2452.7, 140.3, -2387.1),
    ["Forsaken Shores"]                       = CFrame.new(-2903.6, 316.7, 1647.3),
    ["Grand Reef"]                            = CFrame.new(-3584.6, 133.0, 558.2),
    ["Lost Jungle"]                           = CFrame.new(-2736.9, 164.2, -2172.7),
    ["Scoria Reach"]                          = CFrame.new(-4745.5, 138.9, -1406.0),
    ["Tidefall"]                              = CFrame.new(3008.2, -1071.2, 748.2),
    ["Aether"]                                = CFrame.new(-24.0, -632.9, 880.8),
    ["Ancient Archives"]                      = CFrame.new(-3150.1, -747.2, 1638.1),
}
TP.fishAreas = {
    Roslit_Bay               = CFrame.new(-1663.73889, 149.234116, 495.498016),
    Ocean                    = CFrame.new(7665.104, 125.444443, 2601.59351),
    Snowcap_Pond             = CFrame.new(2778.09009, 283.283783, 2580.323),
    Moosewood_Docks          = CFrame.new(343.2359924316406, 133.61595153808594, 267.0580139160156),
    Deep_Ocean               = CFrame.new(3569.07153, 125.480949, 6697.12695),
    Vertigo                  = CFrame.new(-137.697098, -736.86377, 1233.15271),
    Snowcap_Ocean            = CFrame.new(3088.66699, 131.534332, 2587.11304),
    Harvesters_Spike         = CFrame.new(-1234.61523, 125.228767, 1748.57166),
    SunStone                 = CFrame.new(-845.903992, 133.172211, -1163.57776),
    Roslit_Bay_Ocean         = CFrame.new(-1708.09302, 155.000015, 384.928009),
    Moosewood_Pond           = CFrame.new(509.735992, 152.000031, 302.173004),
    Terrapin_Ocean           = CFrame.new(58.6469994, 135.499985, 2147.41699),
    Isonade                  = CFrame.new(-1060.99902, 121.164787, 953.996033),
    Moosewood_Ocean          = CFrame.new(-167.642715, 125.19548, 248.009521),
    Roslit_Pond              = CFrame.new(-1811.96997, 148.047089, 592.642517),
    Moosewood_Ocean_Mythical = CFrame.new(252.802994, 135.849625, 36.8839989),
    Terrapin_Olm             = CFrame.new(22.0639992, 182.000015, 1944.36804),
    The_Arch                 = CFrame.new(1283.30896, 130.923569, -1165.29602),
    Scallop_Ocean            = CFrame.new(23.2255898, 125.236847, 738.952271),
    SunStone_Hidden          = CFrame.new(-1139.55701, 134.62204, -1076.94324),
    Mushgrove_Stone          = CFrame.new(2525.36011, 131.000015, -776.184021),
    Keepers_Altar            = CFrame.new(1307.13599, -805.292236, -161.363998),
    Lava                     = CFrame.new(-1959.86206, 193.144821, 271.960999),
    Roslit_Pond_Seaweed      = CFrame.new(-1785.2869873046875, 148.15780639648438, 639.9299926757812),
}
TP.npcs = {
    Witch          = CFrame.new(409.638092, 134.451523, 311.403687),
    Quiet_Synph    = CFrame.new(566.263245, 152.000031, 353.872101),
    Pierre         = CFrame.new(391.38855, 135.348389, 196.712387),
    Phineas        = CFrame.new(469.912292, 150.69342, 277.954987),
    Paul           = CFrame.new(381.741882, 136.500031, 341.891022),
    Shipwright     = CFrame.new(357.972595, 133.615967, 258.154541),
    Angler         = CFrame.new(480.102478, 150.501053, 302.226898),
    Marc           = CFrame.new(466.160034, 151.00206, 224.497086),
    Lucas          = CFrame.new(449.33963, 181.999893, 180.689072),
    Latern_Keeper  = CFrame.new(-39.0456772, -246.599976, 195.644363),
    Latern_Keeper2 = CFrame.new(-17.4230175, -304.970276, -14.529892),
    Inn_Keeper     = CFrame.new(487.458466, 150.800034, 231.498932),
    Roslit_Keeper  = CFrame.new(-1512.37891, 134.500031, 631.24353),
    FishingNpc_1   = CFrame.new(-1429.04138, 134.371552, 686.034424),
    FishingNpc_2   = CFrame.new(-1778.55408, 149.791779, 648.097107),
    FishingNpc_3   = CFrame.new(-1778.26807, 147.83165, 653.258606),
    Henry          = CFrame.new(483.539307, 152.383057, 236.296143),
    Daisy          = CFrame.new(581.550049, 165.490753, 213.499969),
    Appraiser      = CFrame.new(453.182373, 150.500031, 206.908783),
    Merchant       = CFrame.new(416.690521, 130.302628, 342.765289),
    Mod_Keeper     = CFrame.new(-39.0905838, -245.141144, 195.837891),
    Ashe           = CFrame.new(-1709.94055, 149.862411, 729.399536),
    Alfredrickus   = CFrame.new(-1520.60632, 142.923264, 764.522034),
}
TP.items = {
    Training_Rod       = CFrame.new(457.693848, 148.357529, 230.414307),
    Plastic_Rod        = CFrame.new(454.425385, 148.169739, 229.172424),
    Lucky_Rod          = CFrame.new(446.085999, 148.253006, 222.160004),
    Kings_Rod          = CFrame.new(1375.57642, -810.201721, -303.509247),
    Flimsy_Rod         = CFrame.new(471.107697, 148.36171, 229.642441),
    Nocturnal_Rod      = CFrame.new(-141.874237, -515.313538, 1139.04529),
    Fast_Rod           = CFrame.new(447.183563, 148.225739, 220.187454),
    Carbon_Rod         = CFrame.new(454.083618, 150.590073, 225.328827),
    Long_Rod           = CFrame.new(485.695038, 171.656326, 145.746109),
    Mythical_Rod       = CFrame.new(389.716705, 132.588821, 314.042847),
    Midas_Rod          = CFrame.new(401.981659, 133.258316, 326.325745),
    Trident_Rod        = CFrame.new(-1484.34192, -222.325562, -2194.77002),
    Enchated_Altar     = CFrame.new(1310.54651, -799.469604, -82.7303467),
    Bait_Crate         = CFrame.new(384.57513427734375, 135.3519287109375, 337.5340270996094),
    Quality_Bait_Crate = CFrame.new(-177.876, 144.472, 1932.844),
    Crab_Cage          = CFrame.new(474.803589, 149.664566, 229.49469),
    GPS                = CFrame.new(517.896729, 149.217636, 284.856842),
    Basic_Diving_Gear  = CFrame.new(369.174774, 132.508835, 248.705368),
    Fish_Radar         = CFrame.new(365.75177, 134.50499, 274.105804),
}

TP.cats = {}
do
    local function build(tbl)
        local names, map = {}, {}
        for k, cf in pairs(tbl) do

            local nice = (tostring(k):gsub("_", " "))
            nice = (nice:gsub("(%a)([%w]*)", function(a, b) return a:upper() .. b end))
            names[#names + 1] = nice
            map[nice] = cf
        end
        table.sort(names)
        return names, map
    end
    local defs = {
        { "items", "Items", TP.items }, { "npcs", "NPCs", TP.npcs },
        { "fishAreas", "Fish Areas", TP.fishAreas }, { "spots", "Spots", TP.spots },
    }
    for _, d in ipairs(defs) do
        local nm, mp = build(d[3])
        TP.cats[d[1]] = { label = d[2], names = nm, map = mp }
    end
end

function TP.go(label, cf)
    if Macro.cycleEnabled and Macro.phase ~= "OFF" and Macro.phase ~= "DONE"
       and Macro.phase ~= "FAILED" then
        TP.status = "Stop the macro (F1) before teleporting."
        notify(TP.status, "ZeroDeath Teleport", 4)
        return false
    end
    if not cf then
        TP.status = "Pick a destination first."
        notify(TP.status, "ZeroDeath Teleport", 3)
        return false
    end

    local char = getCharacterModel()
    local hrp  = char and findChild(char, "HumanoidRootPart")
    if not hrp then
        TP.status = "No character/HRP — respawn and retry."
        notify(TP.status, "ZeroDeath Teleport", 4)
        return false
    end
    local ok = pcall(function() hrp.CFrame = cf end)
    if ok then
        TP.status = "Teleported to " .. tostring(label) .. "."
        notify(TP.status, "ZeroDeath Teleport", 3)
        return true
    end
    TP.status = "Teleport write failed (CFrame blocked?)."
    notify(TP.status, "ZeroDeath Teleport", 4)
    return false
end

local HUNT = {}
HUNT.active     = {}
HUNT.lastScanAt = 0
HUNT.scanning   = false
HUNT.forceScan  = false
HUNT.detected   = nil

HUNT.KNOWN = {
    "Baby Bloop Fish","Bloop Fish","Profane Leviathan","Elder Mossjaw","Colossal Ancient Dragon",
    "Colossal Blue Dragon","Colossal Ethereal Dragon","Dreadfin","Flower Guardian","Frostwyrm",
    "Goldwraith","Beluga","Helios Sunray","Humpback Whale Migration","Kerauno Wyrm","Kraken",
    "Legionnaire Lamprey","Leviathan","Megalodon","Megamouth Shark","Mossjaw","Mosslurker",
    "Olympian Devil","Omnithal","Orca Migration","Plesiosaur","Pliosaur","Reef Titan","Rotbloom",
    "Scylla","Sea Leviathan","Shark","Skeletal Leviathan","Styx Angler","Tidecrasher Archon",
    "Toxic Guardian","Whale Migration","Wyvern","Whale Shark","Great White Shark","Awakened Omnithal",
    "Ancient Megalodon","Livyatan","The Depths - Serpent","Nectar Den - Serpent",
    "Great Hammerhead Shark","Brine Storm",
}

HUNT.ALIASES = {
    ["nectar den - serpent"]   = { name = "Nectar Den - Serpent", zone = "Nectar Den" },
    ["the depths - serpent"]   = { name = "The Depths - Serpent", zone = "The Depths" },
    ["forsaken veil - scylla"] = { name = "Scylla",               zone = "Veil of the Forsaken" },
    ["brine storm"]            = { name = "Brine Storm",          zone = "Desolate Deep" },
}

local function huntKnownName(nm)
    nm = (nm or ""):lower()
    for _, h in ipairs(HUNT.KNOWN) do if h:lower() == nm then return h end end
    return nil
end

function HUNT.classify(name)
    if not name or name == "" then return nil end
    local lc = name:lower()
    local a = HUNT.ALIASES[lc]; if a then return a.name, a.zone end
    local k = huntKnownName(name); if k then return k, "Hunt in progress" end
    if lc:sub(1, 5) == "fish_" then local kk = huntKnownName(name:sub(6)); if kk then return kk, "Hunt in progress" end end
    if #lc > 5 and lc:sub(-5) == " hunt"    then local kk = huntKnownName(name:sub(1, #name - 5)); if kk then return kk, "Hunt in progress" end end
    if #lc > 8 and lc:sub(-8) == " default" then local kk = huntKnownName(name:sub(1, #name - 8)); if kk then return kk, "Hunt in progress" end end
    if lc == "orca" or lc == "ancient orca" then return "Orca Migration", "Hunt in progress" end
    if lc == "whale"          then return "Whale Migration", "Hunt in progress" end
    if lc == "humpback whale" then return "Humpback Whale Migration", "Hunt in progress" end
    return nil
end

function HUNT.scan()
    if HUNT.scanning then return HUNT.active end
    HUNT.scanning = true
    local out, seen, budget = {}, {}, 0
    local function walk(inst, depth)
        if depth > 15 or budget > 80000 then return end
        local okCh, children = pcall(inst.GetChildren, inst)
        if not okCh or type(children) ~= "table" then return end
        for _, c in ipairs(children) do
            budget = budget + 1
            if budget % 40 == 0 then task.wait() end
            if budget > 80000 then return end
            local okN, nm = pcall(_index, c, "Name")
            nm = (okN and type(nm) == "string") and nm or ""
            if nm ~= "" and nm ~= "Camera" and nm ~= "Terrain" and nm ~= "world" then
                local creature, zone = HUNT.classify(nm)
                if creature and not seen[creature] then

                    local okCl, cn = pcall(_index, c, "ClassName")
                    cn = (okCl and cn) or ""
                    if cn == "Model" or cn == "Part" or cn == "MeshPart" then
                        local okP, x, y, z = pcall(TP.resolveXYZ, c, 3)
                        seen[creature] = true
                        out[#out + 1] = {
                            name = creature, location = zone or "Hunt in progress",
                            x = okP and x or 0, y = okP and y or 0, z = okP and z or 0,
                        }
                    end
                end
                walk(c, depth + 1)
            end
        end
    end
    local ws = nil
    pcall(function() ws = workspace end)
    if ws then pcall(walk, ws, 0) end
    HUNT.active     = out
    HUNT.lastScanAt = tick() * 1000
    HUNT.lastBudget = budget
    HUNT.scanning   = false
    return out
end

function HUNT.teleportTo(name)
    if Macro.cycleEnabled and Macro.phase ~= "OFF" and Macro.phase ~= "DONE" and Macro.phase ~= "FAILED" then
        notify("Stop the macro (F1) before teleporting to a hunt.", "ZeroDeath Hunt", 4); return false
    end
    local h
    for _, e in ipairs(HUNT.active) do if e.name == name then h = e; break end end
    if not h or not h.x or (h.x == 0 and h.y == 0 and h.z == 0) then
        notify("That hunt has no readable position yet — rescan.", "ZeroDeath Hunt", 3); return false
    end
    local char = getCharacterModel()
    local hrp  = char and findChild(char, "HumanoidRootPart")
    if not hrp then notify("No character/HRP — respawn and retry.", "ZeroDeath Hunt", 4); return false end
    local ok = pcall(function() hrp.CFrame = CFrame.new(h.x, h.y + 8.0, h.z) end)
    if ok then notify("Teleported to " .. h.name .. " (" .. h.location .. ").", "ZeroDeath Hunt", 3); return true end
    notify("Hunt teleport failed (CFrame blocked?).", "ZeroDeath Hunt", 4); return false
end

function HUNT.detectTick()
    if MAIN.hunt_detect_enabled ~= 1 then HUNT.detected = nil; return end
    local target = (MAIN.hunt_detect_target or ""):lower()
    if target == "" then HUNT.detected = nil; return end
    for _, e in ipairs(HUNT.active) do
        if e.name:lower():find(target, 1, true) then
            if HUNT.detected ~= e.name then
                HUNT.detected = e.name
                notify("Hunt detected: " .. e.name .. " (" .. e.location .. ")", "ZeroDeath Hunt", 5)
                if MAIN.hunt_continue_after ~= 1 then
                    pcall(stopMacroCycle, "OFF")
                    notify("Macro stopped — hunt detected.", "ZeroDeath Hunt", 4)
                end
            end
            return
        end
    end
    HUNT.detected = nil
end

local MISC = {}
MISC.shop     = { timer = "", items = {} }
MISC.wantLive = false

MISC.serverEpoch = nil
MISC.serverJob   = nil
MISC.CLOCK_PATH  = "C:/matcha/workspace/zerodeath_serverclock.json"

local function miscJobId()
    local ok, j = pcall(_index, game, "JobId")
    return (ok and type(j) == "string" and j ~= "") and j or nil
end
function MISC.loadClock()
    if type(readfile) ~= "function" then return end
    local okF, body = pcall(readfile, MISC.CLOCK_PATH); if not okF or not body then return end
    local okJ, t = pcall(function() return HttpService:JSONDecode(body) end)
    if okJ and type(t) == "table" and type(t.epoch) == "number" and t.job and t.job == miscJobId() then
        MISC.serverEpoch = t.epoch; MISC.serverJob = t.job
    end
end
local function miscSaveClock()
    if type(writefile) ~= "function" or not MISC.serverEpoch or not MISC.serverJob then return end
    local okJ, body = pcall(function() return HttpService:JSONEncode({ job = MISC.serverJob, epoch = MISC.serverEpoch }) end)
    if okJ and body then pcall(writefile, MISC.CLOCK_PATH, body) end
end

function MISC.uptimeGui()
    local pg = getPlayerGui(); if not pg then return -1 end
    local si = findDescendant(pg, "serverInfo", 8); if not si then return -1 end
    local up = findDescendant(si, "uptime", 6);     if not up then return -1 end
    local txt = readGuiText(up); if not txt or txt == "" then return -1 end
    local s = 0
    local d = txt:match("(%d+)[Dd]"); if d then s = s + (tonumber(d) or 0) * 86400 end
    local h = txt:match("(%d+)[Hh]"); if h then s = s + (tonumber(h) or 0) * 3600 end
    local m = txt:match("(%d+)[Mm]"); if m then s = s + (tonumber(m) or 0) * 60 end
    local x = txt:match("(%d+)[Ss]"); if x then s = s + (tonumber(x) or 0) end
    return s
end

function MISC.uptimeSeconds()
    local tnow = tick()
    local gui  = MISC.uptimeGui()
    if gui >= 0 then
        local job = miscJobId()
        if job and job ~= MISC.serverJob then MISC.serverJob = job; MISC.serverEpoch = nil end
        local est = tnow - gui
        if not MISC.serverEpoch or est < MISC.serverEpoch then MISC.serverEpoch = est; miscSaveClock() end
    end
    if MISC.serverEpoch then return tnow - MISC.serverEpoch end
    if gui >= 0 then return gui end
    return -1
end
pcall(MISC.loadClock)

function MISC.cycle(uptime, firstSpawn, cycleLen, activeDur)
    if uptime < 0 then return "UNKNOWN", 0 end
    if uptime < firstSpawn then return "WAITING", firstSpawn - uptime end
    local n = (uptime - firstSpawn) % cycleLen
    if n < activeDur then return "ACTIVE", activeDur - n end
    return "WAITING", cycleLen - n
end

function MISC.fmt(sec)
    sec = math.max(0, math.floor(sec or 0))
    local h = math.floor(sec / 3600)
    local m = math.floor((sec % 3600) / 60)
    local s = sec % 60
    if h > 0 then return string.format("%dh %02dm %02ds", h, m, s) end
    return string.format("%dm %02ds", m, s)
end

function MISC.liveUptime()
    return MISC.uptimeSeconds()
end

local function shopClean(s)
    if not s or s == "" or s:find("failed to fetch", 1, true) then return "" end
    return s
end
function MISC.readShop()
    local out = { timer = "", items = {} }
    local pg = getPlayerGui(); if not pg then return out end
    local shop = findDescendant(pg, "DailyShop", 10); if not shop then return out end
    local header  = findChild(shop, "Header")
    local refresh = header and findChild(header, "Refresh")
    local rlabel  = refresh and findChild(refresh, "Label")
    if rlabel then out.timer = shopClean(readGuiText(rlabel) or "") end
    local list = findChild(shop, "List"); if not list then return out end
    local okCh, kids = pcall(list.GetChildren, list); if not okCh or type(kids) ~= "table" then return out end
    for _, c in ipairs(kids) do
        local okN, nm = pcall(_index, c, "Name"); nm = (okN and nm) or ""
        if nm ~= "Sample" and nm ~= "UIGridLayout" then
            local nameL  = findChild(c, "Label")
            local amtL   = findChild(c, "Amount")
            local buy    = findChild(c, "BuyButton")
            local priceL = buy and findChild(buy, "Label")
            local soldF  = findChild(c, "SoldOut")
            local nm2 = shopClean(nameL and readGuiText(nameL) or "")
            out.items[#out.items + 1] = {
                name  = (nm2 ~= "" and nm2) or "?",
                price = shopClean(priceL and readGuiText(priceL) or ""),
                qty   = shopClean(amtL   and readGuiText(amtL)   or ""),
                sold  = (soldF  and isGuiVisible(soldF)) or false,
            }
        end
    end
    return out
end

local KILL = false
local clickPickerActive = false

RP.inputCapture = false

local function trackerTickMs()
    local mode = MAIN.tracker_mode
    if mode == "hybrid" then return 10 end
    if mode == "predict" then return 20 end
    return 21
end

task.spawn(function()
    while not KILL do
        local ok, err = pcall(macroTick)
        if not ok then warn("[ZeroDeath tick]", err) end
        task.wait(trackerTickMs() / 1000)
    end
end)

task.spawn(function()
    local prev = {}
    while not KILL do
        local hotkeys = {
            { vk = MAIN.hk_start_macro,   fn = startMacro },
            { vk = MAIN.hk_appraise,      fn = appraiseHotkey },
            { vk = MAIN.hk_stop_appraise, fn = stopAppraisingHotkey },
            { vk = MAIN.hk_fix_attach,    fn = fixAttach },
            { vk = MAIN.hk_reload_macro,  fn = reloadMacro },
        }
        for _, h in ipairs(hotkeys) do
            local down = (iskeypressed and iskeypressed(h.vk)) or false
            if down and not prev[h.vk] and not RP.inputCapture then
                local ok, err = pcall(h.fn)
                if not ok then warn("[hotkey]", err) end
            end
            prev[h.vk] = down
        end

        local lbracket = (iskeypressed and iskeypressed(0xDB)) or false
        if lbracket and not prev[0xDB] and not RP.inputCapture then reloadMacro() end
        prev[0xDB] = lbracket
        task.wait(0.025)
    end
end)

task.spawn(function()
    while not KILL do
        local okR, r = pcall(getHotbarRodName)
        if okR and type(r) == "string" and r ~= "" then ROD = r end

        local kind = "default"
        local okT, toolName = pcall(getEquippedToolName)
        Macro.dbgTool = (okT and type(toolName) == "string" and toolName) or ""
        if okT and toolName and toolName ~= "" then
            local okK, k = pcall(RP.classifyRod, toolName)
            if okK and k then kind = k end
        end
        if kind == "default" then
            local okH, k2 = pcall(RP.classifyRod, ROD)
            if okH and k2 then kind = k2 end
        end
        if kind == "masterline" then
            local ok2, resolved = pcall(RP.resolveMasterlineKind)
            if ok2 and resolved then kind = resolved end
        end
        ROD_KIND = kind
        DreambreakerActive = (ROD_KIND == "dreambreaker")
        task.wait(1.5)
    end
end)

task.spawn(function()
    while not KILL do
        local okW, changed = pcall(loadWebhookUrlFromFile)
        if okW and changed then notify("Webhook config loaded from webhook.txt", "Webhook", 3) end
        local ok, err = pcall(sendSummaryWebhook)
        if not ok then warn("[ZeroDeath summary]", err) end
        pcall(processWebhookEvents)
        task.wait(5)
    end
end)

task.spawn(function()
    while not KILL do
        pcall(HD.scan)
        task.wait(1.5)
    end
end)

task.spawn(function()
    while not KILL do
        if MAIN.hunt_detect_enabled == 1 or HUNT.wantLive or HUNT.forceScan then
            pcall(HUNT.scan)
            pcall(HUNT.detectTick)
            HUNT.forceScan = false
        else
            if #HUNT.active > 0 then HUNT.active = {}; HUNT.detected = nil end
        end
        task.wait(8)
    end
end)

task.spawn(function()
    local n = 0
    while not KILL do
        if MISC.wantLive then
            n = n + 1
            if n == 1 or n % 3 == 0 then
                local okS, sh = pcall(MISC.readShop)
                if okS and sh then MISC.shop = sh end
            end
        else
            n = 0
        end
        task.wait(1)
    end
end)

task.spawn(function()
    while not KILL do
        task.wait(8)
        pcall(collectgarbage, "collect")
    end
end)

task.spawn(function()
    while not KILL do
        task.wait(1)
        if MAIN.debug_logging == 1 then
            pcall(function() writefile("C:/matcha/workspace/zerodeath_debug.txt", table.concat(DBG.buf, "\n")) end)
        end
    end
end)

local function vkName(vk)
    local map = {
        [0x70]="F1",[0x71]="F2",[0x72]="F3",[0x73]="F4",[0x74]="F5",[0x75]="F6",
        [0x76]="F7",[0x77]="F8",[0x78]="F9",[0x79]="F10",[0x7A]="F11",[0x7B]="F12",
        [0x0D]="Enter",[0x1B]="Esc",[0x20]="Space",[0x2D]="Insert",[0x2E]="Delete",
    }
    if map[vk] then return map[vk] end
    if vk >= 0x41 and vk <= 0x5A then return string.char(vk) end
    if vk >= 0x30 and vk <= 0x39 then return string.char(vk) end
    return string.format("VK_%02X", vk)
end

local THEME = {
    bg         = Color3.fromRGB(14, 14, 14),
    panel      = Color3.fromRGB(22, 22, 22),
    panelHi    = Color3.fromRGB(26, 26, 26),
    border     = Color3.fromRGB(42, 42, 42),
    borderHi   = Color3.fromRGB(58, 58, 58),
    accent     = Color3.fromRGB(169, 207, 203),
    accentDim  = Color3.fromRGB(36, 36, 36),
    accentText = Color3.fromRGB(14, 14, 14),
    text       = Color3.fromRGB(240, 240, 240),
    subtext    = Color3.fromRGB(102, 102, 102),
    danger     = Color3.fromRGB(248, 113, 113),
    good       = Color3.fromRGB(74, 222, 128),
    warn       = Color3.fromRGB(235, 185, 70),
    track      = Color3.fromRGB(42, 42, 42),
    hover      = Color3.fromRGB(29, 31, 31),
    cardHead   = Color3.fromRGB(27, 27, 27),
}

local Z = {
    BG = 50, BORDER = 51, TITLE = 52, TITLE_TEXT = 53,
    SIDE = 54, SIDE_HI = 55, SIDE_TEXT = 56,
    SUBTAB = 57, SUBTAB_HI = 58, SUBTAB_TEXT = 59,
    CARD = 60, CARD_BORDER = 61, CARD_HEAD = 62, CARD_HEAD_TEXT = 63,
    WIDGET = 64, WIDGET_HI = 65, WIDGET_TEXT = 66,
    OVERLAY = 90, OVERLAY_HI = 91, OVERLAY_TEXT = 92,
}

local GUI = {
    visible        = true,
    pos            = Vector2.new(80, 80),
    size           = Vector2.new(580, 470),
    titleH         = 30,
    sideW          = 104,
    navH           = 26,
    subTabH        = 26,
    padX           = 12,
    padY           = 10,
    widgetH        = 26,
    widgetGap      = 6,
    cardGap        = 8,
    cardHeadH      = 20,
    cardPadX       = 9,
    cardPadY       = 8,
    categories     = {},
    activeCat      = 1,
    staticDrawings = {},
    sideDrawings   = {},
    subTabDrawings = {},
    widgetDrawings = {},
    dragWin        = false,
    dragWinOff     = Vector2.new(0, 0),
    dragSlider     = nil,

    scroll         = 0,
    maxScroll      = 0,
    scrollStep     = 42,
    dragScroll     = false,
    contentTop     = 0,
    contentViewH   = 0,
    contentX       = 0,
    contentW       = 0,
    scrollTrackBox = nil,
    scrollThumbBox = nil,
    mPrev          = false,
    mX             = 0,
    mY             = 0,

    liveLabels     = {},

    anims          = {},

    sideIndDraw    = nil, sideIndY = 0,
    subIndDraw     = nil, subIndX  = 0,
    hoverKey       = nil,
    _rebindTarget  = nil,
}

local function pointInBox(px, py, bx, by, bw, bh)
    return px >= bx and px <= bx + bw and py >= by and py <= by + bh
end

local function mkDraw(typ, props, pool)
    local d = Drawing.new(typ)
    for k, v in pairs(props) do d[k] = v end
    if pool then table.insert(pool, d) end
    return d
end

local function clearPool(pool)
    for i = #pool, 1, -1 do
        pcall(pool[i].Remove, pool[i])
        pool[i] = nil
    end
end

local function setVisible(pool, vis)
    for _, d in ipairs(pool) do
        pcall(_setIndex, d, "Visible", vis)
    end
end

local Tab = {}
Tab.__index = Tab

local Category = {}
Category.__index = Category

function GUI:AddCategory(name)
    local c = setmetatable({ name = name, panels = {}, active = 1 }, Category)
    table.insert(self.categories, c)
    return c
end

function Category:AddPanel(subName)
    local t = setmetatable({ name = subName, widgets = {} }, Tab)
    table.insert(self.panels, t)
    return t
end

function GUI:AddTab(name)
    return self:AddCategory(name):AddPanel(nil)
end

function GUI:activePanel()
    local c = self.categories[self.activeCat]
    if not c then return nil end
    return c.panels[c.active or 1]
end

function Tab:_add(w)
    table.insert(self.widgets, w)
    return w
end

function Tab:Section(label)
    return self:_add({ kind = "section", label = label, height = 24 })
end

function Tab:Label(text, opts)
    opts = opts or {}
    return self:_add({
        kind = "label",
        text = text or "",
        color = opts.color or THEME.text,
        size = opts.size or 13,
        height = (opts.size or 13) + 6,
        liveId = opts.liveId,
    })
end

function Tab:Button(label, fn, liveId)
    return self:_add({ kind = "button", label = label, fn = fn, height = 26, liveId = liveId })
end

function Tab:Toggle(label, default, fn)
    return self:_add({ kind = "toggle", label = label, value = default and true or false, fn = fn, height = 22 })
end

function Tab:Slider(label, min, max, default, opts, fn)
    opts = opts or {}
    return self:_add({
        kind = "slider", label = label, min = min, max = max, value = default,
        isInt = opts.int or false, fmt = opts.fmt or (opts.int and "%d" or "%.2f"),
        fn = fn, height = 34,
    })
end

function Tab:Dropdown(label, items, defaultIdx, fn)
    return self:_add({
        kind = "dropdown", label = label, items = items, idx = defaultIdx or 1, fn = fn,
        open = false, ddScroll = 0, height = 28, textSize = 14,
    })
end

function Tab:MultiSelect(label, items, selectedList, fn, searchable)
    local sel = {}
    for _, n in ipairs(selectedList or {}) do sel[n] = true end
    return self:_add({
        kind = "dropdown", multi = true, label = label,
        items = items, allItems = items, filter = "",
        searchable = searchable or nil,
        idx = 1, selected = sel, fn = fn, open = false, ddScroll = 0, height = 28, textSize = 14,
    })
end

function Tab:SearchDropdown(label, items, fn)
    return self:_add({
        kind = "dropdown", searchable = true, label = label,
        allItems = items, items = items, filter = "", selName = items[1],
        idx = 1, fn = fn, open = false, ddScroll = 0, height = 28, textSize = 14,
    })
end

function Tab:Spacing(h)
    return self:_add({ kind = "spacing", height = h or 8 })
end

function Tab:Keybind(label, settingKey, fn)
    return self:_add({ kind = "keybind", label = label, settingKey = settingKey, fn = fn, height = 26 })
end

function GUI:rect(pool, x, y, w, h, fill, bord, zf, zb)
    local fd
    if fill then
        fd = mkDraw("Square", {
            Visible = self.visible, Filled = true, Color = fill, Transparency = 1,
            Position = Vector2.new(x, y), Size = Vector2.new(w, h), ZIndex = zf or Z.WIDGET,
        }, pool)
    end
    if bord then
        for _, e in ipairs({
            { Vector2.new(x, y),     Vector2.new(x + w, y) },
            { Vector2.new(x, y + h), Vector2.new(x + w, y + h) },
            { Vector2.new(x, y),     Vector2.new(x, y + h) },
            { Vector2.new(x + w, y), Vector2.new(x + w, y + h) },
        }) do
            mkDraw("Line", {
                Visible = self.visible, Color = bord, Transparency = 1,
                From = e[1], To = e[2], Thickness = 1, ZIndex = zb or Z.CARD_BORDER,
            }, pool)
        end
    end
    return fd
end

function GUI:BuildChrome()
    clearPool(self.staticDrawings)

    self:rect(self.staticDrawings, self.pos.X, self.pos.Y, self.size.X, self.size.Y,
        THEME.bg, THEME.border, Z.BG, Z.BORDER)

    self:rect(self.staticDrawings, self.pos.X, self.pos.Y, self.size.X, self.titleH, THEME.panel, nil, Z.TITLE)
    mkDraw("Line", {
        Visible = self.visible, Color = THEME.border, Transparency = 1,
        From = Vector2.new(self.pos.X, self.pos.Y + self.titleH),
        To   = Vector2.new(self.pos.X + self.size.X, self.pos.Y + self.titleH),
        Thickness = 1, ZIndex = Z.BORDER,
    }, self.staticDrawings)
    self:rect(self.staticDrawings, self.pos.X, self.pos.Y, self.size.X, 2, THEME.accent, nil, Z.BORDER + 1)

    mkDraw("Text", {
        Visible = self.visible, Color = THEME.text, Transparency = 1,
        Position = Vector2.new(self.pos.X + 12, self.pos.Y + 8),
        Size = 14, Outline = true, Center = false, Font = Drawing.Fonts.SystemBold,
        Text = "ZeroDeath fisch", ZIndex = Z.TITLE_TEXT,
    }, self.staticDrawings)
    mkDraw("Text", {
        Visible = self.visible, Color = THEME.subtext, Transparency = 1,
        Position = Vector2.new(self.pos.X + self.size.X - 168, self.pos.Y + 9),
        Size = 11, Outline = true, Center = false, Font = Drawing.Fonts.System,
        Text = "DELETE hide  ·  PgUp/PgDn scroll", ZIndex = Z.TITLE_TEXT,
    }, self.staticDrawings)
end

function GUI:BuildSidebar()
    clearPool(self.sideDrawings)
    local x  = self.pos.X
    local y0 = self.pos.Y + self.titleH
    local h  = self.size.Y - self.titleH

    self:rect(self.sideDrawings, x, y0, self.sideW, h, THEME.panel, nil, Z.SIDE)
    mkDraw("Line", {
        Visible = self.visible, Color = THEME.border, Transparency = 1,
        From = Vector2.new(x + self.sideW, y0), To = Vector2.new(x + self.sideW, y0 + h),
        Thickness = 1, ZIndex = Z.SIDE_HI,
    }, self.sideDrawings)

    local actY = y0 + 6 + (self.activeCat - 1) * self.navH
    self.sideIndY = actY
    self.sideIndDraw = mkDraw("Square", {
        Visible = self.visible, Filled = true, Color = THEME.accent, Transparency = 1,
        Position = Vector2.new(x, actY + 2), Size = Vector2.new(3, self.navH - 4), ZIndex = Z.SIDE_TEXT,
    }, self.sideDrawings)

    local ry = y0 + 6
    for i, c in ipairs(self.categories) do
        local active = (i == self.activeCat)
        c._navBox = { x = x, y = ry, w = self.sideW, h = self.navH }
        c._navActive = active
        c._navBg = self:rect(self.sideDrawings, x + 1, ry, self.sideW - 2, self.navH,
            active and THEME.accentDim or THEME.panel, nil, Z.SIDE_HI)
        c._navTxt = mkDraw("Text", {
            Visible = self.visible, Color = active and THEME.text or THEME.subtext, Transparency = 1,
            Outline = true, Center = false, Position = Vector2.new(x + 13, ry + 6),
            Size = 12, Font = active and Drawing.Fonts.SystemBold or Drawing.Fonts.System,
            Text = c.name, ZIndex = Z.SIDE_TEXT,
        }, self.sideDrawings)
        ry = ry + self.navH
    end
end

function GUI:BuildSubTabs()
    clearPool(self.subTabDrawings)
    self.subIndDraw = nil
    local c = self.categories[self.activeCat]
    if not c or #c.panels < 2 then return end
    local x0 = self.pos.X + self.sideW
    local y  = self.pos.Y + self.titleH
    local w  = self.size.X - self.sideW
    self:rect(self.subTabDrawings, x0, y, w, self.subTabH, THEME.panel, nil, Z.SUBTAB)
    mkDraw("Line", {
        Visible = self.visible, Color = THEME.border, Transparency = 1,
        From = Vector2.new(x0, y + self.subTabH), To = Vector2.new(x0 + w, y + self.subTabH),
        Thickness = 1, ZIndex = Z.SUBTAB,
    }, self.subTabDrawings)
    local px = x0 + 8
    for i, p in ipairs(c.panels) do
        local label  = p.name or ("Tab " .. i)
        local pw     = (#label * 7) + 16
        local active = (i == (c.active or 1))
        p._pillBox    = { x = px, y = y, w = pw, h = self.subTabH }
        p._pillActive = active
        p._pillTxt = mkDraw("Text", {
            Visible = self.visible, Color = active and THEME.accent or THEME.subtext, Transparency = 1,
            Outline = true, Center = false, Position = Vector2.new(px + 8, y + 7),
            Size = 12, Font = active and Drawing.Fonts.SystemBold or Drawing.Fonts.System,
            Text = label, ZIndex = Z.SUBTAB_TEXT,
        }, self.subTabDrawings)
        if active then
            self.subIndX = px
            self.subIndDraw = mkDraw("Square", {
                Visible = self.visible, Filled = true, Color = THEME.accent, Transparency = 1,
                Position = Vector2.new(px, y + self.subTabH - 2), Size = Vector2.new(pw, 2), ZIndex = Z.SUBTAB_HI,
            }, self.subTabDrawings)
        end
        px = px + pw + 6
    end
end

function GUI:_renderWidget(w, bx, by, bw)
    if w.kind == "label" then
        w._textDraw = mkDraw("Text", {
            Visible = self.visible, Color = w.color, Transparency = 1, Outline = true, Center = false,
            Position = Vector2.new(bx, by + 2), Size = w.size, Font = Drawing.Fonts.System,
            Text = w.text, ZIndex = Z.WIDGET_TEXT,
        }, self.widgetDrawings)
        if w.liveId then self.liveLabels[w.liveId] = w end

    elseif w.kind == "button" then
        w._btnBg = self:rect(self.widgetDrawings, bx, by, bw, w.height, THEME.panelHi, THEME.border, Z.WIDGET, Z.WIDGET_HI)

        mkDraw("Square", {
            Visible = self.visible, Filled = true, Color = THEME.accent, Transparency = 1,
            Position = Vector2.new(bx, by), Size = Vector2.new(2, w.height), ZIndex = Z.WIDGET_HI,
        }, self.widgetDrawings)
        w._textDraw = mkDraw("Text", {
            Visible = self.visible, Color = THEME.text, Transparency = 1, Outline = true, Center = false,
            Position = Vector2.new(bx + 12, by + 6), Size = 13, Font = Drawing.Fonts.System,
            Text = w.label, ZIndex = Z.WIDGET_TEXT,
        }, self.widgetDrawings)
        if w.liveId then self.liveLabels[w.liveId] = w end

    elseif w.kind == "toggle" then
        local tw, th = 32, 16
        local tx, ty = bx + 1, by + 4
        local on = w.value
        local trackCol = on and THEME.accent or THEME.track
        w._trackMid = self:rect(self.widgetDrawings, tx, ty, tw, th, trackCol, nil, Z.WIDGET)
        w._trackL = mkDraw("Circle", {
            Visible = self.visible, Filled = true, Color = trackCol, Transparency = 1,
            Position = Vector2.new(tx, ty + th / 2), Radius = th / 2, NumSides = 24, ZIndex = Z.WIDGET,
        }, self.widgetDrawings)
        w._trackR = mkDraw("Circle", {
            Visible = self.visible, Filled = true, Color = trackCol, Transparency = 1,
            Position = Vector2.new(tx + tw, ty + th / 2), Radius = th / 2, NumSides = 24, ZIndex = Z.WIDGET,
        }, self.widgetDrawings)
        w._knobX0, w._knobX1 = tx, tx + tw
        w._knobY   = ty + th / 2
        w._knobCur = on and w._knobX1 or w._knobX0
        w._knob = mkDraw("Circle", {
            Visible = self.visible, Filled = true, Color = THEME.text, Transparency = 1,
            Position = Vector2.new(w._knobCur, w._knobY), Radius = th / 2 + 1, NumSides = 24, ZIndex = Z.WIDGET_HI,
        }, self.widgetDrawings)
        w._lblDraw = mkDraw("Text", {
            Visible = self.visible, Color = on and THEME.text or THEME.subtext, Transparency = 1,
            Outline = true, Center = false, Position = Vector2.new(bx + tw + 16, by + 4),
            Size = 13, Font = Drawing.Fonts.System, Text = w.label, ZIndex = Z.WIDGET_TEXT,
        }, self.widgetDrawings)

    elseif w.kind == "slider" then
        mkDraw("Text", {
            Visible = self.visible, Color = THEME.text, Transparency = 1, Outline = true, Center = false,
            Position = Vector2.new(bx, by), Size = 12, Font = Drawing.Fonts.System,
            Text = w.label, ZIndex = Z.WIDGET_TEXT,
        }, self.widgetDrawings)
        w._valueDraw = mkDraw("Text", {
            Visible = self.visible, Color = THEME.accent, Transparency = 1, Outline = true, Center = false,
            Position = Vector2.new(bx + bw - 60, by), Size = 12, Font = Drawing.Fonts.SystemBold,
            Text = string.format(w.fmt, w.value), ZIndex = Z.WIDGET_TEXT,
        }, self.widgetDrawings)
        local tx, ty, tw, th = bx, by + 20, bw, 6
        self:rect(self.widgetDrawings, tx, ty, tw, th, THEME.track, nil, Z.WIDGET)
        local frac = (w.value - w.min) / math.max(1e-9, (w.max - w.min))
        frac = math.max(0, math.min(1, frac))
        w._fillDraw = self:rect(self.widgetDrawings, tx, ty, math.floor(tw * frac), th, THEME.accent, nil, Z.WIDGET_HI)
        w._handleDraw = mkDraw("Square", {
            Visible = self.visible, Filled = true, Color = THEME.text, Transparency = 1,
            Position = Vector2.new(math.floor(tx + tw * frac) - 3, ty - 3), Size = Vector2.new(6, 12), ZIndex = Z.WIDGET_HI,
        }, self.widgetDrawings)
        w._trackBox = { x = tx, y = ty - 4, w = tw, h = th + 8 }

    elseif w.kind == "dropdown" then
        local bcol = w.open and THEME.accent or THEME.border
        w._ddBg = self:rect(self.widgetDrawings, bx, by, bw, w.height, THEME.panelHi, bcol, Z.WIDGET, Z.WIDGET_HI)
        mkDraw("Text", {
            Visible = self.visible, Color = THEME.subtext, Transparency = 1, Outline = true, Center = false,
            Position = Vector2.new(bx + 8, by + 7), Size = 12, Font = Drawing.Fonts.System,
            Text = w.label, ZIndex = Z.WIDGET_TEXT,
        }, self.widgetDrawings)
        local headerVal
        if w.searchable and w.open then

            headerVal = (w.filter ~= "" and (w.filter .. "_")) or "(type to search)"
        elseif w.multi then

            local n, only = 0, nil
            for _, it in ipairs(w.allItems or w.items) do if w.selected[it] then n = n + 1; only = it end end
            headerVal = (n == 0 and "None") or (n == 1 and only) or (n .. " selected")
        elseif w.searchable then
            if w.preserveFilter and w.filter and w.filter ~= "" then
                headerVal = tostring(w.filter)
            else
                headerVal = tostring(w.selName or "?")
            end
        else
            headerVal = tostring(w.items[w.idx] or "?")
        end
        mkDraw("Text", {
            Visible = self.visible, Color = THEME.text, Transparency = 1, Outline = true, Center = false,
            Position = Vector2.new(bx + bw - 150, by + 7), Size = w.textSize or 12, Font = Drawing.Fonts.SystemBold,
            Text = headerVal, ZIndex = Z.WIDGET_TEXT,
        }, self.widgetDrawings)
        mkDraw("Text", {
            Visible = self.visible, Color = THEME.accent, Transparency = 1, Outline = true, Center = false,
            Position = Vector2.new(bx + bw - 16, by + 6), Size = 13, Font = Drawing.Fonts.SystemBold,
            Text = w.open and "^" or "v", ZIndex = Z.WIDGET_TEXT,
        }, self.widgetDrawings)
        w._itemBoxes = nil; w._ddUpBox = nil; w._ddDownBox = nil
        if w.open then
            local n      = #w.items
            local VIS    = 9
            local itemH  = 22
            local oy     = by + w.height
            local arrows = n > VIS
            local startI, endI = 1, n
            if arrows then
                local off = math.max(0, math.min(n - VIS, w.ddScroll or 0))
                w.ddScroll = off
                startI, endI = off + 1, off + VIS
            end
            local rows  = (endI - startI + 1) + (arrows and 2 or 0)
            local listH = rows * itemH
            self:rect(self.widgetDrawings, bx, oy, bw, listH, THEME.panel, THEME.accent, Z.OVERLAY, Z.OVERLAY_HI)
            local ry = oy
            if arrows then
                mkDraw("Text", {
                    Visible = self.visible, Color = THEME.subtext, Transparency = 1, Outline = true, Center = false,
                    Position = Vector2.new(bx + bw / 2 - 3, ry + 5),
                    Size = 12, Font = Drawing.Fonts.SystemBold, Text = "^", ZIndex = Z.OVERLAY_TEXT,
                }, self.widgetDrawings)
                w._ddUpBox = { x = bx, y = ry, w = bw, h = itemH }
                ry = ry + itemH
            end
            w._itemBoxes = {}
            for i = startI, endI do
                local sel
                if w.multi then
                    sel = (w.selected[w.items[i]] == true)
                elseif w.searchable then
                    sel = (w.items[i] == w.selName)
                else
                    sel = (i == w.idx)
                end
                if sel then
                    self:rect(self.widgetDrawings, bx + 1, ry, bw - 2, itemH, THEME.accentDim, nil, Z.OVERLAY_HI)
                end
                mkDraw("Text", {
                    Visible = self.visible, Color = sel and THEME.accent or THEME.text, Transparency = 1,
                    Outline = true, Center = false, Position = Vector2.new(bx + 10, ry + 4),
                    Size = w.textSize or 12, Font = Drawing.Fonts.System,
                    Text = tostring(w.items[i]), ZIndex = Z.OVERLAY_TEXT,
                }, self.widgetDrawings)
                table.insert(w._itemBoxes, { x = bx, y = ry, w = bw, h = itemH, idx = i })
                ry = ry + itemH
            end
            if arrows then
                mkDraw("Text", {
                    Visible = self.visible, Color = THEME.subtext, Transparency = 1, Outline = true, Center = false,
                    Position = Vector2.new(bx + bw / 2 - 3, ry + 5),
                    Size = 12, Font = Drawing.Fonts.SystemBold, Text = "v", ZIndex = Z.OVERLAY_TEXT,
                }, self.widgetDrawings)
                w._ddDownBox = { x = bx, y = ry, w = bw, h = itemH }
                ry = ry + itemH
            end
        end

    elseif w.kind == "keybind" then
        local listening = (self._rebindTarget == w)
        local bcol = listening and THEME.accent or THEME.border
        w._kbBg = self:rect(self.widgetDrawings, bx, by, bw, w.height, THEME.panelHi, bcol, Z.WIDGET, Z.WIDGET_HI)
        mkDraw("Text", {
            Visible = self.visible, Color = THEME.text, Transparency = 1, Outline = true, Center = false,
            Position = Vector2.new(bx + 12, by + 6), Size = 13, Font = Drawing.Fonts.System,
            Text = w.label, ZIndex = Z.WIDGET_TEXT,
        }, self.widgetDrawings)
        local rt = listening and "press a key  (Esc cancels)" or vkName(MAIN[w.settingKey])
        mkDraw("Text", {
            Visible = self.visible, Color = listening and THEME.warn or THEME.accent, Transparency = 1,
            Outline = true, Center = false, Position = Vector2.new(bx + bw - 150, by + 6),
            Size = 12, Font = Drawing.Fonts.SystemBold, Text = rt, ZIndex = Z.WIDGET_TEXT,
        }, self.widgetDrawings)
    end
end

function GUI:BuildWidgets()
    clearPool(self.widgetDrawings)
    self.liveLabels = {}
    local tab = self:activePanel()
    if not tab then return end
    local cat = self.categories[self.activeCat]
    local hasSub = cat and #cat.panels > 1

    local contentTop    = self.pos.Y + self.titleH + (hasSub and self.subTabH or 0) + self.padY
    local contentBottom = self.pos.Y + self.size.Y - self.padY
    local viewH         = contentBottom - contentTop
    local contentX      = self.pos.X + self.sideW + self.padX
    local contentW      = self.size.X - self.sideW - self.padX * 2 - 16
    self.contentTop   = contentTop
    self.contentViewH = viewH
    self.contentX     = contentX
    self.contentW     = contentW

    local groups, cur = {}, nil
    for _, w in ipairs(tab.widgets) do
        if w.kind == "section" then
            cur = { title = w.label, items = {} }
            groups[#groups + 1] = cur
        else
            if not cur then cur = { title = nil, items = {} }; groups[#groups + 1] = cur end
            cur.items[#cur.items + 1] = w
        end
    end

    local function groupH(g)
        local bh = self.cardPadY * 2
        for i, it in ipairs(g.items) do
            bh = bh + it.height
            if i < #g.items then bh = bh + self.widgetGap end
        end
        return (g.title and self.cardHeadH or 0) + bh
    end

    local total = 0
    for i, g in ipairs(groups) do
        total = total + groupH(g)
        if i < #groups then total = total + self.cardGap end
    end
    self.maxScroll = math.max(0, total - viewH)
    if self.scroll > self.maxScroll then self.scroll = self.maxScroll end
    if self.scroll < 0 then self.scroll = 0 end

    local cardX, cardW = contentX, contentW
    local bx = contentX + self.cardPadX
    local bw = contentW - self.cardPadX * 2
    local y  = contentTop - self.scroll
    for _, g in ipairs(groups) do
        local gh      = groupH(g)
        local cardTop = y
        local cardVis = (cardTop >= contentTop - 0.5) and (cardTop + gh <= contentBottom + 0.5)
        for _, it in ipairs(g.items) do it._visible = false end
        if cardVis then
            self:rect(self.widgetDrawings, cardX, cardTop, cardW, gh, THEME.panel, THEME.border, Z.CARD, Z.CARD_BORDER)
            local iy = cardTop
            if g.title then
                self:rect(self.widgetDrawings, cardX, cardTop, cardW, self.cardHeadH, THEME.cardHead, nil, Z.CARD_HEAD)
                mkDraw("Square", {
                    Visible = self.visible, Filled = true, Color = THEME.accent, Transparency = 1,
                    Position = Vector2.new(cardX, cardTop), Size = Vector2.new(3, self.cardHeadH), ZIndex = Z.CARD_HEAD_TEXT,
                }, self.widgetDrawings)
                mkDraw("Text", {
                    Visible = self.visible, Color = THEME.accent, Transparency = 1, Outline = true, Center = false,
                    Position = Vector2.new(cardX + 10, cardTop + 4), Size = 12, Font = Drawing.Fonts.SystemBold,
                    Text = string.upper(g.title), ZIndex = Z.CARD_HEAD_TEXT,
                }, self.widgetDrawings)
                iy = cardTop + self.cardHeadH
            end
            iy = iy + self.cardPadY
            for _, w in ipairs(g.items) do
                w._box = { x = bx, y = iy, w = bw, h = w.height }
                w._visible = true
                self:_renderWidget(w, bx, iy, bw)
                iy = iy + w.height + self.widgetGap
            end
        end
        y = y + gh + self.cardGap
    end

    if self.maxScroll > 0 then
        local barX, barW = self.pos.X + self.size.X - 13, 9
        mkDraw("Square", {
            Visible = self.visible, Filled = true, Color = THEME.track, Transparency = 1,
            Position = Vector2.new(barX, contentTop), Size = Vector2.new(barW, viewH),
            ZIndex = Z.WIDGET,
        }, self.widgetDrawings)
        local thumbH = math.max(32, viewH * (viewH / (viewH + self.maxScroll)))
        local thumbY = contentTop + (viewH - thumbH) * (self.scroll / self.maxScroll)
        mkDraw("Square", {
            Visible = self.visible, Filled = true, Color = THEME.accent, Transparency = 1,
            Position = Vector2.new(barX, math.floor(thumbY)), Size = Vector2.new(barW, math.floor(thumbH)),
            ZIndex = Z.WIDGET_HI,
        }, self.widgetDrawings)

        self.scrollTrackBox = { x = barX - 7, y = contentTop, w = barW + 13, h = viewH }
        self.scrollThumbBox = { x = barX - 7, y = thumbY, w = barW + 13, h = thumbH }
    else
        self.scrollTrackBox = nil
        self.scrollThumbBox = nil
    end
end

function GUI:Rebuild()
    self:BuildChrome()
    self:BuildSidebar()
    self:BuildSubTabs()
    self:BuildWidgets()
end

function GUI:Show()  self.visible = true;  self:Rebuild() end
function GUI:CloseDropdowns()
    for _, c in ipairs(self.categories) do
        for _, p in ipairs(c.panels) do
            for _, w in ipairs(p.widgets) do
                if w.kind == "dropdown" then w.open = false end
            end
        end
    end
end

function GUI:FilterDropdown(w)
    local q = string.lower(w.filter or "")
    if q == "" then
        w.items = w.allItems
    else
        local out = {}
        for _, it in ipairs(w.allItems) do
            if string.find(string.lower(tostring(it)), q, 1, true) then out[#out + 1] = it end
        end
        w.items = out
    end
    w.ddScroll = 0
    if w.idx > #w.items then w.idx = 1 end
end

GUI._kbPrev = {}
function GUI:PollSearchKeys(w)
    if type(iskeypressed) ~= "function" then return end
    local changed = false
    local function edge(vk)
        local down = iskeypressed(vk) or false
        local was = self._kbPrev[vk]
        self._kbPrev[vk] = down
        return down and not was
    end
    for vk = 0x41, 0x5A do
        if edge(vk) then w.filter = (w.filter or "") .. string.char(vk + 32); changed = true end
    end
    for vk = 0x30, 0x39 do
        if edge(vk) then w.filter = (w.filter or "") .. string.char(vk); changed = true end
    end
    if edge(0x20) then w.filter = (w.filter or "") .. " "; changed = true end
    if edge(0xBC) then w.filter = (w.filter or "") .. ","; changed = true end
    if edge(0xBD) or edge(0x6D) then w.filter = (w.filter or "") .. "-"; changed = true end
    if edge(0xBE) or edge(0x6E) then w.filter = (w.filter or "") .. "."; changed = true end
    if edge(0x08) then
        if #(w.filter or "") > 0 then w.filter = string.sub(w.filter, 1, -2); changed = true end
    end
    if changed then
        self:FilterDropdown(w)
        self:BuildWidgets()
    end
end

function GUI:CaptureRebind()
    local w = self._rebindTarget
    if not w then return end
    if type(iskeypressed) ~= "function" then self._rebindTarget = nil; return end
    local function edge(vk)
        local down = iskeypressed(vk) or false
        local was = self._kbPrev[vk]; self._kbPrev[vk] = down
        return down and not was
    end
    if edge(0x1B) then
        self._rebindTarget = nil; self:BuildWidgets()
        notify("Rebind cancelled.", "ZeroDeath fisch", 2); return
    end
    local hit
    for vk = 0x70, 0x7B do if edge(vk) then hit = vk end end
    for vk = 0x41, 0x5A do if edge(vk) then hit = vk end end
    for vk = 0x30, 0x39 do if edge(vk) then hit = vk end end
    if hit then
        MAIN[w.settingKey] = hit
        saveSettings()
        self._rebindTarget = nil
        if w.fn then pcall(w.fn, hit) end
        self:BuildWidgets()
        notify("Bound to " .. vkName(hit), "ZeroDeath fisch", 2)
    end
end

function GUI:Hide()
    self.visible = false
    self._rebindTarget = nil
    self:CloseDropdowns()
    setVisible(self.staticDrawings, false)
    setVisible(self.sideDrawings, false)
    setVisible(self.subTabDrawings, false)
    setVisible(self.widgetDrawings, false)
end
function GUI:Toggle() if self.visible then self:Hide() else self:Show() end end

function GUI:_anim(draw, ax, ay, bx, by, durMs)
    if not draw then return end
    pcall(_setIndex, draw, "Position", Vector2.new(ax, ay))
    self.anims[#self.anims + 1] = { draw = draw, ax = ax, ay = ay, bx = bx, by = by,
        t0 = tick() * 1000, dur = durMs or 120 }
end

function GUI:SetCategory(i)
    if not self.categories[i] or i == self.activeCat then return end
    self:CloseDropdowns()
    local fromY = self.sideIndY
    self.activeCat = i
    self.scroll = 0
    self:BuildSidebar()
    self:BuildSubTabs()
    self:BuildWidgets()
    self:_anim(self.sideIndDraw, self.pos.X, fromY + 2, self.pos.X, self.sideIndY + 2, 120)
end

function GUI:SetPanel(i)
    local c = self.categories[self.activeCat]
    if not c or not c.panels[i] or i == (c.active or 1) then return end
    self:CloseDropdowns()
    local fromX = self.subIndX
    c.active = i
    self.scroll = 0
    self:BuildSubTabs()
    self:BuildWidgets()
    if self.subIndDraw then
        local yb = self.pos.Y + self.titleH + self.subTabH - 2
        self:_anim(self.subIndDraw, fromX, yb, self.subIndX, yb, 120)
    end
end

function GUI:ScrollBy(delta)
    if self.maxScroll <= 0 then return end
    local ns = math.max(0, math.min(self.maxScroll, self.scroll + delta))
    if ns ~= self.scroll then self.scroll = ns; self:BuildWidgets() end
end

function GUI:_applyScrollFromMouse(my)
    if self.maxScroll <= 0 then return end
    local frac = (my - self.contentTop) / math.max(1, self.contentViewH)
    frac = math.max(0, math.min(1, frac))
    local ns = math.floor(self.maxScroll * frac + 0.5)
    if ns ~= self.scroll then self.scroll = ns; self:BuildWidgets() end
end

function GUI:Move(dx, dy)
    self.pos = Vector2.new(self.pos.X + dx, self.pos.Y + dy)

    local cam = workspace.CurrentCamera
    if cam and cam.ViewportSize then
        local vp = cam.ViewportSize
        self.pos = Vector2.new(
            math.max(0, math.min(vp.X - 60, self.pos.X)),
            math.max(0, math.min(vp.Y - 60, self.pos.Y))
        )
    end
    self:Rebuild()
end

function GUI:SetLabel(id, text)
    local w = self.liveLabels[id]
    if not w or not w._textDraw then return end
    pcall(_setIndex, w._textDraw, "Text", text)
end

function GUI:SetLabelColor(id, color)
    local w = self.liveLabels[id]
    if not w or not w._textDraw then return end
    pcall(_setIndex, w._textDraw, "Color", color)
end

local function getMouseXY()
    local lp = Players.LocalPlayer
    if not lp then return 0, 0 end
    local m = lp:GetMouse()
    if not m then return 0, 0 end
    return m.X or 0, m.Y or 0
end

function GUI:HandleClick(mx, my)
    if not self.visible then return end

    local prevRebind = self._rebindTarget
    self._rebindTarget = nil

    if pointInBox(mx, my, self.pos.X, self.pos.Y, self.size.X, self.titleH) then
        self.dragWin = true
        self.dragWinOff = Vector2.new(mx - self.pos.X, my - self.pos.Y)
        return
    end

    for i, c in ipairs(self.categories) do
        local b = c._navBox
        if b and pointInBox(mx, my, b.x, b.y, b.w, b.h) then
            self:SetCategory(i)
            return
        end
    end

    local cat = self.categories[self.activeCat]
    if cat and #cat.panels > 1 then
        for i, p in ipairs(cat.panels) do
            local b = p._pillBox
            if b and pointInBox(mx, my, b.x, b.y, b.w, b.h) then
                self:SetPanel(i)
                return
            end
        end
    end

    if self.scrollTrackBox and pointInBox(mx, my, self.scrollTrackBox.x, self.scrollTrackBox.y, self.scrollTrackBox.w, self.scrollTrackBox.h) then
        self.dragScroll = true
        self:_applyScrollFromMouse(my)
        return
    end

    local tab = self:activePanel()
    if not tab then return end

    for _, w in ipairs(tab.widgets) do
        if w.kind == "dropdown" and w.open then
            if w._ddUpBox and pointInBox(mx, my, w._ddUpBox.x, w._ddUpBox.y, w._ddUpBox.w, w._ddUpBox.h) then
                w.ddScroll = math.max(0, (w.ddScroll or 0) - 3); self:BuildWidgets(); return
            end
            if w._ddDownBox and pointInBox(mx, my, w._ddDownBox.x, w._ddDownBox.y, w._ddDownBox.w, w._ddDownBox.h) then
                w.ddScroll = (w.ddScroll or 0) + 3; self:BuildWidgets(); return
            end
            if w._itemBoxes then
                for _, ib in ipairs(w._itemBoxes) do
                    if pointInBox(mx, my, ib.x, ib.y, ib.w, ib.h) then
                        if w.multi then

                            local nm = w.items[ib.idx]
                            w.selected[nm] = (not w.selected[nm]) or nil

                            local arr = {}
                            for _, it in ipairs(w.allItems or w.items) do if w.selected[it] then arr[#arr + 1] = it end end
                            if w.fn then pcall(w.fn, arr) end
                            self:BuildWidgets(); return
                        end
                        local chosen = w.items[ib.idx]
                        w.open = false
                        if w.searchable then

                            w.selName = chosen
                            w.filter = ""
                            w.items = w.allItems
                            for i, it in ipairs(w.items) do if it == chosen then w.idx = i; break end end
                        else
                            w.idx = ib.idx
                        end
                        if w.fn then pcall(w.fn, w.idx, chosen) end
                        self:BuildWidgets(); return
                    end
                end
            end

            if w.searchable and w.preserveFilter and w.filter and w.filter ~= "" then
                w.selName = w.filter
            end
            w.open = false; self:BuildWidgets(); return
        end
    end

    for _, w in ipairs(tab.widgets) do
        local b = w._box; if not b or not w._visible then continue end
        if pointInBox(mx, my, b.x, b.y, b.w, b.h) then
            if w.kind == "button" then
                if w.fn then pcall(w.fn) end
            elseif w.kind == "toggle" then
                w.value = not w.value
                if w.fn then pcall(w.fn, w.value) end

                local on = w.value
                local col = on and THEME.accent or THEME.track
                pcall(_setIndex, w._trackMid, "Color", col)
                pcall(_setIndex, w._trackL, "Color", col)
                pcall(_setIndex, w._trackR, "Color", col)
                pcall(_setIndex, w._lblDraw, "Color", on and THEME.text or THEME.subtext)
                local fromX = w._knobCur or (on and w._knobX0 or w._knobX1)
                local toX   = on and w._knobX1 or w._knobX0
                w._knobCur  = toX
                self:_anim(w._knob, fromX, w._knobY, toX, w._knobY, 100)
            elseif w.kind == "slider" then
                if w._trackBox and pointInBox(mx, my, w._trackBox.x, w._trackBox.y, w._trackBox.w, w._trackBox.h) then
                    self.dragSlider = w
                    self:_applySliderFromMouse(w, mx)
                end
            elseif w.kind == "dropdown" then

                for _, ow in ipairs(tab.widgets) do
                    if ow.kind == "dropdown" and ow ~= w then
                        if ow.searchable and ow.preserveFilter and ow.filter and ow.filter ~= "" then
                            ow.selName = ow.filter
                        end
                        ow.open = false
                    end
                end
                if w.open and w.searchable and w.preserveFilter and w.filter and w.filter ~= "" then
                    w.selName = w.filter
                end
                w.open = not w.open
                w.ddScroll = 0

                if w.open and w.searchable then
                    if not w.preserveFilter then
                        w.filter = ""
                    end
                    self:FilterDropdown(w)
                end
                self:BuildWidgets()
            elseif w.kind == "keybind" then
                self._rebindTarget = (prevRebind == w) and nil or w
                self._kbPrev = {}
                self:BuildWidgets()
            end
            return
        end
    end
end

function GUI:HandleRightClick(mx, my)
    if not self.visible then return end

    local tab = self:activePanel(); if not tab then return end
    for _, w in ipairs(tab.widgets) do
        if w.kind == "dropdown" and w.open then
            w.open = false; self:BuildWidgets(); return
        end
    end
end

function GUI:_applySliderFromMouse(w, mx)
    local tb = w._trackBox
    local frac = (mx - tb.x) / tb.w
    frac = math.max(0, math.min(1, frac))
    local val = w.min + (w.max - w.min) * frac
    if w.isInt then val = math.floor(val + 0.5) end
    if val ~= w.value then
        w.value = val
        w._pendingFire = true
        local fillW = math.floor(tb.w * frac)
        pcall(function()
            w._fillDraw.Size = Vector2.new(fillW, w._fillDraw.Size.Y)
            w._handleDraw.Position = Vector2.new(math.floor(tb.x + tb.w * frac) - 3, tb.y + 4 - 3)
            w._valueDraw.Text = string.format(w.fmt, val)
        end)
    end
end

function GUI:Update()
    self.mX, self.mY = getMouseXY()

    RP.inputCapture = (self._rebindTarget ~= nil)
    self:_advanceAnims()
    local mDown = (ismouse1pressed and ismouse1pressed()) or false

    if not robloxActive() then
        self.dragWin = false
        self.dragSlider = nil
        self.dragScroll = false
        self.mPrev = mDown
        return
    end
    local edgeDown = mDown and not self.mPrev

    if edgeDown then
        local pr = self._rebindTarget
        self:HandleClick(self.mX, self.mY)

        if self._rebindTarget ~= pr then self:BuildWidgets() end
    end
    if self.dragWin and not mDown then self.dragWin = false end
    if self.dragSlider and not mDown then

        local w = self.dragSlider
        if w._pendingFire and w.fn then
            w._pendingFire = false
            pcall(w.fn, w.value)
        end
        self.dragSlider = nil
    end
    if self.dragScroll and not mDown then self.dragScroll = false end

    if self.dragWin then
        local nx = self.mX - self.dragWinOff.X
        local ny = self.mY - self.dragWinOff.Y
        if nx ~= self.pos.X or ny ~= self.pos.Y then
            local dx, dy = nx - self.pos.X, ny - self.pos.Y
            self:Move(dx, dy)
        end
    end

    if self.dragSlider and mDown then
        self:_applySliderFromMouse(self.dragSlider, self.mX)
    end

    if self.dragScroll and mDown then
        self:_applyScrollFromMouse(self.mY)
    end

    if self.visible then self:_hover(self.mX, self.mY) end

    self.mPrev = mDown
end

function GUI:_advanceAnims()
    local n = #self.anims
    if n == 0 then return end
    local now = tick() * 1000
    for i = n, 1, -1 do
        local a = self.anims[i]
        local p = (now - a.t0) / a.dur
        if p < 0 then p = 0 end
        if p > 1 then p = 1 end
        local e = p * p * (3 - 2 * p)
        pcall(_setIndex, a.draw, "Position",
            Vector2.new(a.ax + (a.bx - a.ax) * e, a.ay + (a.by - a.ay) * e))
        if p >= 1 then table.remove(self.anims, i) end
    end
end

function GUI:_hoverColor(obj, typ, on)
    if typ == "cat" then
        pcall(_setIndex, obj._navBg, "Color",
            on and THEME.hover or (obj._navActive and THEME.accentDim or THEME.panel))
    elseif typ == "pill" then
        pcall(_setIndex, obj._pillTxt, "Color",
            on and THEME.text or (obj._pillActive and THEME.accent or THEME.subtext))
    elseif typ == "btn" then
        pcall(_setIndex, obj._btnBg, "Color", on and THEME.borderHi or THEME.panelHi)
    end
end

function GUI:_hover(mx, my)
    local item, typ = nil, nil
    for _, c in ipairs(self.categories) do
        local b = c._navBox
        if b and not c._navActive and pointInBox(mx, my, b.x, b.y, b.w, b.h) then
            item, typ = c, "cat"; break
        end
    end
    if not item then
        local cat = self.categories[self.activeCat]
        if cat and #cat.panels > 1 then
            for _, p in ipairs(cat.panels) do
                local b = p._pillBox
                if b and not p._pillActive and pointInBox(mx, my, b.x, b.y, b.w, b.h) then
                    item, typ = p, "pill"; break
                end
            end
        end
    end
    if not item then
        local tab = self:activePanel()
        if tab then
            for _, w in ipairs(tab.widgets) do
                if w._visible and w.kind == "button" then
                    local b = w._box
                    if b and pointInBox(mx, my, b.x, b.y, b.w, b.h) then
                        item, typ = w, "btn"; break
                    end
                end
            end
        end
    end
    if item == self.hoverItem then return end
    if self.hoverItem then self:_hoverColor(self.hoverItem, self.hoverType, false) end
    self.hoverItem, self.hoverType = item, typ
    if item then self:_hoverColor(item, typ, true) end
end

;(function()
    local t = GUI:AddTab("Dashboard")
    t:Section("Control")

    t:Button("Start / Stop", function() startMacro() end)
    t:Button("Stop Appraise", function() stopAppraisingHotkey() end)
    t:Button("Refresh Rod / Cache", function() fixAttach() end)
    t:Section("Tracker")
    local di = 1
    for i = 1, #RP.trackerValues do if RP.trackerValues[i] == MAIN.tracker_mode then di = i end end
    t:Dropdown("Mode", RP.trackerLabels, di, function(idx)
        MAIN.tracker_mode = RP.trackerValues[idx] or "predict"
        saveSettings()
        if controller and controller.Reset then controller:Reset() end
        notify("Tracker: " .. (RP.trackerLabels[idx] or "?"), "ZeroDeath fisch", 2)
    end)
    t:Section("Master Switches")
    t:Toggle("Auto Fish", Macro.cycleEnabled and Macro.phase ~= "APPRAISE",
        function(v)
            local currentlyFishing = Macro.cycleEnabled and Macro.phase ~= "APPRAISE"
            if v ~= currentlyFishing then
                local saved = MAIN.auto_appraise_enabled
                MAIN.auto_appraise_enabled = 0
                startMacro()
                MAIN.auto_appraise_enabled = saved
                saveSettings()
            end
        end)
    t:Toggle("Auto Reel only (no auto cast)", MAIN.auto_reel_only == 1,
        function(v)
            MAIN.auto_reel_only = v and 1 or 0
            saveSettings()

            if v and Macro.cycleEnabled then
                local ph = Macro.phase
                if ph == "CASTING" or ph == "CASTED" or ph == "SHAKE" then
                    releaseMouse(true); Macro.phase = "REELWATCH"
                end
            end
        end)
    t:Toggle("Auto Appraise (master)", MAIN.auto_appraise_enabled == 1,
        function(v) MAIN.auto_appraise_enabled = v and 1 or 0; saveSettings() end)
    t:Toggle("Auto Totem", MAIN.auto_totem_enabled == 1,
        function(v) MAIN.auto_totem_enabled = v and 1 or 0; saveSettings() end)
    t:Toggle("Discord Webhook", MAIN.webhook_enabled == 1,
        function(v) MAIN.webhook_enabled = v and 1 or 0; saveSettings() end)
    t:Toggle("Status HUD (always-on overlay)", MAIN.show_status_hud == 1,
        function(v) MAIN.show_status_hud = v and 1 or 0; saveSettings() end)
    t:Section("Live Status")
    t:Label("Status:    OFF",          { liveId = "status" })
    t:Label("Rod:       ---",          { liveId = "rod" })
    t:Label("Profile:   ---",          { liveId = "profile" })
    t:Label("Power:     ---",          { liveId = "power" })
    t:Label("Progress:  ---",          { liveId = "prog" })
    t:Label("Totem:     IDLE",         { liveId = "totem" })
    t:Label("Appraise:  IDLE",         { liveId = "appraise" })
    t:Label("Runtime:   0s",           { liveId = "runtime" })
    t:Section("Stats")
    t:Label("Caught:        0",        { liveId = "caught" })
    t:Label("Lost:          0",        { liveId = "lost" })
    t:Label("Success Rate:  0.0%",     { liveId = "rate" })
    t:Label("Fish / Hour:   0.0",      { liveId = "fph" })
    t:Label("Cast Timeouts: 0",        { liveId = "timeouts" })
    t:Label("Totems Popped: 0",        { liveId = "pops" })
end)()

;(function()
    local cat = GUI:AddCategory("Fishing")

    do
        local pc = cat:AddPanel("Cast")
        pc:Section("Casting")
        local castModes = {"Perfect", "Short", "Custom"}
        local castIdx = (MAIN.cast_mode == "short" and 2) or (MAIN.cast_mode == "custom" and 3) or 1
        pc:Dropdown("Cast Mode", castModes, castIdx, function(idx)
            MAIN.cast_mode = ({"perfect","short","custom"})[idx]; saveSettings()
        end)
        pc:Slider("Cast Power (Custom %)",  1.0, 100.0, MAIN.cast_power_custom,  { fmt="%.1f" }, function(v) MAIN.cast_power_custom=v; saveSettings() end)
        pc:Slider("Cast Timeout (ms)",      5000, 60000, MAIN.cast_timeout_ms,   { int=true, fmt="%d" }, function(v) MAIN.cast_timeout_ms=v; saveSettings() end)
        pc:Slider("Cycle Start Delay (ms)", 0, 5000, MAIN.pre_cast_delay_ms,    { int=true, fmt="%d" }, function(v) MAIN.pre_cast_delay_ms=v; saveSettings() end)
        pc:Slider("Post-Cast Delay (ms)",   0, 5000, MAIN.post_cast_delay_ms,   { int=true, fmt="%d" }, function(v) MAIN.post_cast_delay_ms=v; saveSettings() end)
        pc:Toggle("Re-cast on Timeout", MAIN.cast_on_timeout == 1,
            function(v) MAIN.cast_on_timeout = v and 1 or 0; saveSettings() end)
    end

    do
        local pr = cat:AddPanel("Reel")
        pr:Section("Fishing")
        pr:Slider("Fishing Action Delay (ms)",   0, 500, MAIN.fishing_action_delay_ms, { int=true, fmt="%d" }, function(v) MAIN.fishing_action_delay_ms=v; saveSettings() end)
        pr:Slider("Completion Threshold (%)",    0.0, 100.0, MAIN.completion_threshold, { fmt="%.1f" }, function(v) MAIN.completion_threshold=v; saveSettings() end)
        pr:Slider("Shake Interval (ms)",         1, 500, MAIN.shake_interval_ms,        { int=true, fmt="%d" }, function(v) MAIN.shake_interval_ms=v; saveSettings() end)
    end

    do
        local pl = cat:AddPanel("Lullaby")
        pl:Section("Lullaby (Metronome)")
        pl:Label("Auto-clicks the needle boxes for +Progress Speed (Lullaby only).", { color = THEME.subtext, size = 12 })
        pl:Label("Set the Mode to match what your rod is on (boxes differ per mode).", { color = THEME.subtext, size = 12 })
        local li = 1
        for i = 1, #RP.lullabyModes do if RP.lullabyModes[i] == MAIN.lullaby_mode then li = i end end
        pl:Dropdown("Mode", RP.lullabyModeLabels, li,
            function(idx) MAIN.lullaby_mode = RP.lullabyModes[idx] or "prismatic"; saveSettings() end)
    end

    do
        local prl = cat:AddPanel("Reliability")
        prl:Section("Reliability")
        prl:Label("Re-equips a dropped rod + restarts if it gets stuck (for AFK).", { color = THEME.subtext, size = 12 })
        prl:Toggle("Stall Watchdog", MAIN.watchdog_enabled == 1,
            function(v) MAIN.watchdog_enabled = v and 1 or 0; saveSettings() end)
        prl:Slider("Stall Timeout (s)", 8, 60, MAIN.watchdog_stall_sec, { int=true, fmt="%d" },
            function(v) MAIN.watchdog_stall_sec=v; saveSettings() end)
    end
end)()

;(function()
    local t = GUI:AddTab("Appraise")
    t:Section("Auto Appraise")
    t:Toggle("Master Switch", MAIN.auto_appraise_enabled == 1,
        function(v) MAIN.auto_appraise_enabled = v and 1 or 0; saveSettings() end)
    local mutations = {
        "Mythical","Abyssal","Glossy","Electric","Negative","Amber",
        "Fossilized","Silver","Darkened","Scorched","Albino","Lunar",
        "Mosaic","Translucent","Shiny","Big","Midas","Hexed","Frozen","Sparkling",
    }

    t:MultiSelect("Mutations", mutations, appraiseBaseList(),
        function(arr) MAIN.auto_appraise_mutations = table.concat(arr, ","); saveSettings() end)
    t:Section("Require Traits")
    t:Label("Shiny/Sparkling must match; any selected size matches.", { color = THEME.subtext, size = 12 })
    t:Toggle("Shiny",     MAIN.auto_appraise_shiny == 1,     function(v) MAIN.auto_appraise_shiny = v and 1 or 0; saveSettings() end)
    t:Toggle("Sparkling", MAIN.auto_appraise_sparkling == 1, function(v) MAIN.auto_appraise_sparkling = v and 1 or 0; saveSettings() end)
    t:Toggle("Tiny",      MAIN.auto_appraise_tiny == 1,      function(v) MAIN.auto_appraise_tiny = v and 1 or 0; saveSettings() end)
    t:Toggle("Small",     MAIN.auto_appraise_small == 1,     function(v) MAIN.auto_appraise_small = v and 1 or 0; saveSettings() end)
    t:Toggle("Big",       MAIN.auto_appraise_big == 1,       function(v) MAIN.auto_appraise_big = v and 1 or 0; saveSettings() end)
    t:Toggle("Giant",     MAIN.auto_appraise_giant == 1,     function(v) MAIN.auto_appraise_giant = v and 1 or 0; saveSettings() end)
    t:Section("Timing")
    t:Slider("Appraise Delay (ms)", 0, 5000, MAIN.appraise_delay_ms, { int=true, fmt="%d" },
        function(v) MAIN.appraise_delay_ms=v; saveSettings() end)
    t:Label("Status: Ready.", { liveId = "appraise_status" })
    t:Section("Guide")
    t:Label("Clicks IN PLACE (your mouse never moves).", { color = THEME.accent, size = 12 })
    t:Label("1. Choose a mutation/trait above.", { color = THEME.subtext })
    t:Label("2. Hold the fish + hover the cursor over the in-game Appraise button.", { color = THEME.subtext })
    t:Label("3. Press the APPRAISE hotkey (F5) and leave the cursor there.", { color = THEME.subtext })
    t:Label("Re-press (or Stop Appraise) to cancel. Auto-master + F1 still works too.", { color = THEME.subtext, size = 11 })
end)()

function RP.buildTotemTab()
    local t = GUI:AddTab("Totem")
    t:Section("!!! WARNING !!!")
    t:Label("THIS MIGHT BE DETECTABLE — I AM NOT SURE.", { color = THEME.danger, size = 14 })
    t:Label("USE AT YOUR OWN RISK.", { color = THEME.danger, size = 14 })
    t:Label("It moves/clicks to deploy totems, which is more detectable", { color = THEME.danger, size = 12 })
    t:Label("than the read-only features. Enable only if you accept the risk.", { color = THEME.danger, size = 12 })
    t:Section("Auto Totem")
    t:Label("Day/Night totems. Deploys at a safe boundary (won't ruin a catch).", { color = THEME.subtext, size = 12 })
    t:Toggle("Enabled", MAIN.auto_totem_enabled == 1,
        function(v) MAIN.auto_totem_enabled = v and 1 or 0; saveSettings() end)
    t:Dropdown("Mode", {"On Cycle", "Interval"}, MAIN.auto_totem_mode == "interval" and 2 or 1,
        function(idx) MAIN.auto_totem_mode = (idx == 2) and "interval" or "cycle"; saveSettings() end)
    t:Slider("Interval (sec)", 60, 7200, MAIN.auto_totem_interval_sec, { int=true, fmt="%d" },
        function(v) MAIN.auto_totem_interval_sec=v; saveSettings() end)

    local function totemChoices()
        local list = { "None" }
        for _, tt in ipairs(getHotbarTotems()) do list[#list + 1] = tt end
        for _, key in ipairs({ MAIN.auto_totem_day, MAIN.auto_totem_night }) do
            if key and key ~= "None" then
                local found = false
                for _, v in ipairs(list) do if v == key then found = true break end end
                if not found then list[#list + 1] = key end
            end
        end
        return list
    end
    local function idxOf(list, name)
        for i, v in ipairs(list) do if v == name then return i end end
        return 1
    end

    local dayItems = totemChoices()
    local dayWidget = t:Dropdown("Day Totem", dayItems, idxOf(dayItems, MAIN.auto_totem_day or "None"),
        function(_, val) MAIN.auto_totem_day = val or "None"; saveSettings() end)
    local nightItems = totemChoices()
    local nightWidget = t:Dropdown("Night Totem", nightItems, idxOf(nightItems, MAIN.auto_totem_night or "None"),
        function(_, val) MAIN.auto_totem_night = val or "None"; saveSettings() end)
    t:Button("Refresh Totem List", function()
        local di = totemChoices()
        dayWidget.items = di; dayWidget.idx = idxOf(di, MAIN.auto_totem_day or "None")
        local ni = totemChoices()
        nightWidget.items = ni; nightWidget.idx = idxOf(ni, MAIN.auto_totem_night or "None")
        notify(#di > 1 and ("Totems: " .. table.concat(di, ", ", 2)) or "No totems on hotbar.", "Auto Totem", 4)
    end)
    t:Label("Cycle: --   State: IDLE", { liveId = "totemcycle" })
end
RP.buildTotemTab()
RP.buildTotemTab = nil

RP.GPS = { active = false, x = 0, y = 0, z = 0, label = nil, dot = nil, status = "No waypoint set." }

function RP.gpsSet(raw)
    raw = tostring(raw or "")
    local nums = {}
    for n in raw:gmatch("[-+]?%d*%.?%d+") do nums[#nums + 1] = tonumber(n) end
    if #nums < 3 then
        RP.GPS.status = "Enter coordinates as X, Y, Z."
        notify(RP.GPS.status, "GPS", 3)
        return false
    end
    RP.GPS.x, RP.GPS.y, RP.GPS.z = nums[1], nums[2], nums[3]
    RP.GPS.active = true
    RP.GPS.status = string.format("Waypoint: %.1f, %.1f, %.1f", nums[1], nums[2], nums[3])
    notify("GPS waypoint set.", "GPS", 2)
    return true
end

function RP.gpsClear()
    RP.GPS.active = false
    RP.GPS.status = "No waypoint set."
    if RP.GPS.label then pcall(_setIndex, RP.GPS.label, "Visible", false) end
    if RP.GPS.dot then pcall(_setIndex, RP.GPS.dot, "Visible", false) end
end

function RP.gpsCurrent()
    local hrp = getHRP()
    if not hrp then notify("Could not read your position.", "GPS", 3); return nil end
    local ok, p = pcall(_index, hrp, "Position")
    if not ok or not p then notify("Could not read your position.", "GPS", 3); return nil end
    return string.format("%.1f, %.1f, %.1f", p.X, p.Y, p.Z)
end

do
    local cat = GUI:AddCategory("Teleport")
    local function addTp(catId, name)
        local data = TP.cats[catId]
        local p = cat:AddPanel(name)
        p:Section(name)
        p:Label("Stationary only — STOP the macro (F1) before teleporting.", { color = THEME.subtext, size = 12 })
        local dd = p:SearchDropdown("Destination", data.names, function() end)
        p:Label("Click the box, then TYPE to filter. Backspace deletes.", { color = THEME.subtext, size = 11 })
        p:Button("Teleport", function()
            TP.go(dd.selName, data.map[dd.selName])
        end)
        p:Label("Status: pick a destination.", { liveId = "tp_status", color = THEME.subtext, size = 12 })
    end
    addTp("items",     "Items")
    addTp("npcs",      "NPCs")
    addTp("fishAreas", "Fish Areas")
    addTp("spots",     "Spots")
end

;(function()
    local t = GUI:AddTab("GPS")
    t:Section("Coordinate Finder")

    local gpsX = t:SearchDropdown("X Coordinate", { "19498" }, function() end)
    local gpsY = t:SearchDropdown("Y Coordinate", { "335" }, function() end)
    local gpsZ = t:SearchDropdown("Z Coordinate", { "5553" }, function() end)
    gpsX.selName, gpsY.selName, gpsZ.selName = "19498", "335", "5553"
    gpsX.filter, gpsY.filter, gpsZ.filter = "19498", "335", "5553"
    gpsX.preserveFilter, gpsY.preserveFilter, gpsZ.preserveFilter = true, true, true

    t:Label("Click each box and type one coordinate. Minus signs and decimals work.", { color = THEME.subtext, size = 11 })
    t:Button("Set GPS Waypoint", function()
        local x = (gpsX.filter and gpsX.filter ~= "") and gpsX.filter or gpsX.selName
        local y = (gpsY.filter and gpsY.filter ~= "") and gpsY.filter or gpsY.selName
        local z = (gpsZ.filter and gpsZ.filter ~= "") and gpsZ.filter or gpsZ.selName
        RP.gpsSet(tostring(x or "") .. "," .. tostring(y or "") .. "," .. tostring(z or ""))
    end)
    t:Button("Use My Current Position", function()
        local raw = RP.gpsCurrent()
        if raw then
            local vals = {}
            for n in raw:gmatch("[-+]?%d*%.?%d+") do vals[#vals + 1] = n end
            if #vals >= 3 then
                gpsX.filter, gpsX.selName = vals[1], vals[1]
                gpsY.filter, gpsY.selName = vals[2], vals[2]
                gpsZ.filter, gpsZ.selName = vals[3], vals[3]
                GUI:BuildWidgets()
                RP.gpsSet(raw)
            end
        end
    end)
    t:Button("Clear GPS Waypoint", function() RP.gpsClear() end)
    t:Label("No waypoint set.", { liveId = "gps_status", color = THEME.accent, size = 12 })
    t:Label("The waypoint uses a small dot and compact distance label.", { color = THEME.subtext, size = 11 })
end)()

-- Start the GPS renderer immediately when the script loads.
task.spawn(function()
    if type(WorldToScreen) ~= "function" or not Drawing or type(Drawing.new) ~= "function" then
        RP.GPS.status = "GPS marker unavailable in this executor."
        return
    end

    RP.GPS.label = Drawing.new("Text")
    RP.GPS.label.Size = 15
    RP.GPS.label.Center = true
    RP.GPS.label.Outline = true
    RP.GPS.label.Visible = false

    RP.GPS.dot = Drawing.new("Circle")
    RP.GPS.dot.Radius = 3
    RP.GPS.dot.Filled = true
    RP.GPS.dot.Visible = false

    while not KILL do
        if RP.GPS.active then
            local target = Vector3.new(RP.GPS.x, RP.GPS.y, RP.GPS.z)
            local ok, a, b, c = pcall(WorldToScreen, target)
            local sx, sy, visible = nil, nil, true

            if ok then
                if type(a) == "number" and type(b) == "number" then
                    sx, sy = a, b
                    if type(c) == "boolean" then visible = c end
                elseif a then
                    pcall(function() sx, sy = a.X, a.Y end)
                    if type(b) == "boolean" then visible = b end
                end
            end

            local distance = nil
            local hrp = getHRP()
            if hrp then
                local okp, pos = pcall(_index, hrp, "Position")
                if okp and pos then pcall(function() distance = (pos - target).Magnitude end) end
            end

            if sx and sy and visible ~= false then
                RP.GPS.label.Text = distance and string.format("GPS %d", math.floor(distance + 0.5)) or "GPS"
                RP.GPS.label.Position = Vector2.new(sx, sy - 15)
                RP.GPS.dot.Position = Vector2.new(sx, sy)
                RP.GPS.label.Visible = true
                RP.GPS.dot.Visible = true
                RP.GPS.status = string.format("Waypoint: %.1f, %.1f, %.1f%s", RP.GPS.x, RP.GPS.y, RP.GPS.z, distance and string.format("  •  %d studs", math.floor(distance + 0.5)) or "")
            else
                RP.GPS.label.Visible = false
                RP.GPS.dot.Visible = false
                RP.GPS.status = string.format("Waypoint: %.1f, %.1f, %.1f  •  off-screen", RP.GPS.x, RP.GPS.y, RP.GPS.z)
            end
        else
            RP.GPS.label.Visible = false
            RP.GPS.dot.Visible = false
        end
        task.wait(0.03)
    end
end)

do
    local cat = GUI:AddCategory("Hunts")

    local pd = cat:AddPanel("Detect")
    pd:Section("Hunt Detection")
    pd:Toggle("Hunt Detection", MAIN.hunt_detect_enabled == 1, function(on)
        MAIN.hunt_detect_enabled = on and 1 or 0; saveSettings()
    end)
    local hd = pd:SearchDropdown("Target hunt", HUNT.KNOWN, function() end)
    if MAIN.hunt_detect_target ~= "" then hd.selName = MAIN.hunt_detect_target end
    pd:Label("Click the box, TYPE to filter, then Set target.", { color = THEME.subtext, size = 11 })
    pd:Button("Set target", function()
        MAIN.hunt_detect_target = hd.selName or ""; saveSettings()
        notify("Hunt target: " .. (MAIN.hunt_detect_target ~= "" and MAIN.hunt_detect_target or "(none)"), "ZeroDeath Hunt", 3)
    end)
    pd:Toggle("Continue fishing after detect (off = stop)", MAIN.hunt_continue_after == 1, function(on)
        MAIN.hunt_continue_after = on and 1 or 0; saveSettings()
    end)
    pd:Label("Detected: none", { liveId = "hunt_detected", color = THEME.accent, size = 12 })

    local pl = cat:AddPanel("Live")
    pl:Section("Live Active Hunts")
    pl:Label("Auto-updates while this tab is open. Click a hunt to teleport to it", { color = THEME.subtext, size = 11 })
    pl:Label("(STOP the macro with F1 first).", { color = THEME.subtext, size = 11 })
    pl:Label("Status: scanning…", { liveId = "hunt_status", color = THEME.subtext, size = 12 })

    for i = 1, 5 do
        pl:Button("—", function()
            local h = HUNT.active[i]
            if h then HUNT.teleportTo(h.name) else notify("No hunt there.", "ZeroDeath Hunt", 2) end
        end, "hunt_btn_" .. i)
    end
end

;(function()
    local t = GUI:AddTab("Weather")
    t:Section("Auto Weather")
    t:Toggle("Auto Weather", MAIN.auto_weather_enabled == 1,
        function(v) MAIN.auto_weather_enabled = v and 1 or 0; saveSettings() end)
    local wkeys = { "none","aurora","starfall","rainbow","eclipse","clear","windy","rain","foggy",
                    "shiny surge","night of the luminous","mutation surge" }
    local wIdx = 1; for i, k in ipairs(wkeys) do if k == MAIN.weather_target then wIdx = i end end
    t:Dropdown("Target weather", wkeys, wIdx, function(idx)
        MAIN.weather_target = wkeys[idx] or "none"; saveSettings()
    end)
    local totems = { "None" }
    for _, tt in ipairs(getHotbarTotems()) do totems[#totems + 1] = tt end
    if MAIN.weather_totem ~= "" then
        local f = false; for _, v in ipairs(totems) do if v == MAIN.weather_totem then f = true end end
        if not f then totems[#totems + 1] = MAIN.weather_totem end
    end
    local td = t:SearchDropdown("Weather totem (hotbar)", totems, function() end)
    if MAIN.weather_totem ~= "" then td.selName = MAIN.weather_totem end
    t:Button("Set totem", function()
        MAIN.weather_totem = (td.selName and td.selName ~= "None") and td.selName or ""; saveSettings()
        notify("Weather totem: " .. (MAIN.weather_totem ~= "" and MAIN.weather_totem or "(none)"), "ZeroDeath Weather", 3)
    end)
    t:Label("Deploys the totem (at a safe cast moment) when the target isn't active.", { color = THEME.subtext, size = 11 })
    t:Section("Current Weather")
    t:Label("Weather: —", { liveId = "wx_normal",  color = THEME.text,   size = 12 })
    t:Label("Special: —", { liveId = "wx_special", color = THEME.text,   size = 12 })
    t:Label("Event:   —", { liveId = "wx_event",   color = THEME.text,   size = 12 })
    t:Label("Target:  —", { liveId = "wx_target",  color = THEME.accent, size = 12 })
end)()

;(function()
    local t = GUI:AddTab("Misc")
    t:Section("Daily Shop")
    t:Label("Refresh: —", { liveId = "misc_shop_timer", color = THEME.subtext, size = 12 })
    for i = 1, 6 do
        t:Label("—", { liveId = "misc_shop_" .. i, color = THEME.text, size = 12 })
    end
    t:Section("Sunken Chest")
    t:Label("Spawns: —", { liveId = "misc_chest", color = THEME.text, size = 13 })
    t:Section("Orca Migration")
    t:Label("Spawns: —", { liveId = "misc_orca", color = THEME.text, size = 13 })
end)()

;(function()
    local cat = GUI:AddCategory("Webhook")

    local ps = cat:AddPanel("Summary")
    ps:Section("Discord Webhook")
    ps:Toggle("Enabled", MAIN.webhook_enabled == 1,
        function(v) MAIN.webhook_enabled = v and 1 or 0; saveSettings() end)
    ps:Slider("Summary Interval (min)", 1, 360, MAIN.webhook_summary_interval_min, { int=true, fmt="%d" },
        function(v) MAIN.webhook_summary_interval_min=v; saveSettings() end)
    ps:Label("URL: (loading)", { liveId = "webhook_url", color = THEME.subtext, size = 12 })
    ps:Label("Ping ID: (none)", { liveId = "webhook_ping", color = THEME.subtext, size = 11 })
    ps:Label("Paste in webhook.txt — line 1 = URL, line 2 = user ID. Auto-loads", { color = THEME.subtext, size = 11 })
    ps:Label("on save and is kept in the settings JSON.", { color = THEME.subtext, size = 11 })
    ps:Button("Copy webhook.txt Path", function()
        if type(setclipboard) == "function" then setclipboard(WEBHOOK_URL_PATH) end
        notify("Path copied. Put URL on line 1, user ID on line 2, then save.", "Webhook", 5)
    end)
    ps:Button("Send Test Summary", function()
        if MAIN.webhook_url == "" then notify("No URL set yet. Paste it into webhook.txt first.", "Webhook", 3); return end
        if WebhookSession.startedAt == 0 then
            WebhookSession.startedAt     = tick() * 1000
            WebhookSession.lastSummaryAt = tick() * 1000
        end
        postWebhook(MAIN.webhook_url, buildSummaryPayload())
        notify("Test summary sent.", "Webhook", 2)
    end)
    ps:Section("Summary Fields")
    ps:Toggle("Fish Caught/Lost",  MAIN.webhook_summary_fish == 1,         function(v) MAIN.webhook_summary_fish = v and 1 or 0; saveSettings() end)
    ps:Toggle("Success Rate",      MAIN.webhook_summary_success_rate == 1, function(v) MAIN.webhook_summary_success_rate = v and 1 or 0; saveSettings() end)
    ps:Toggle("Fish / Hour",       MAIN.webhook_summary_fish_per_hour == 1,function(v) MAIN.webhook_summary_fish_per_hour = v and 1 or 0; saveSettings() end)
    ps:Toggle("Rod",               MAIN.webhook_summary_rod == 1,          function(v) MAIN.webhook_summary_rod = v and 1 or 0; saveSettings() end)
    ps:Toggle("Tracker Mode",      MAIN.webhook_summary_tracker == 1,      function(v) MAIN.webhook_summary_tracker = v and 1 or 0; saveSettings() end)
    ps:Toggle("Day/Night Cycle",   MAIN.webhook_summary_cycle == 1,        function(v) MAIN.webhook_summary_cycle = v and 1 or 0; saveSettings() end)
    ps:Toggle("Auto Totem State",  MAIN.webhook_summary_totem_state == 1,  function(v) MAIN.webhook_summary_totem_state = v and 1 or 0; saveSettings() end)
    ps:Toggle("Totems Popped",     MAIN.webhook_summary_totem_pops == 1,   function(v) MAIN.webhook_summary_totem_pops = v and 1 or 0; saveSettings() end)
    ps:Toggle("Session Runtime",   MAIN.webhook_summary_session_time == 1, function(v) MAIN.webhook_summary_session_time = v and 1 or 0; saveSettings() end)
    ps:Toggle("Cast Timeouts",     MAIN.webhook_summary_cast_timeouts == 1,function(v) MAIN.webhook_summary_cast_timeouts = v and 1 or 0; saveSettings() end)
    ps:Toggle("Activity",          MAIN.webhook_summary_activity == 1,     function(v) MAIN.webhook_summary_activity = v and 1 or 0; saveSettings() end)
    ps:Toggle("Lua Memory",        MAIN.webhook_summary_mem == 1,          function(v) MAIN.webhook_summary_mem = v and 1 or 0; saveSettings() end)

    local pa = cat:AddPanel("Alerts")
    pa:Section("AFK Alerts")
    pa:Toggle("Start Alert",       MAIN.webhook_alert_start == 1,          function(v) MAIN.webhook_alert_start = v and 1 or 0; saveSettings() end)
    pa:Toggle("Stop Alert",        MAIN.webhook_alert_stop == 1,           function(v) MAIN.webhook_alert_stop = v and 1 or 0; saveSettings() end)
    pa:Toggle("Stall Alert (no catches)", MAIN.webhook_alert_stall == 1,   function(v) MAIN.webhook_alert_stall = v and 1 or 0; saveSettings() end)
    pa:Slider("Stall After (min)", 1, 60, MAIN.webhook_stall_minutes, { int=true, fmt="%d" }, function(v) MAIN.webhook_stall_minutes=v; saveSettings() end)
    pa:Toggle("Milestone Pings",   MAIN.webhook_milestone == 1,            function(v) MAIN.webhook_milestone = v and 1 or 0; saveSettings() end)
    pa:Slider("Milestone Every (fish)", 10, 1000, MAIN.webhook_milestone_every, { int=true, fmt="%d" }, function(v) MAIN.webhook_milestone_every=v; saveSettings() end)
    pa:Toggle("Alert: Totem Failed", MAIN.webhook_alert_totem_failed == 1, function(v) MAIN.webhook_alert_totem_failed = v and 1 or 0; saveSettings() end)
    pa:Toggle("@Mention Me on Alerts", MAIN.webhook_ping_on_alerts == 1,   function(v) MAIN.webhook_ping_on_alerts = v and 1 or 0; saveSettings() end)

    local ph = cat:AddPanel("Hunts")
    ph:Section("Hunt Alerts")
    ph:Label("Pings Discord when a SELECTED hunt is announced in chat.", { color = THEME.subtext, size = 12 })
    ph:Toggle("Hunt Alerts Enabled", MAIN.hunt_alerts_enabled == 1,
        function(v) MAIN.hunt_alerts_enabled = v and 1 or 0; HD.primed = false; saveSettings() end)

    ph:MultiSelect("Hunts to Webhook", HD.allNames(), HD.selectedList(),
        function(arr) MAIN.hunt_alerts_selected = table.concat(arr, ","); saveSettings() end, true)
    ph:Label("Click to open, TYPE to filter, click hunts to toggle. Uses @Mention if on.", { color = THEME.subtext, size = 11 })
end)()

;(function()
    local t = GUI:AddTab("About")
    t:Section("Hotkeys  (click a row, then press a key)")
    t:Keybind("Start / Stop",       "hk_start_macro")
    t:Keybind("Appraise Held Fish", "hk_appraise")
    t:Keybind("Stop Appraise",      "hk_stop_appraise")
    t:Keybind("Toggle GUI Menu",    "hk_toggle_menu")
    t:Keybind("Refresh / Cache",    "hk_fix_attach")
    t:Keybind("Stop + Save",        "hk_reload_macro")
    t:Label(" [ key:       Reload macro  (fixed)", { color = THEME.subtext, size = 12 })
    t:Section("Settings")
    t:Label("Everything you toggle auto-saves to the settings JSON",  { color = THEME.subtext, size = 12 })
    t:Label("(webhook URL + ping ID included). Edit it directly to remap hotkeys.", { color = THEME.subtext, size = 12 })
    t:Button("Copy Settings JSON Path", function()
        if type(setclipboard) == "function" then setclipboard(SETTINGS_PATH) end
        notify("Path copied. Everything you change is auto-saved here.", "Settings", 4)
    end)
    t:Button("Reload Settings from JSON", function()
        loadSettings()
        notify("Settings reloaded from JSON.", "Settings", 2)
    end)
    t:Section("About")
    t:Label("ZeroDeath fisch  (matcha)")
    t:Label("Version: 1.7 (hotfix 5)",                   { color = THEME.accent, size = 13 })
    t:Label("Executor: " .. execName(),                { color = THEME.subtext, size = 12 })
    t:Label("Roblox build: version-ad5d3e2906444472",  { color = THEME.subtext, size = 12 })
    t:Label("Unsafe LuaU: " .. (hasUnsafe and "ENABLED" or "DISABLED"),
        { color = hasUnsafe and THEME.good or THEME.danger, size = 12 })
    t:Label("Lua memory: --- KB", { liveId = "mem", color = THEME.subtext, size = 12 })
    t:Label("Color cue only: red above 30k KB. No leak alerts.", { color = THEME.subtext, size = 11 })
    t:Section("Debug")
    t:Toggle("Debug Logging", MAIN.debug_logging == 1,
        function(v) MAIN.debug_logging = v and 1 or 0; saveSettings() end)
    t:Label("ONLY ENABLE IF ZERODEATH SAID SO.", { color = THEME.danger, size = 13 })
    t:Label("Logs per-tick state to zerodeath_debug.txt for diagnosing issues.", { color = THEME.subtext, size = 11 })
    t:Label("Off by default — leave it off unless asked.", { color = THEME.subtext, size = 11 })
    t:Button("Reset Stats", function()
        Macro.fishCaughtCount  = 0
        Macro.fishLostCount    = 0
        Macro.castTimeoutCount = 0
        Macro.totemPopCount    = 0
        WebhookSession.startedAt    = 0
        WebhookSession.lastSummaryAt= 0
        notify("Stats reset.", "ZeroDeath fisch", 2)
    end)
end)()

GUI:Rebuild()

local HUD = { pool = {}, x = MAIN.hud_x or 16, y = MAIN.hud_y or 150, w = 150, h = 0, sig = nil, dragging = false }

function HUD.memColor(kb) return (kb and kb > 30000) and THEME.danger or THEME.good end
function HUD.clear()
    for i = #HUD.pool, 1, -1 do pcall(HUD.pool[i].Remove, HUD.pool[i]); HUD.pool[i] = nil end
end
function HUD.build()
    HUD.clear()

    local fishing   = Macro.cycleEnabled and Macro.phase ~= "OFF" and Macro.phase ~= "APPRAISE"
    local appraising = Macro.cycleEnabled and Macro.phase == "APPRAISE"
    local rows = {
        { fishing and (MAIN.auto_reel_only == 1 and "Auto Reel" or "Auto Fish") or "Auto Fish", fishing },
        { appraising and "Appraising..." or "Auto Appraise", appraising or MAIN.auto_appraise_enabled == 1 },
        { "Auto Totem",    MAIN.auto_totem_enabled == 1 },
        { "Webhook",       MAIN.webhook_enabled == 1 },
    }
    local x, y, w = HUD.x, HUD.y, 150
    local headerH, rowH = 22, 18
    local h = headerH + #rows * rowH + 6 + rowH + 5
    HUD.w, HUD.h = w, h
    mkDraw("Square", { Visible = true, Filled = true, Color = THEME.bg, Transparency = 0.86,
        Position = Vector2.new(x, y), Size = Vector2.new(w, h), ZIndex = 95 }, HUD.pool)
    mkDraw("Square", { Visible = true, Filled = true, Color = THEME.accent, Transparency = 1,
        Position = Vector2.new(x, y), Size = Vector2.new(3, h), ZIndex = 96 }, HUD.pool)
    mkDraw("Line", { Visible = true, Color = THEME.border, Transparency = 1,
        From = Vector2.new(x, y + headerH - 2), To = Vector2.new(x + w, y + headerH - 2), Thickness = 1, ZIndex = 96 }, HUD.pool)
    mkDraw("Text", { Visible = true, Color = THEME.accent, Transparency = 1, Outline = true, Center = false,
        Position = Vector2.new(x + 9, y + 5), Size = 12, Font = Drawing.Fonts.SystemBold,
        Text = "ZeroDeath", ZIndex = 97 }, HUD.pool)
    local ry = y + headerH + 1
    for _, r in ipairs(rows) do
        local on = r[2]

        mkDraw("Square", { Visible = true, Filled = true, Color = on and THEME.good or THEME.track, Transparency = 1,
            Position = Vector2.new(x + 9, ry + 3), Size = Vector2.new(7, 7), ZIndex = 97 }, HUD.pool)
        mkDraw("Text", { Visible = true, Color = on and THEME.text or THEME.subtext, Transparency = 1,
            Outline = true, Center = false,
            Position = Vector2.new(x + 23, ry), Size = 12, Font = Drawing.Fonts.System,
            Text = r[1], ZIndex = 97 }, HUD.pool)
        ry = ry + rowH
    end

    mkDraw("Line", { Visible = true, Color = THEME.border, Transparency = 1,
        From = Vector2.new(x, ry + 1), To = Vector2.new(x + w, ry + 1), Thickness = 1, ZIndex = 96 }, HUD.pool)
    local mkb = 0
    local okM, kbv = pcall(gcinfo)
    if okM and kbv then mkb = math.floor(kbv) end
    local memCol = HUD.memColor(mkb)
    HUD.memText = mkDraw("Text", { Visible = true, Color = memCol, Transparency = 1,
        Outline = true, Center = false,
        Position = Vector2.new(x + 9, ry + 5), Size = 12, Font = Drawing.Fonts.SystemBold,
        Text = "Lua: " .. mkb .. " KB", ZIndex = 97 }, HUD.pool)
end
function HUD.update()
    if MAIN.show_status_hud ~= 1 then
        if #HUD.pool > 0 then HUD.clear(); HUD.sig = nil end
        return
    end
    local fishing   = Macro.cycleEnabled and Macro.phase ~= "OFF" and Macro.phase ~= "APPRAISE"
    local appraising = Macro.cycleEnabled and Macro.phase == "APPRAISE"
    local sig = table.concat({
        fishing and "1" or "0", appraising and "1" or "0", MAIN.auto_reel_only,
        MAIN.auto_appraise_enabled, MAIN.auto_totem_enabled, MAIN.webhook_enabled,
    }, "|")
    if sig ~= HUD.sig then HUD.sig = sig; pcall(HUD.build) end

    if HUD.memText then
        local okM, kbv = pcall(gcinfo)
        if okM and kbv then
            local mkb = math.floor(kbv)
            pcall(_setIndex, HUD.memText, "Text", "Lua: " .. mkb .. " KB")
            pcall(_setIndex, HUD.memText, "Color", HUD.memColor(mkb))
        end
    end
end
HUD.update()

task.spawn(function()
    while not KILL do
        pcall(HUD.update)

        HUNT.wantLive = (GUI.visible and GUI.categories[GUI.activeCat]
                         and GUI.categories[GUI.activeCat].name == "Hunts") and true or false
        MISC.wantLive = (GUI.visible and GUI.categories[GUI.activeCat]
                         and GUI.categories[GUI.activeCat].name == "Misc") and true or false
        if GUI.visible then
          pcall(function()
            local total = Macro.fishCaughtCount + Macro.fishLostCount
            local rate  = total > 0 and (Macro.fishCaughtCount / total) * 100.0 or 0
            local runtime = WebhookSession.startedAt > 0 and (tick()*1000 - WebhookSession.startedAt) or 0
            local statusText
            if not Macro.cycleEnabled and Macro.phase == "OFF" then
                statusText = "OFF"
            elseif Macro.phase == "APPRAISE" then
                statusText = "APPRAISE " .. Macro.appraiseState
            elseif Macro.totemState ~= "IDLE" then
                statusText = "TOTEM " .. Macro.totemState
            elseif Macro.phase == "REELWATCH" then
                statusText = "WAITING (cast manually)"
            else
                statusText = Macro.phase
            end
            GUI:SetLabel("status",   "Status:    " .. statusText)
            GUI:SetLabel("rod",      "Rod:       " .. (ROD ~= "" and ROD or "---"))
            GUI:SetLabel("profile",  "Profile:   " .. (ROD_KIND or "default"))
            GUI:SetLabel("power",    "Power:     " .. (Macro.powerPercent ~= "" and (Macro.powerPercent .. "%") or "---"))
            GUI:SetLabel("prog",     "Progress:  " .. (Macro.progressPercent ~= "" and (Macro.progressPercent .. "%") or "---"))
            GUI:SetLabel("totem",    "Totem:     " .. Macro.totemState)
            GUI:SetLabel("totemcycle", "Cycle: " .. (getGameCycleIsDay() and "Day" or "Night") .. "   State: " .. Macro.totemState)
            GUI:SetLabel("appraise", "Appraise:  " .. Macro.appraiseState)
            GUI:SetLabel("runtime",  "Runtime:   " .. formatRuntime(runtime))
            GUI:SetLabel("caught",   "Caught:        " .. Macro.fishCaughtCount)
            GUI:SetLabel("lost",     "Lost:          " .. Macro.fishLostCount)
            GUI:SetLabel("rate",     string.format("Success Rate:  %.1f%%", rate))
            local fphHrs = runtime / 3600000
            GUI:SetLabel("fph",      string.format("Fish / Hour:   %.1f",
                fphHrs > 0.0001 and (Macro.fishCaughtCount / fphHrs) or 0))
            GUI:SetLabel("timeouts", "Cast Timeouts: " .. Macro.castTimeoutCount)
            GUI:SetLabel("pops",     "Totems Popped: " .. Macro.totemPopCount)

            GUI:SetLabel("appraise_status", "Status: " .. appraiseStatus)

            GUI:SetLabel("tp_status", "Status: " .. TP.status)
            GUI:SetLabel("gps_status", RP.GPS.status)

            GUI:SetLabel("hunt_detected", "Detected: " .. (HUNT.detected or "none"))
            local nh = #HUNT.active
            GUI:SetLabel("hunt_status", nh > 0 and ("Active hunts: " .. nh .. "  — click one to teleport")
                or ((MAIN.hunt_detect_enabled == 1 or HUNT.wantLive)
                    and ("Scanning…  (" .. (HUNT.lastBudget or 0) .. " objects)")
                    or "Open the Live tab to start."))
            for i = 1, 5 do
                local h = HUNT.active[i]
                GUI:SetLabel("hunt_btn_" .. i, h and ("▸  " .. h.name .. "   ·   " .. h.location) or "—")
            end

            if MISC.wantLive then
                local sh = MISC.shop
                GUI:SetLabel("misc_shop_timer", "Refresh: " .. (sh.timer ~= "" and sh.timer or "—"))
                for i = 1, 6 do
                    local it = sh.items[i]
                    GUI:SetLabel("misc_shop_" .. i, it and ((it.sold and "[SOLD] " or "") .. it.name
                        .. (it.price ~= "" and ("   " .. it.price) or "")
                        .. (it.qty ~= "" and ("   " .. it.qty) or "")) or "—")
                end

                local up = MISC.liveUptime()
                local cs, cr   = MISC.cycle(up, 3600, 4200, 600)
                local oss, orr = MISC.cycle(up, 3600, 4500, 900)
                GUI:SetLabel("misc_chest", (cs == "ACTIVE" and ("● ACTIVE — ends in " .. MISC.fmt(cr)))
                    or (cs == "WAITING" and ("Spawns in " .. MISC.fmt(cr)))
                    or "— (waiting for server data)")
                GUI:SetLabel("misc_orca", (oss == "ACTIVE" and ("● ACTIVE — ends in " .. MISC.fmt(orr)))
                    or (oss == "WAITING" and ("Spawns in " .. MISC.fmt(orr)))
                    or "— (waiting for server data)")
            end

            if GUI.categories[GUI.activeCat] and GUI.categories[GUI.activeCat].name == "Weather" then
                local wx  = getCurrentWeather()
                local met = getWorldNested("weather", "meteorological")
                local evt = getCurrentEvent()
                GUI:SetLabel("wx_normal",  "Weather: " .. (wx  ~= "" and wx  or "—"))
                GUI:SetLabel("wx_special", "Special: " .. (met ~= "" and met or "—"))
                GUI:SetLabel("wx_event",   "Event:   " .. (evt ~= "" and evt or "—"))
                local tgt = MAIN.weather_target
                GUI:SetLabel("wx_target", (tgt == "none" or tgt == "") and "Target:  (none set)"
                    or ("Target:  " .. tgt .. "  —  " .. (weatherActive(tgt) and "ACTIVE ✓" or "not active")))
            end

            local wu = MAIN.webhook_url
            GUI:SetLabel("webhook_url", "URL: " .. (wu ~= "" and ("✓ set (" .. wu:sub(1, 40) .. "...)") or "✗ not set — paste into webhook.txt"))
            GUI:SetLabelColor("webhook_url", wu ~= "" and THEME.good or THEME.danger)
            local uid = MAIN.webhook_user_id or ""
            GUI:SetLabel("webhook_ping", "Ping ID: " .. (uid ~= "" and uid or "(none — add to webhook.txt line 2)"))
            GUI:SetLabelColor("webhook_ping", uid ~= "" and THEME.good or THEME.subtext)

            if type(gcinfo) == "function" then
                local okM, kb = pcall(gcinfo)
                if okM and kb then
                    kb = math.floor(kb)
                    GUI:SetLabel("mem", string.format("Lua memory: %d KB", kb))
                    GUI:SetLabelColor("mem", HUD.memColor(kb))
                end
            end
          end)
        end
        task.wait(0.2)
    end
end)

task.spawn(function()
    local hudPrev = false
    while not KILL do
        pcall(GUI.Update, GUI)

        pcall(function()
        if MAIN.show_status_hud == 1 and robloxActive() then
            local mx, my = getMouseXY()
            local down = (ismouse1pressed and ismouse1pressed()) or false
            local onMenu = GUI.visible and pointInBox(mx, my, GUI.pos.X, GUI.pos.Y, GUI.size.X, GUI.size.Y)
            if down and not hudPrev and not onMenu and HUD.h > 0 and pointInBox(mx, my, HUD.x, HUD.y, HUD.w, HUD.h) then
                HUD.dragging = true
                HUD.dragOffX = mx - HUD.x
                HUD.dragOffY = my - HUD.y
            end
            if HUD.dragging and down then
                local nx, ny = mx - HUD.dragOffX, my - HUD.dragOffY
                local cam = workspace.CurrentCamera
                if cam and cam.ViewportSize then
                    nx = math.max(0, math.min(cam.ViewportSize.X - 40, nx))
                    ny = math.max(0, math.min(cam.ViewportSize.Y - 24, ny))
                end
                if nx ~= HUD.x or ny ~= HUD.y then
                    HUD.x, HUD.y = nx, ny
                    pcall(HUD.build)
                end
            elseif HUD.dragging and not down then
                HUD.dragging = false
                MAIN.hud_x, MAIN.hud_y = HUD.x, HUD.y
                saveSettings()
            end
            hudPrev = down
        end
        end)

        task.wait()
    end
end)

task.spawn(function()
    local insertPrev = false
    local rmbPrev    = false
    local pgUpPrev   = false
    local pgDnPrev   = false
    while not KILL do

      pcall(function()
        local insertNow = (iskeypressed and iskeypressed(MAIN.hk_toggle_menu or 0x2E)) or false
        if insertNow and not insertPrev then GUI:Toggle() end
        insertPrev = insertNow

        if GUI.visible then
            if GUI._rebindTarget then
                GUI:CaptureRebind()
            else
                local atab = GUI:activePanel()
                if atab then
                    for _, w in ipairs(atab.widgets) do
                        if w.kind == "dropdown" and w.searchable and w.open then
                            GUI:PollSearchKeys(w); break
                        end
                    end
                end
            end
        end

        if clickPickerActive and iskeypressed and iskeypressed(0x1B) then
            clickPickerActive = false
            setAppraiseStatus("Click point pick cancelled.")
        end

        local rmbNow = (ismouse2pressed and ismouse2pressed()) or false
        if rmbNow and not rmbPrev and robloxActive() then
            if clickPickerActive then
                local px, py = getMouseXY()
                px, py = math.floor(px + 0.5), math.floor(py + 0.5)
                MAIN.auto_appraise_click_x = px
                MAIN.auto_appraise_click_y = py
                saveSettings()
                clickPickerActive = false
                setAppraiseStatus(string.format("Click point saved: %d, %d.", px, py))
                notify("Click point saved: " .. px .. ", " .. py, "ZeroDeath fisch", 3)
            elseif GUI.visible then
                local mx, my = getMouseXY()
                GUI:HandleRightClick(mx, my)
            end
        end
        rmbPrev = rmbNow

        local pgUp = (iskeypressed and iskeypressed(0x21)) or false
        local pgDn = (iskeypressed and iskeypressed(0x22)) or false
        if GUI.visible then
            local page = math.max(40, math.floor(GUI.contentViewH * 0.7))
            if pgDn and not pgDnPrev then GUI:ScrollBy(page) end
            if pgUp and not pgUpPrev then GUI:ScrollBy(-page) end
        end
        pgUpPrev = pgUp
        pgDnPrev = pgDn
      end)

        task.wait(0.03)
    end
end)

ROD = getHotbarRodName()

do
    local okE, exists = pcall(isfile, WEBHOOK_URL_PATH)
    if okE and not exists then
        pcall(writefile, WEBHOOK_URL_PATH,
            "# Paste your Discord webhook URL on the FIRST line below.\n" ..
            "# (Optional) put your Discord user ID on the SECOND line for @mention pings.\n")
    end
end
if loadWebhookUrlFromFile() then
    print("[ZeroDeath] Webhook config loaded from " .. WEBHOOK_URL_PATH)
end
notify("Press " .. vkName(MAIN.hk_toggle_menu) .. " to open the ZeroDeath tabs. Hotkey: "
    .. vkName(MAIN.hk_start_macro) .. " starts the macro.",
    "ZeroDeath fisch · v1.7 (hotfix 5)", 4)
print(string.format("[ZeroDeath] loaded. Unsafe LuaU = %s. Rod = %s",
    tostring(hasUnsafe), ROD ~= "" and ROD or "?"))

while not KILL do task.wait(60) end
