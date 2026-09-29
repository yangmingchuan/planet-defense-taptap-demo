local Debug = { enabled=false, rows={}, clock=nil, clockLabel="N/A" }
local RED = {255,95,95,255}

local function read(object,method)
    if not object then return nil end
    local ok,value=pcall(function() return object[method](object) end)
    if ok and type(value)=="number" and value==value then return value end
end

local function number(value,format)
    return value and string.format(format or "%.0f",value) or "N/A"
end

function Debug.Init()
    Debug.enabled=false
    Debug.clock=nil
    Debug.cpuClock=type(os.clock)=="function" and function() return os.clock()*1000 end or nil
    Debug.hasWallClock=false
    if GetTime then
        local time=GetTime()
        if read(time,"GetSystemTime") then
            Debug.clock=function() return time:GetSystemTime() end
            Debug.clockLabel="wall ms"
            Debug.hasWallClock=true
        end
    end
    if not Debug.clock then
        Debug.clock=Debug.cpuClock or function() return 0 end
        Debug.clockLabel=Debug.cpuClock and "CPU clock ms" or "N/A"
    end
    Debug.Reset()
end

function Debug.Reset()
    Debug.rows={"采样中…"}
    Debug.lastRender=nil
    Debug.updateElapsed,Debug.pendingFrameMs,Debug.clockUnreliable=0,0,false
    Debug.updateIntervals,Debug.updateWorst,Debug.updateStutters={},0,0
    Debug.updateSum,Debug.updates,Debug.renderSum,Debug.renders=0,0,0,0
    Debug.cpuUpdateSum,Debug.cpuRenderSum,Debug.cpuUpdates,Debug.cpuRenders=0,0,0,0
    Debug.simulations=0
end

function Debug.Toggle()
    if not Debug.clock then Debug.Init() end
    Debug.enabled=not Debug.enabled
    Debug.Reset()
end

function Debug.BeginUpdate(rawDt)
    if Debug.enabled then
        if type(rawDt)=="number" and rawDt>=0 and rawDt<10 then
            local ms=rawDt*1000
            Debug.updateElapsed=Debug.updateElapsed+ms
            Debug.pendingFrameMs=Debug.pendingFrameMs+ms
            if #Debug.updateIntervals<256 then Debug.updateIntervals[#Debug.updateIntervals+1]=ms end
            Debug.updateWorst=math.max(Debug.updateWorst,ms)
            if ms>50 then Debug.updateStutters=Debug.updateStutters+1 end
        end
        Debug.cpuUpdateStart=Debug.cpuClock and Debug.cpuClock() or nil
        return Debug.clock()
    end
end

function Debug.EndUpdate(start)
    if not start then return end
    Debug.updateSum=Debug.updateSum+math.max(0,Debug.clock()-start)
    Debug.updates=Debug.updates+1
    local cpuDelta=Debug.cpuUpdateStart and Debug.cpuClock()-Debug.cpuUpdateStart or 0
    if cpuDelta>0 then
        Debug.cpuUpdateSum=Debug.cpuUpdateSum+cpuDelta
        Debug.cpuUpdates=Debug.cpuUpdates+1
    end
end

function Debug.MarkSimulation()
    if Debug.enabled then Debug.simulations=Debug.simulations+1 end
end

function Debug.BeginRender()
    if not Debug.enabled then return end
    local now=Debug.clock()
    if Debug.lastRender then
        local measured=now-Debug.lastRender
        if Debug.pendingFrameMs>0 and (measured<=0 or measured<Debug.pendingFrameMs*0.25) then
            Debug.clockUnreliable=true
        end
    end
    Debug.lastRender=now
    Debug.pendingFrameMs=0
    Debug.cpuRenderStart=Debug.cpuClock and Debug.cpuClock() or nil
    return now
end

function Debug.EndRender(start,game,graphics,imagePaths,audio,fpsCap,cached)
    if not start then return end
    Debug.renderSum=Debug.renderSum+math.max(0,Debug.clock()-start)
    Debug.renders=Debug.renders+1
    local cpuDelta=Debug.cpuRenderStart and Debug.cpuClock()-Debug.cpuRenderStart or 0
    if cpuDelta>0 then
        Debug.cpuRenderSum=Debug.cpuRenderSum+cpuDelta
        Debug.cpuRenders=Debug.cpuRenders+1
    end
    if Debug.updateElapsed<500 or Debug.renders==0 then return end
    table.sort(Debug.updateIntervals)
    local guards,textures,bytes,voices=0,0,0,0
    for _ in pairs(game.defenders) do guards=guards+1 end
    for _,entry in pairs(imagePaths) do
        textures=textures+1
        bytes=bytes+entry.meta.w*entry.meta.h*4
    end
    for _,source in ipairs(audio.sources) do
        local ok,playing=pcall(function() return source:IsPlaying() end)
        if ok and playing then voices=voices+1 end
    end
    local ok,memory=pcall(collectgarbage,"count")
    local p95=Debug.updateIntervals[math.max(1,math.ceil(#Debug.updateIntervals*0.95))]
    local fx=#game.combatFx.items+#game.particles+#game.iceBlasts
    local logic=not Debug.clockUnreliable and Debug.updates>0 and Debug.updateSum/Debug.updates
        or (Debug.cpuUpdates>0 and Debug.cpuUpdateSum/Debug.cpuUpdates or nil)
    local paint=not Debug.clockUnreliable and Debug.renderSum/Debug.renders
        or (Debug.cpuRenders>0 and Debug.cpuRenderSum/Debug.cpuRenders or nil)
    local source=Debug.clockUnreliable and "CPU钟" or ""
    Debug.rows={
        "更新 "..number(Debug.updates*1000/Debug.updateElapsed,"%.0f").."/s  模拟 "..number(Debug.simulations*1000/Debug.updateElapsed,"%.0f").."/s",
        "实际重绘 "..number(Debug.renders*1000/Debug.updateElapsed,"%.0f").."/s  目标 "..number(fpsCap),
        "帧缓存 "..(cached and "ON" or "OFF"),
        "更新P95 "..number(p95,"%.1f").."ms",
        "最慢更新 "..number(Debug.updateWorst,"%.0f").."ms  >50ms "..Debug.updateStutters.."次",
        "逻辑"..source.." "..number(logic,"%.1f").." ms",
        "绘制"..source.." "..number(paint,"%.1f").." ms",
        "怪物 "..#game.monsters.."  守卫 "..guards.."  弹道 "..#game.projectiles,
        "特效 "..fx.."  飘字 "..#game.floats.."  音效 "..voices,
        "Lua内存 "..number(ok and memory/1024 or nil,"%.2f").." MiB",
        "纹理 "..textures.."  RGBA估算 "..number(bytes/1048576,"%.1f").." MiB",
        "引擎批次 "..number(read(graphics,"GetNumBatches")).."  图元 "..number(read(graphics,"GetNumPrimitives")),
        "画布 "..number(read(graphics,"GetWidth")).." x "..number(read(graphics,"GetHeight")),
        "实际FPS/CPU/GPU N/A",
    }
    Debug.updateElapsed,Debug.clockUnreliable=0,false
    Debug.updateIntervals={}
    Debug.updateSum,Debug.updates,Debug.renderSum,Debug.renders=0,0,0,0
    Debug.cpuUpdateSum,Debug.cpuRenderSum,Debug.cpuUpdates,Debug.cpuRenders=0,0,0,0
    Debug.simulations=0
end

function Debug.Bounds(width,height,safe)
    local right=width-(safe.right or 0)-8
    local y=(safe.top or 0)+8
    local available=math.max(1,width-(safe.left or 0)-(safe.right or 0)-16)
    local panelWidth=math.min(252,available)
    return {x=right-math.min(82,available),y=y,w=math.min(82,available),h=36,
        panelX=right-panelWidth,panelY=y+40,panelW=panelWidth,
        lineHeight=17,fontSize=11,height=height}
end

function Debug.Hit(bounds,x,y)
    return bounds and x>=bounds.x and x<=bounds.x+bounds.w and y>=bounds.y and y<=bounds.y+bounds.h
end

function Debug.Draw(ctx,font,bounds)
    if not bounds then return end
    if font and font~=-1 then nvgFontFaceId(ctx,font) end
    nvgBeginPath(ctx); nvgRoundedRect(ctx,bounds.x,bounds.y,bounds.w,bounds.h,4)
    nvgFillColor(ctx,nvgRGBA(12,16,22,220)); nvgFill(ctx)
    nvgFontSize(ctx,12); nvgTextAlign(ctx,NVG_ALIGN_CENTER+NVG_ALIGN_MIDDLE)
    nvgFillColor(ctx,nvgRGBA(RED[1],RED[2],RED[3],RED[4]))
    nvgText(ctx,bounds.x+bounds.w/2,bounds.y+bounds.h/2,Debug.enabled and "Debug ON" or "Debug",nil)
    if not Debug.enabled then return end
    local maxRows=math.max(0,math.floor((bounds.height-bounds.panelY-8)/bounds.lineHeight))
    local count=math.min(#Debug.rows,maxRows)
    nvgBeginPath(ctx); nvgRect(ctx,bounds.panelX,bounds.panelY,bounds.panelW,count*bounds.lineHeight+8)
    nvgFillColor(ctx,nvgRGBA(8,12,18,205)); nvgFill(ctx)
    nvgFontSize(ctx,bounds.fontSize); nvgTextAlign(ctx,NVG_ALIGN_LEFT+NVG_ALIGN_MIDDLE)
    nvgFillColor(ctx,nvgRGBA(RED[1],RED[2],RED[3],RED[4]))
    for i=1,count do
        nvgText(ctx,bounds.panelX+6,bounds.panelY+4+(i-0.5)*bounds.lineHeight,Debug.rows[i],nil)
    end
end

return Debug
