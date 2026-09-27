assert(loadfile("tests/squad-combat.lua"))()
local function up(fn,wanted)
    for i=1,100 do local n,v=debug.getupvalue(fn,i); if n==wanted then return v end; if not n then break end end
    error(wanted)
end
local function state() return up(HandleMouseDown,"game") end
local tuning=require("BattleTuning")
StartBattle(); local g=state()
assert(g.silver==500)
StartNextWave(); assert(g.spawnRemaining==28)
for i=1,800 do UpdateWave(0.05) end
assert(#g.monsters==28 and g.spawnRemaining==0)
for _,m in ipairs(g.monsters) do assert(m.hp<30 and m.damage==tuning.swarmDamage and m.silver==4) end
g.wave=10; g.spawnRemaining=1000
for i=1,1000 do UpdateWave(0.05) end
assert(#g.monsters==tuning.maxMonsters)
local waiting=g.spawnRemaining
UpdateWave(0.05); assert(g.spawnRemaining==waiting)
table.remove(g.monsters); g.spawnTimer=0
UpdateWave(0.05); assert(#g.monsters==80 and g.spawnRemaining==waiting-1)
print("PASS denser waves, weak swarm, silver budget, 80-monster backpressure without discarded spawns")

local slots=up(FindSlotAt,"slotDefs")
for _,kind in ipairs({"archer","mage","bombardier"}) do
    StartBattle(); g=state()
    local d=CreateDefender(kind,3,4); g.defenders[4]=d
    local target={x=slots[4].x,y=slots[4].y-100,hp=10000,maxHp=10000,defense=12,id="basic",slowTime=0,slowRatio=0,freezeTime=0}
    g.monsters={target}; d.actionTarget=target
    ReleaseDefenderAction(4,d)
    assert(#g.projectiles==3 and target.hp==10000)
    for i=1,40 do UpdateProjectiles(0.05) end
    assert(#g.projectiles==0)
    if kind=="archer" then
        -- Level III legacy pierce damage is separate; direct three-arrow damage stays 42-12.
        assert(target.hp<=9970 and target.hp>9920)
    elseif kind=="bombardier" then assert(math.abs(target.hp-9944)<0.001) end
end
local fx=require("CombatFX")
for _,area in ipairs({AreaDamage,AreaSlow}) do
    StartBattle(); g=state()
    local target={x=400,y=700,hp=100,defense=12,slowTime=0,slowRatio=0}
    g.monsters={target}
    for i=1,3 do area(400,700,80,10,nil,1/3) end
    assert(math.abs(target.hp-76)<0.001,"area damage must share armor across a volley")
end
local s=fx.New()
for i=1,1000 do fx.Emit(s,"burst",0,0,50,{255,100,80}) end
assert(#s.items==96); fx.Update(s,1); assert(#s.items==0)
print("PASS 3-shot bursts, delayed hit timing, armor split, effect budget and cleanup")

-- First-wave playability smoke test: spend initial silver across eight level-I ranged guards.
for seed=1,5 do
    math.randomseed(seed)
    StartBattle(); g=state()
    for i=1,8 do g.defenders[i]=CreateDefender(i%2==0 and "archer" or "mage",1,i) end
    g.silver=116
    local peak=0
    for i=1,1800 do
        HandleUpdate(nil,{GetFloat=function() return 0.05 end})
        peak=math.max(peak,#g.monsters)
        if g.wave>=2 or g.state=="defeat" then break end
    end
    assert(g.wave>=2 and g.wallHp>=30,"first-wave seed="..seed..", wave="..g.wave..", wall="..g.wallHp)
    print("PASS first-wave combat smoke: seed="..seed..", wave="..g.wave..", wall="..g.wallHp..", peakMonsters="..peak)
end
