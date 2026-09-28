package.path="scripts/?.lua;"..package.path
local sources={}
local loads=0
local function source()
    local s={playing=false,plays=0}
    function s:Play(sound,frequency,gain)
        assert(sound and frequency==0 and gain<=0.3)
        self.playing=true; self.plays=self.plays+1
    end
    function s:IsPlaying() return self.playing end
    function s:Stop() self.playing=false end
    sources[#sources+1]=s
    return s
end
Scene=function() return {CreateChild=function() return {CreateComponent=source} end} end
cache={GetResource=function(_,kind,path)
    loads=loads+1
    assert(kind=="Sound" and not path:match("^assets/"))
    return {SetLooped=function(_,looped) assert(looped) end}
end}
local audio=require("BattleAudio")
audio.Init(); assert(#sources==7 and loads==0)
for _,name in ipairs({"shot","hit","frost","ultimate","music"}) do audio.Prepare(name); audio.Prepare(name) end
assert(loads==5)
audio.Update(0.1,true); assert(not audio.music.playing)
audio.Unlock(); audio.Update(0.1,true); assert(audio.music.playing)
audio.Play("shot"); audio.Play("shot"); assert(sources[1].plays==1 and sources[2].plays==0)
for i=1,20 do audio.Update(0.2,true); audio.Play("shot") end
local count=0; for i=1,6 do count=count+sources[i].plays end
assert(count==6)
audio.Play("ultimate"); assert(sources[1].plays==2)
audio.Toggle(); for _,s in ipairs(sources) do assert(not s.playing) end
audio.Update(0.2,true); audio.Play("hit"); assert(not audio.music.playing)
audio.Toggle(); audio.Update(0.2,true); assert(audio.music.playing)
audio.Update(0.2,false); assert(not audio.music.playing)
audio.Shutdown(); assert(not audio.enabled and audio.scene==nil)
print("PASS lazy audio loading, no duplicate decode, gesture unlock, 6-voice cap, rate limit, mute, scene lifetime, music stop")
