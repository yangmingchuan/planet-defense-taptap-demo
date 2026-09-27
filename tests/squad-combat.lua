assert(loadfile("tests/home-navigation.lua"))()
local Roster = require("Roster")
local function up(fn, wanted)
    for i=1,100 do local name,value=debug.getupvalue(fn,i); if name==wanted then return value end; if not name then break end end
    error("Missing "..wanted)
end
local function state() return up(HandleMouseDown,"game") end
local function setTeam(team)
    ResetGame("home")
    local old=Roster.Copy(state().squad)
    for _,id in ipairs(old) do ToggleSquad(id) end
    for _,id in ipairs(team) do ToggleSquad(id) end
end
local function monster(x,y,hp,defense,id)
    local m={x=x,y=y,hp=hp or 1000,maxHp=hp or 1000,defense=defense or 0,id=id or "basic",silver=12,
        slowTime=0,slowRatio=0,freezeTime=0,speed=0,animState="walk",animTime=0}
    table.insert(state().monsters,m)
    return m
end
local function ticks(n)
    for i=1,n do UpdateProjectiles(0.05); UpdateExtraStatuses(0.05) end
end
local function shoot(kind,level,target,ultimate)
    local d=CreateDefender(kind,level,4)
    state().defenders[4]=d
    d.actionTarget=target
    ReleaseExtraAttack(d,ultimate)
    return d
end
local function near(a,b) assert(math.abs(a-b)<0.001,tostring(a).." ~= "..tostring(b)) end

setTeam({})
StartBattle(); assert(state().state=="home")
ToggleSquad("unknown"); assert(#state().squad==0)
for _,id in ipairs({"bombardier","stormcaller","rail_sniper","mage"}) do ToggleSquad(id) end
assert(#state().squad==3 and not Roster.Contains(state().squad,"mage"))
StartBattle(); assert(state().state=="playing")
ToggleSquad("mage"); assert(not Roster.Contains(state().squad,"mage"))
for i=1,1000 do assert(Roster.Contains(state().squad,RandomDefenderKind())) end
ResetGame("home"); assert(state().squad[1]=="bombardier" and #state().squad==3)
for i=1,100 do
    for _,e in ipairs(BuildEventChoices()) do assert(not e.id:match("^frost") and not e.id:match("^healer") and not e.id:match("^arrow")) end
end
state().silver=10000
StartBattle(); state().silver=10000
for i=1,10 do SummonDefender() end
local silver,cost=state().silver,state().summonCost
SummonDefender(); assert(state().silver==silver and state().summonCost==cost)
print("PASS empty/full/invalid roster, run snapshot, return home, summon pool, full board, event filtering")

for _,kind in ipairs(Roster.order) do
    if Roster.extra[kind] then
        for level=1,3 do
            setTeam({kind}); StartBattle()
            local target=monster(420,1080)
            shoot(kind,level,target,false)
            assert(target.hp==1000)
            ticks(30)
            assert(target.hp<1000,kind.." no normal damage")
            DrawDefender({},state().defenders[4],420,1282)
            setTeam({kind}); StartBattle()
            target=monster(420,1080)
            local d=shoot(kind,3,target,true)
            ticks(85)
            assert(target.hp<1000,kind.." no ultimate damage")
            assert(#state().projectiles==0,kind.." leaked projectile")
        end
    end
end
print("PASS six roles, levels I/II/III, impact-only normal damage, ultimate damage and projectile cleanup")

setTeam({"bombardier"}); StartBattle()
local target=monster(420,1080)
shoot("bombardier",1,target,false)
ticks(10); near(target.hp,984)
setTeam({"bombardier"}); StartBattle()
target=monster(420,1080)
shoot("bombardier",1,target,false)
target.x=800; ticks(10); near(target.hp,1000)
setTeam({"stormcaller"}); StartBattle()
local a,b=monster(420,1080),monster(450,1080)
shoot("stormcaller",3,a,false); ticks(30)
near(a.hp,966); near(b.hp,977.9)
setTeam({"rail_sniper"}); StartBattle()
a,b=monster(420,1080,1000,0),monster(420,1000,1000,12)
local d=shoot("rail_sniper",1,a,false)
assert(FindTarget(d)==b)
setTeam({"blade_dancer"}); StartBattle()
a=monster(420,1080)
shoot("blade_dancer",1,a,false); ticks(30); near(a.hp,985)
print("PASS single explosion hit, fixed-point miss, chain uniqueness, armored priority, blade outbound/return")

setTeam({"alchemist"}); StartBattle()
a=monster(420,1080)
d=shoot("alchemist",1,a,false)
ticks(10); near(a.hp,996)
ticks(60); near(a.hp,990)
assert(a.acid==nil)
a.corrosion,a.corrosionLeft=5,0.1
ticks(3); assert(a.corrosionLeft==0)
setTeam({"gravity_engineer"}); StartBattle()
a,b=monster(420,1080),monster(450,1100,1000,0,"boss")
local wall=monster(470,1185)
shoot("gravity_engineer",3,a,true); ticks(30)
near(b.x,450); near(b.y,1100); near(wall.x,470); near(wall.y,1185)
print("PASS acid ticks and expiry, corrosion expiry, boss/wall displacement immunity")

setTeam({"bombardier"}); StartBattle()
a=monster(420,1080,10)
d=shoot("bombardier",3,a,false)
shoot("bombardier",3,a,false)
local before=state().silver
ticks(20); assert(state().silver==before+12 and state().kills==1)
setTeam({"bombardier"}); StartBattle()
a=monster(420,1080,10)
d=shoot("bombardier",3,a,false)
state().defenders[4]=CreateDefender("bombardier",3,4)
ticks(20); assert(state().defenders[4].rage==0 and state().kills==1)
print("PASS exactly-once death rewards, removed owner cannot transfer rage")

for id in pairs(Roster.extra) do
    setTeam({id}); StartBattle()
    local d=CreateDefender(id,3,4); state().defenders[4]=d; d.rage=100
    CastReadyUltimate(); assert(d.rage==100 and #state().projectiles==0)
    monster(420,1080)
    CastReadyUltimate(); assert(d.rage==0 and #state().projectiles==1)
    ticks(85)
end
setTeam({"alchemist"}); StartBattle()
monster(420,1080)
for slot=4,6 do
    local d=CreateDefender("alchemist",3,slot); state().defenders[slot]=d; d.rage=100
end
CastReadyUltimate(); CastReadyUltimate(); CastReadyUltimate()
assert(#state().projectiles==2)
local stillReady=GetReadyUltimate(); assert(stillReady and stillReady.rage==100)
print("PASS manual ultimates, no-target rage retention, acid zone reservation budget")

setTeam({"bombardier","stormcaller","rail_sniper"}); StartBattle(); RebuildLayout(390,844)
local function inputAt(x,y)
    local sx,sy=ToScreen(x,y)
    return {GetInt=function(_,key) if key=="Button" then return MOUSEB_LEFT end; return key=="X" and sx or sy end}
end
local slots=up(FindSlotAt,"slotDefs")
local function merge(first,second)
    HandleMouseDown(nil,inputAt(slots[first].x,slots[first].y))
    HandleMouseUp(nil,inputAt(slots[second].x,slots[second].y))
end
state().defenders[1]=CreateDefender("bombardier",1,1)
state().defenders[2]=CreateDefender("bombardier",1,2)
merge(1,2)
assert(state().defenders[1]==nil and state().defenders[2].level==2 and state().defenders[2].kind=="bombardier")
state().defenders[1]=CreateDefender("stormcaller",2,1)
merge(1,2)
assert(state().defenders[2].level==3 and Roster.Contains(state().squad,state().defenders[2].kind))
state().eventChoices=nil
state().defenders[1]=CreateDefender("bombardier",3,1)
merge(1,2); assert(state().defenders[1] and state().defenders[2].level==3)
print("PASS same-role merge, mixed-role merge stays inside squad, level III cap")

for offset=1,9 do
    local team={Roster.order[offset],Roster.order[offset%9+1],Roster.order[(offset+1)%9+1]}
    setTeam(team); StartBattle(); RebuildLayout(390,844)
    state().silver=100000
    for slot=1,#slots do state().defenders[slot]=CreateDefender(team[(slot-1)%3+1],3,slot) end
    for frame=1,600 do
        HandleUpdate(nil,{GetFloat=function() return 0.05 end})
        if GetReadyUltimate() then CastReadyUltimate() end
        DrawDefenders({}); DrawProjectiles({})
        assert(state().silver>=0)
    end
end
print("PASS nine mixed squads, real action/update/render loops, 270 simulated seconds without runtime errors")

setTeam({"archer","mage","healer"})
print("PASS squad-combat suite")
