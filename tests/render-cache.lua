assert(loadfile("tests/home-navigation.lua"))()

local size={w=390,h=844}
local graphics={GetWidth=function() return size.w end,GetHeight=function() return size.h end,
    GetRGBAFormat=function() return 1 end,SetMode=function() end}
GetGraphics=function() return graphics end
GetEngine=function() return {SetMaxFps=function() end,SetMaxInactiveFps=function() end,
    SetPauseMinimized=function() end} end
SampleStart=function() end
SampleInitMouseMode=function() end

local subscriptions,draws,targets={},0,{}
SubscribeToEvent=function(...) subscriptions[#subscriptions+1]={...} end
UnsubscribeFromAllEvents=function() subscriptions={} end
nvgCreate=function() return {} end
nvgDelete=function() end
nvgCreateFont=function() return 1 end
nvgCreateImage=function(_,path) return path end
nvgDeleteImage=function() end
nvgImageSize=function() return 256,256 end
nvgBeginFrame=function() draws=draws+1 end
nvgEndFrame=function() end
nvgSetRenderTarget=function(_,target) targets[#targets+1]=target end
TEXTURE_RENDERTARGET,FILTER_BILINEAR=2,1
Texture2D={}
function Texture2D:new() return setmetatable({}, {__index=self}) end
function Texture2D:SetNumLevels() end
function Texture2D:SetSize(w,h) self.w,self.h=w,h; return true end
function Texture2D:SetFilterMode() end
BorderImage={}
function BorderImage:new() return setmetatable({}, {__index=self}) end
function BorderImage:SetTexture(target) self.texture=target end
function BorderImage:SetPosition() end
function BorderImage:SetSize(w,h) self.w,self.h=w,h end
function BorderImage:Remove() self.removed=true end
ui={root={AddChild=function(_,panel) ui.panel=panel end}}

Start()
assert(#targets==1 and ui.panel.texture==targets[1])
assert(subscriptions[1][1]=="EndAllViewsRender")
for i=1,120 do
    HandleUpdate(nil,{GetFloat=function() return 1/120 end})
    HandleRender()
end
assert(draws>=29 and draws<=31,"120Hz callbacks should redraw near 30Hz, got "..draws)
local game
for i=1,100 do
    local name,value=debug.getupvalue(HandleMouseDown,i)
    if name=="game" then game=value; break end
end
assert(game and math.abs(game.time-1)<0.04,"simulation time must not slow down")
size.w,size.h=430,932
HandleRender()
assert(targets[1].w==430 and targets[1].h==932)
assert(ui.panel.w==430 and ui.panel.h==932)
local panel=ui.panel
Stop()
assert(panel.removed)

ui=nil
draws=0
Start()
assert(subscriptions[1][1]~="EndAllViewsRender")
for i=1,4 do HandleRender() end
assert(draws==4,"unsupported render targets must retain direct drawing")
Stop()
ui={root={AddChild=function(_,panel) ui.panel=panel end}}
nvgSetRenderTarget=function() error("render target unavailable") end
draws=0
Start()
assert(ui.panel.removed,"failed target binding must remove the temporary UI panel")
assert(subscriptions[1][1]~="EndAllViewsRender")
HandleRender()
assert(draws==1,"failed target binding must retain direct drawing")
Stop()
print("PASS render target retains frames, caps real draws near 30Hz, preserves simulation time, resizes and falls back")
