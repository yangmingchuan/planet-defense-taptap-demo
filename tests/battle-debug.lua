assert(loadfile("tests/home-navigation.lua"))()
local Debug=require("BattleDebug")
local now,clockReads=0,0
GetTime=function() return {GetSystemTime=function() clockReads=clockReads+1; return now end} end
Debug.Init()
local count=clockReads
assert(Debug.BeginUpdate()==nil and Debug.BeginRender()==nil and clockReads==count)
local function up(fn,key)
    for i=1,100 do local n,v=debug.getupvalue(fn,i); if n==key then return v end; if not n then break end end
    error(key)
end
StartBattle(); RebuildLayout(390,844)
local g=up(HandleMouseDown,"game")
local layout=up(ToScreen,"layout")
local button=layout.debugBounds
local silver=g.silver
local function click()
    HandleMouseDown(nil,{GetInt=function(_,key)
        if key=="Button" then return MOUSEB_LEFT end
        return key=="X" and button.x+button.w/2 or button.y+button.h/2
    end})
end
click(); assert(Debug.enabled and g.silver==silver and #g.defenders==0)
local graphics={GetWidth=function() return 390 end,GetHeight=function() return 844 end,
    GetNumBatches=function() return 72 end,GetNumPrimitives=function() return 2048 end}
local images={one={meta={w=512,h=512}}}
local audio={sources={}}
local frames=0
local function frame(interval)
    now=now+interval
    local update=Debug.BeginUpdate(); now=now+2; Debug.EndUpdate(update)
    local render=Debug.BeginRender(); now=now+3
    Debug.EndRender(render,g,graphics,images,audio,60)
    frames=frames+1
end
for i=1,8 do frame(11) end
frame(195) -- 200ms frame interval must not be truncated by the simulation's 50ms clamp.
for i=1,20 do frame(11) end
local text=table.concat(Debug.rows,"\n")
assert(text:find("最慢帧 200 ms",1,true) and text:find(">50ms 1次",1,true))
assert(text:find("逻辑 2.0 ms",1,true) and text:find("绘制提交 3.0 ms",1,true))
assert(text:find("RGBA估算 1.0 MiB",1,true) and text:find("引擎批次 72",1,true))
assert(text:find("CPU/GPU占用 N/A",1,true))
Debug.Reset(); now=now+10000
frame(11); assert(Debug.stutters==0)
for i=1,40 do
    now=now+16; local start=Debug.BeginRender(); Debug.EndRender(start,g,{},images,audio,60)
end
assert(table.concat(Debug.rows):find("引擎批次 N/A",1,true))
click(); assert(not Debug.enabled and g.silver==silver)
for _,size in ipairs({{320,568},{390,844},{450,800},{1280,800}}) do
    RebuildLayout(size[1],size[2]); local l=up(ToScreen,"layout"); local b=l.debugBounds
    assert(b.x>=0 and b.x+b.w<=size[1] and b.y+b.h<=size[2])
    assert(b.panelX>=l.dx-0.01 and b.panelX+b.panelW<=l.dx+l.drawW+0.01)
end
GetTime=nil
Debug.Init(); Debug.clock=function() return now end; Debug.Toggle()
for i=1,40 do
    now=now+16; local start=Debug.BeginRender(); Debug.EndRender(start,g,{},images,audio,60)
end
assert(table.concat(Debug.rows):find("FPS N/A",1,true),"CPU time is not a valid wall-clock FPS")
print("PASS debug toggle consumes input, disabled sampling idle, unclamped stalls, callback timing, missing counters, focus reset, viewport bounds")
