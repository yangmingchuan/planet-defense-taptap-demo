local FX = {}
FX.limit = 96

function FX.New() return { items = {}, clock = 0 } end

function FX.Emit(state, kind, x, y, radius, color, tx, ty)
    if #state.items >= FX.limit then return end
    local duration = kind == "beam" and 0.35 or (kind == "burst" and 0.42 or 0.22)
    state.items[#state.items+1] = {kind=kind,x=x,y=y,tx=tx,ty=ty,r=radius,c=color,life=duration,duration=duration}
end

function FX.Update(state, dt)
    state.clock = state.clock + dt
    for i=#state.items,1,-1 do
        local effect=state.items[i]
        effect.life=effect.life-dt
        if effect.life<=0 then table.remove(state.items,i) end
    end
end

local function line(ctx,x,y,tx,ty,width,c,alpha)
    nvgBeginPath(ctx); nvgMoveTo(ctx,x,y); nvgLineTo(ctx,tx,ty)
    nvgStrokeColor(ctx,nvgRGBA(c[1],c[2],c[3],math.floor(alpha)))
    nvgStrokeWidth(ctx,width); nvgStroke(ctx)
end

function FX.Draw(ctx,state,toScreen,scale)
    for _,e in ipairs(state.items) do
        local x,y=toScreen(e.x,e.y)
        local fade=e.life/e.duration
        local progress=1-fade
        if e.kind=="beam" then
            local tx,ty=toScreen(e.tx,e.ty)
            line(ctx,x,y,tx,ty,e.r*scale*2.6,e.c,65*fade)
            line(ctx,x,y,tx,ty,e.r*scale,e.c,230*fade)
            line(ctx,x,y,tx,ty,math.max(1,e.r*0.3)*scale,{255,255,230},255*fade)
        else
            local r=e.r*scale
            if e.kind=="burst" then
                nvgBeginPath(ctx); nvgCircle(ctx,x,y,r*(0.2+progress*0.8))
                nvgStrokeColor(ctx,nvgRGBA(e.c[1],e.c[2],e.c[3],math.floor(210*fade)))
                nvgStrokeWidth(ctx,(2+4*fade)*scale); nvgStroke(ctx)
                nvgBeginPath(ctx); nvgCircle(ctx,x,y,r*0.30*fade)
                nvgFillColor(ctx,nvgRGBA(255,240,180,math.floor(180*fade))); nvgFill(ctx)
            end
            for i=1,(e.kind=="burst" and 8 or 4) do
                local a=i*2.399+e.x*0.01
                local inner=r*(0.1+progress*0.5)
                local outer=inner+r*0.38*fade
                line(ctx,x+math.cos(a)*inner,y+math.sin(a)*inner,
                    x+math.cos(a)*outer,y+math.sin(a)*outer,(e.kind=="burst" and 3 or 2)*scale,e.c,245*fade)
            end
        end
    end
end

return FX
