-- Deterministic layout proof from the real NanoVG calls, not an engine screenshot.
package.path = "scripts/?.lua;" .. package.path
package.preload["LuaScripts/Utilities/Sample"] = function() return {} end
package.preload["urhox-libs/UI"] = function() return {} end
NVG_ALIGN_LEFT, NVG_ALIGN_CENTER, NVG_ALIGN_RIGHT, NVG_ALIGN_MIDDLE = 1, 2, 4, 16
local width, height = tonumber(arg[2]) or 390, tonumber(arg[3]) or 844
local page = arg[1] or "home"
local output, path, fill, stroke, strokeWidth, fontSize, align, paint = {}, "", "#000", "#000", 1, 16, 1, nil
local function escape(value)
    return tostring(value):gsub("&", "&amp;"):gsub('"', "&quot;"):gsub("<", "&lt;"):gsub(">", "&gt;")
end
local function add(value) output[#output + 1] = value end
function nvgRGBA(r, g, b, a) return string.format("rgba(%s,%s,%s,%.4f)", r, g, b, (a or 255) / 255) end
function nvgBeginPath() path = ""; paint = nil end
function nvgRect(_, x, y, w, h) path = string.format("M %f %f h %f v %f h %f Z", x, y, w, h, -w) end
function nvgRoundedRect(_, x, y, w, h, r)
    path = string.format("M %f %f h %f q %f 0 %f %f v %f q 0 %f %f %f h %f q %f 0 %f %f v %f q 0 %f %f %f Z",
        x+r,y,w-2*r,r,r,r,h-2*r,r,-r,r,-w+2*r,-r,-r,-r,-h+2*r,-r,r,-r)
end
function nvgCircle(_, x, y, r)
    path = string.format("M %f %f a %f %f 0 1 0 %f 0 a %f %f 0 1 0 %f 0", x-r,y,r,r,2*r,r,r,-2*r)
end
function nvgMoveTo(_, x, y) path = path .. string.format(" M %f %f", x, y) end
function nvgLineTo(_, x, y) path = path .. string.format(" L %f %f", x, y) end
function nvgFillColor(_, value) fill = value; paint = nil end
function nvgStrokeColor(_, value) stroke = value end
function nvgStrokeWidth(_, value) strokeWidth = value end
function nvgFillPaint(_, value) paint = value end
function nvgFill()
    if paint then
        add(string.format('<image x="%f" y="%f" width="%f" height="%f" href="%s" preserveAspectRatio="none"/>', paint.x,paint.y,paint.w,paint.h,escape(paint.img)))
    else
        add('<path d="' .. path .. '" fill="' .. fill .. '"/>')
    end
end
function nvgStroke() add('<path d="' .. path .. '" fill="none" stroke="' .. stroke .. '" stroke-width="' .. strokeWidth .. '"/>') end
function nvgImagePattern(_, x, y, w, h, rotation, img) return {x=x,y=y,w=w,h=h,img=img} end
function nvgCreateImage(_, filename) return filename end
function nvgImageSize(_, filename)
    if filename:find("home-background") then return 941, 1672 end
    if filename:find("commander") then return 1263, 1246 end
    return 256, 256
end
function nvgFontFaceId() end
function nvgFontSize(_, value) fontSize = value end
function nvgTextAlign(_, value) align = value end
function nvgText(_, x, y, text)
    local anchor = align % 16 == 2 and "middle" or (align % 16 == 4 and "end" or "start")
    add(string.format('<text x="%f" y="%f" text-anchor="%s" dominant-baseline="central" font-family="PingFang SC,Arial" font-size="%f" fill="%s">%s</text>',x,y,anchor,fontSize,fill,escape(text)))
end
assert(loadfile("scripts/main.lua"))()
ResetGame("home")
if arg[4] then
    for _, id in ipairs({"archer","mage","healer","bombardier","stormcaller","rail_sniper"}) do ToggleSquad(id) end
end
for i = 1, 80 do
    local name, value = debug.getupvalue(DrawHome, i)
    if name == "game" then value.homeTab = page; value.homeGuard = tonumber(arg[4]) or 1; break end
end
LoadImages()
RebuildLayout(width, height)
if page=="battle" then
    ResetGame("playing"); RebuildLayout(width,height)
    QueueBattleResources()
    for _=1,100 do ProcessBattleResources() end
    local g
    for i=1,80 do local n,v=debug.getupvalue(DrawHome,i); if n=="game" then g=v; break end end
    math.randomseed(27)
    g.wave=7; g.spawnRemaining=0; g.waveTimer=100
    for i=1,65 do
        SpawnMonsterForWave()
        local m=g.monsters[#g.monsters]
        m.x=155+((i-1)%9)*76; m.y=390+math.floor((i-1)/9)*94
        m.hp,m.maxHp=180,180
    end
    local kinds={"bombardier","rail_sniper","mage"}
    for i=1,10 do
        g.defenders[i]=CreateDefender(kinds[(i-1)%3+1],3,i)
        g.defenders[i].cooldown=(i%4)*0.14
    end
    for i=1,tonumber(arg[4]) or 25 do HandleUpdate(nil,{GetFloat=function() return 0.05 end}) end
    if arg[5]=="debug" then
        local debug=require("BattleDebug")
        debug.Toggle()
        debug.rows={"FPS 32.8  上限 60","帧间隔 30.5 ms  P95 54.0","最慢帧 126 ms  >50ms 8次",
            "逻辑 3.2 ms","绘制提交 12.4 ms","怪物 65  守卫 10  弹道 120",
            "特效 88  飘字 24  音效 6","Lua内存 8.20 MiB","纹理 125  RGBA估算 35.6 MiB",
            "引擎批次 180  图元 16020","画布 "..width.." x "..height,"CPU/GPU占用 N/A  |  wall ms"}
    end
    DrawScene({},width,height)
else
    DrawBackground({}, width, height)
    DrawHome({})
end
print(string.format('<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" viewBox="0 0 %d %d">',width,height,width,height))
print(table.concat(output, "\n"))
print('</svg>')
