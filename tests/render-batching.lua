assert(loadfile("tests/home-navigation.lua"))()

local function up(fn,key)
    for i=1,100 do
        local name,value=debug.getupvalue(fn,i)
        if name==key then return value end
        if not name then break end
    end
    error(key)
end

ResetGame("playing")
RebuildLayout(390,844)
local game=up(DrawMonsters,"game")
local images=up(DrawMonsters,"images")
local scale=up(ToScreen,"layout").scale
images.monster_animation_atlas=99
images.monster_boss=77
game.monsters={
    {id="basic",x=230,y=400,radius=22,animState="walk",animTime=0,hp=30,maxHp=55,freezeTime=0},
    {id="agile",x=550,y=500,radius=20,animState="attack",animTime=0.64,hp=18,maxHp=38,freezeTime=0},
    {id="boss",x=470,y=600,radius=45,animState="walk",animTime=0,hp=480,maxHp=480,freezeTime=0},
}
local paints,fills={},0
local originalPattern,originalFill=nvgImagePattern,nvgFill
nvgImagePattern=function(_,x,y,w,h,angle,img,alpha)
    paints[#paints+1]={x=x,y=y,w=w,h=h,img=img}
    return {}
end
nvgFill=function(...) fills=fills+1; return originalFill(...) end
DrawMonsters({})
assert(paints[1].img==99 and paints[2].img==99 and paints[3].img==77)
assert(math.abs(paints[1].w/(22*2.3*scale)-8)<0.001)
assert(math.abs(paints[1].h/(22*2.3*scale)-6)<0.001)
local agileX,agileY=ToScreen(550,500)
local agileSize=20*2.3*scale
assert(math.abs(paints[2].x-(agileX-7.5*agileSize))<0.001)
assert(math.abs(paints[2].y-(agileY-2.75*agileSize))<0.001)
assert(fills==5,"three sprites and two batched health-bar fills expected")
nvgImagePattern,nvgFill=originalPattern,originalFill

game.acidZones={}
game.projectiles={}
for i=1,3 do game.projectiles[#game.projectiles+1]={kind="arrow",x=100+i*25,y=500,prevX=80+i*25,prevY=520} end
for i=1,2 do game.projectiles[#game.projectiles+1]={kind="frost",x=300+i*25,y=500,prevX=300+i*25,prevY=520} end
local strokes=0
local originalStroke=nvgStroke
nvgStroke=function(...) strokes=strokes+1; return originalStroke(...) end
nvgFill=function(...) fills=fills+1; return originalFill(...) end
fills=0
DrawProjectiles({})
assert(strokes==3 and fills==2,"same-kind projectiles should share trails and heads")
nvgStroke,nvgFill=originalStroke,originalFill
print("PASS monster atlas coordinates, batched health bars and same-kind projectile draw calls")
