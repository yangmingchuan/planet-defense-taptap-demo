-- Engine-free regression test for the real Lua input and layout code.
package.preload["LuaScripts/Utilities/Sample"] = function() return {} end
package.preload["urhox-libs/UI"] = function() return {} end
MOUSEB_LEFT = 1
NVG_ALIGN_LEFT, NVG_ALIGN_CENTER, NVG_ALIGN_RIGHT, NVG_ALIGN_MIDDLE = 1, 2, 4, 16
local rendered = {}
local draws = 0
local names = { "BeginPath", "Rect", "RoundedRect", "Circle", "MoveTo", "LineTo",
    "FillColor", "Fill", "StrokeColor", "StrokeWidth", "Stroke", "FillPaint",
    "FontFaceId", "FontSize", "TextAlign" }
for _, name in ipairs(names) do
    _G["nvg" .. name] = function(_, ...)
        draws = draws + 1
        for _, v in ipairs({...}) do
            if type(v) == "number" then assert(v == v and math.abs(v) < 1e9) end
        end
    end
end
nvgRGBA = function(...) return {...} end
nvgImagePattern = function(...) return {} end
nvgText = function(_, x, y, value) rendered[value] = true end
assert(loadfile("scripts/main.lua"))()
local function upvalue(fn, wanted)
    for i = 1, 80 do
        local name, value = debug.getupvalue(fn, i)
        if name == wanted then return value end
        if not name then break end
    end
    error("Missing upvalue " .. wanted)
end
local function near(a, b) assert(math.abs(a - b) < 0.001) end
local function click(r)
    local sx, sy = ToScreen(r.x + r.w / 2, r.y + r.h / 2)
    HandleMouseDown(nil, { GetInt = function(_, key)
        if key == "Button" then return MOUSEB_LEFT end
        return key == "X" and sx or sy
    end })
end
local views = {{375,812}, {390,844}, {430,932}, {450,800}, {1280,800}}
for _, viewport in ipairs(views) do
    ResetGame("home")
    RebuildLayout(viewport[1], viewport[2])
    local layout = upvalue(ToScreen, "layout")
    local game = upvalue(HandleMouseDown, "game")
    local x, y = ToScreen(layout.homeHomeButton.x, 0)
    near(x, 0); near(y, 0)
    local r = layout.homeMapButton
    x, y = ToScreen(r.x + r.w, r.y + r.h)
    near(x, viewport[1]); near(y, viewport[2])
    assert(layout.homeStartButton.y + layout.homeStartButton.h < r.y)
    local pages = {
        {layout.homeGuardButton, "guards", "守卫图鉴"},
        {layout.homeMechaButton, "mecha", "领主机甲"},
        {layout.homeMapButton, "map", "星图航线"},
        {layout.homeHomeButton, "home", "开始防守"},
    }
    for _, page in ipairs(pages) do
        click(page[1]); assert(game.homeTab == page[2])
        rendered = {}; DrawHome({}); assert(rendered[page[3]])
        if page[2] ~= "home" then
            click(layout.homeStartButton); assert(game.state == "home")
        end
        HandleUpdate(nil, {GetFloat = function() return 0.016 end})
        assert(game.wave == 0 and #game.monsters == 0)
    end
    click(layout.homeStartButton)
    game = upvalue(HandleMouseDown, "game")
    assert(game.state == "playing" and game.wallHp == 60)
    game.state = "defeat"
    click(layout.resultHomeButton)
    game = upvalue(HandleMouseDown, "game")
    assert(game.state == "home" and game.homeTab == "home")
    print("PASS viewport " .. viewport[1] .. "x" .. viewport[2])
end
assert(draws > 0)
print("PASS tab routing, hit regions, home idle, start battle, return home")
