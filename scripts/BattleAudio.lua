local Audio = { muted = false, sources = {}, sounds = {}, gates = {}, attempted = {}, clock = 0, enabled = false }
local paths = {
    shot = "audio/sfx/pulse-shot-v1.mp3",
    hit = "audio/sfx/shell-impact-v1.mp3",
    frost = "audio/sfx/frost-hit-v1.mp3",
    ultimate = "audio/sfx/ultimate-charge-v1.mp3",
    music = "audio/music/battle-loop-v1.mp3",
}

function Audio.Init()
    if Audio.enabled or not Scene or not cache then return end
    -- Hold the scene strongly for the lifetime of its pooled SoundSources.
    Audio.scene = Scene()
    for i=1,6 do Audio.sources[i]=Audio.scene:CreateChild("BattleSfx"..i):CreateComponent("SoundSource") end
    Audio.music=Audio.scene:CreateChild("BattleMusic"):CreateComponent("SoundSource")
    Audio.enabled=true
end

function Audio.Prepare(name)
    if not Audio.enabled or Audio.attempted[name] or not paths[name] then return end
    Audio.attempted[name] = true
    Audio.sounds[name] = cache:GetResource("Sound",paths[name])
    if not Audio.sounds[name] then print("WARN: missing battle sound: "..paths[name]); return end
    if name=="music" then Audio.sounds[name]:SetLooped(true) end
end

function Audio.Update(dt,playing)
    Audio.clock=Audio.clock+dt
    if not Audio.enabled then return end
    if playing and Audio.unlocked and not Audio.muted and Audio.sounds.music then
        if not Audio.music:IsPlaying() then Audio.music:Play(Audio.sounds.music,0,0.12) end
    elseif Audio.music:IsPlaying() then Audio.music:Stop() end
end

function Audio.Unlock() Audio.unlocked=true end

function Audio.Play(name)
    if not Audio.enabled or Audio.muted or not Audio.unlocked or not Audio.sounds[name] then return end
    if Audio.clock<(Audio.gates[name] or 0) then return end
    Audio.gates[name]=Audio.clock+(name=="shot" and 0.12 or 0.09)
    for _,source in ipairs(Audio.sources) do
        if not source:IsPlaying() then
            source:Play(Audio.sounds[name],0,name=="ultimate" and 0.3 or 0.18)
            return
        end
    end
    if name=="ultimate" then Audio.sources[1]:Play(Audio.sounds[name],0,0.3) end
end

function Audio.Toggle()
    Audio.muted=not Audio.muted
    if Audio.muted then Audio.Stop() end
end

function Audio.Stop()
    if Audio.music then Audio.music:Stop() end
    for _,source in ipairs(Audio.sources) do source:Stop() end
end

function Audio.Shutdown()
    Audio.Stop()
    Audio.sources,Audio.sounds,Audio.scene,Audio.music,Audio.enabled={},{},nil,nil,false
    Audio.attempted,Audio.gates,Audio.unlocked={}, {}, false
end

return Audio
