-- Structural workload checks, not a browser FPS benchmark.
assert(loadfile("tests/home-navigation.lua"))()
local function up(fn,key)
    for i=1,100 do local n,v=debug.getupvalue(fn,i); if n==key then return v end; if not n then break end end
    error(key)
end
local function game() return up(HandleMouseDown,"game") end
local textures,deleted,sounds,subscriptions={}, {}, {}, {}
local engine={}
function engine:SetMaxFps(n) self.fps=n end
function engine:SetMaxInactiveFps(n) self.inactive=n end
function engine:SetPauseMinimized(n) self.pause=n end
GetEngine=function() return engine end
GetGraphics=function() return {SetMode=function() end,GetWidth=function() return 390 end,GetHeight=function() return 844 end} end
SampleStart=function() end
SampleInitMouseMode=function() end
nvgCreate=function() return {} end
nvgCreateFont=function() return 1 end
nvgCreateImage=function(_,path) textures[#textures+1]=path; return path end
nvgImageSize=function() return 256,256 end
nvgDeleteImage=function(_,path) assert(not deleted[path],"double delete: "..path); deleted[path]=true end
nvgDelete=function() end
SubscribeToEvent=function(...) subscriptions[#subscriptions+1]={...} end
UnsubscribeFromAllEvents=function() subscriptions={} end
require("urhox-libs/UI").Shutdown=function() end
Scene=function() return {CreateChild=function() return {CreateComponent=function()
    return {IsPlaying=function(self) return self.playing end, Play=function(self) self.playing=true end,Stop=function(self) self.playing=false end}
end} end} end
cache={GetResource=function(_,kind,path) assert(kind=="Sound"); sounds[#sounds+1]=path; return {SetLooped=function() end} end}
Start()
assert(engine.fps==30 and engine.inactive==10 and engine.pause)
assert(#textures==47 and #sounds==0)
for _,p in ipairs(textures) do assert(not p:find("/monsters/") and not p:find("/attack/") and not p:find("battle-background")) end
print("PASS startup: 47 image loads, 0 sound loads; no combat frames on home")

local rebuilds,safeCalls=0,0
local originalRebuild=RebuildLayout
RebuildLayout=function(...) rebuilds=rebuilds+1; return originalRebuild(...) end
GetSafeAreaInsets=function() safeCalls=safeCalls+1; return nil end
sdk=nil
EnsureLayout(390,844)
for i=1,600 do HandleUpdate(nil,{GetFloat=function() return 1/60 end}); EnsureLayout(390,844) end
assert(rebuilds<=1 and safeCalls<=21)
local before=rebuilds
EnsureLayout(430,932); assert(rebuilds==before+1)
GetSafeAreaInsets=function() return {min={x=0,y=48},max={x=0,y=20}} end
HandleUpdate(nil,{GetFloat=function() return 0.6 end}); EnsureLayout(430,932)
assert(up(ToScreen,"layout").safeTop==56)
print("PASS layout cache: 600 frames, "..safeCalls.." safe-area polls; resize and changed insets invalidate")

StartBattle(); assert(game().loadingBattle)
local wave=game().wave
local updates=0
while game().loadingBattle do
    local before=#textures+#sounds
    HandleUpdate(nil,{GetFloat=function() return 1/60 end})
    assert(#textures+#sounds-before<=2)
    assert(game().wave==wave,"combat must wait for textures")
    updates=updates+1; assert(updates<100)
end
HandleUpdate(nil,{GetFloat=function() return 1/60 end})
assert(engine.fps==30 and #sounds==5)
local portraitCount=0
for _,path in ipairs(textures) do
    if path:find("/tank/portrait") then portraitCount=portraitCount+1 end
    assert(not path:find("frost%-mage/attack") and not path:find("/attack/level%-2"))
end
assert(portraitCount==1)
print("PASS staged battle loading: "..updates.." updates, at most 2 uploads/loads per update; unused attacks skipped, boss texture shared")

local t=game().time
HandleInputFocus(nil,{GetBool=function() return false end})
for i=1,100 do HandleUpdate(nil,{GetFloat=function() return 1 end}) end
assert(game().time==t and engine.fps==10)
HandleInputFocus(nil,{GetBool=function(_,key) return key=="Focus" end})
HandleUpdate(nil,{GetFloat=function() return 1/60 end})
assert(game().time>t and game().time<t+0.1 and engine.fps==30)
local textureCount,soundCount=#textures,#sounds
ResetGame("home"); StartBattle()
assert(not game().loadingBattle and #textures==textureCount and #sounds==soundCount)
print("PASS inactive simulation pause, foreground resume, cached replay without reload")

local fx=require("CombatFX")
local state=fx.New()
fx.Emit(state,"burst",100,100,60,{255,100,50})
local strokes=0
local oldStroke=nvgStroke
nvgStroke=function() strokes=strokes+1 end
fx.Draw({},state,function(x,y) return x,y end,1)
assert(strokes==2,"one ring plus one batched spark path")
nvgStroke=oldStroke
Stop(); assert(#subscriptions==0)
local count=0; for _ in pairs(deleted) do count=count+1 end
assert(count==#textures)
print("PASS burst strokes 9 -> 2; textures deleted once; callbacks removed on Stop")
