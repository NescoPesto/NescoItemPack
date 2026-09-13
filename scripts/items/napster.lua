---@diagnostic disable: param-type-mismatch
local napster = Isaac.GetItemIdByName("Napster")
local napsterUnlockAchievement = Isaac.GetAchievementIdByName("Napster")
local SHOULD_BLOCK_POPUP = false

if EID then
    Nesco:AddCallback(ModCallbacks.MC_POST_GAME_STARTED, function()
        EID:addCollectible(napster, "#If Isaac goes to the next floor without taking damage in the boss room, one of the following will spawn on next floor:#{{GoldenBomb}} -> 15%#{{Coin}} (Golden) -> 20%#{{GoldenHeart}} -> 15%#{{GoldenKey}} -> 20%#{{Battery}} (Mega) -> 15%#{{Pill}} (Golden) -> 15%#Otherwise there's a 50% chance the pickup will spawn", "Napster", "en")
    end)
end

function Nesco:UnlockNapster()
    local persistGameData = Isaac.GetPersistentGameData()
    if persistGameData:Unlocked(napsterUnlockAchievement) then return end

    local unlockRequirement = persistGameData:Unlocked(Achievement.GOLDEN_PENNY)
        and persistGameData:Unlocked(Achievement.GOLDEN_HEARTS)
        and persistGameData:Unlocked(Achievement.GOLDEN_BOMBS)
        and persistGameData:Unlocked(Achievement.GOLDEN_PILLS)

    if unlockRequirement then
        persistGameData:TryUnlock(napsterUnlockAchievement, SHOULD_BLOCK_POPUP)
    end
end

Nesco:AddCallback(ModCallbacks.MC_POST_GAME_STARTED, Nesco.UnlockNapster)

local willSpawn = true
local damageCalcCalled = false
local entityVariant = nil
local entitySubType = nil

-- function to calculate which pickup will be dropped
-- Odds:
-- Golden Bomb -> 15%
-- Golden Key -> 20%
-- Golden Pill -> 15%
-- Mega Battery -> 15%
-- Golden Heart -> 15%
-- Golden Coin -> 20%
function Nesco:CalculateOdds()
    local player = Isaac.GetPlayer(0)
    local rng = player:GetCollectibleRNG(napster)
    local odds = rng:RandomFloat()

    local goldenBomb = odds >= 0 and odds <= 0.14
    local goldenKey = odds >= 0.15 and odds <= 0.34
    local goldenPill = odds >= 0.35 and odds <= 0.49
    local megaBattery = odds >= 0.50 and odds <= 0.64
    local goldenHeart = odds >= 0.65 and odds <= 0.79
    local goldenCoin = odds >= 0.80 and odds <= 0.99

    if goldenBomb then
        entityVariant = PickupVariant.PICKUP_BOMB
        entitySubType = BombSubType.BOMB_GOLDEN
    elseif goldenKey then
        entityVariant = PickupVariant.PICKUP_KEY
        entitySubType = KeySubType.KEY_GOLDEN
    elseif goldenPill then
        entityVariant = PickupVariant.PICKUP_PILL
        entitySubType = PillColor.PILL_GOLD
    elseif megaBattery then
        entityVariant = PickupVariant.PICKUP_LIL_BATTERY
        entitySubType = BatterySubType.BATTERY_MEGA
    elseif goldenHeart then
        entityVariant = PickupVariant.PICKUP_HEART
        entitySubType = HeartSubType.HEART_GOLDEN
    elseif goldenCoin then
        entityVariant = PickupVariant.PICKUP_COIN
        entitySubType = CoinSubType.COIN_GOLDEN
    end
end

function Nesco:SpawnPickup()
    local player = Isaac.GetPlayer(0)
    local spawnPosition = player.Position + Vector(20,20)

    if player:GetCollectibleNum(napster) <= 0 then return
    elseif willSpawn and player:GetCollectibleNum(napster) > 0 then
            Nesco:CalculateOdds()
            SFXManager():Play(SoundEffect.SOUND_THUMBSUP)
            player:PlayExtraAnimation("Happy")
            Isaac.Spawn(EntityType.ENTITY_PICKUP, entityVariant, entitySubType, spawnPosition, Vector(0,0), nil)
        else
        SFXManager():Play(SoundEffect.SOUND_THUMBS_DOWN)
        player:PlayExtraAnimation("Sad")
    end

    --reset values after spawning
    willSpawn = true
    damageCalcCalled = false
    entityVariant = nil
    entitySubType = nil
end

function Nesco:CalculateChanceReduction()
    local player = Isaac.GetPlayer(0)
    if player:GetCollectibleNum(napster) <= 0 then return end --jumps out if doesn't have the item

    local roomType =  Game():GetRoom():GetType()
    if roomType ~= RoomType.ROOM_BOSS then return end --jumps out so that it only applies to damage taken in the boss room

    local rng = player:GetCollectibleRNG(napster)

    if not damageCalcCalled then
        damageCalcCalled = true
        local chance = rng:RandomFloat()

        if chance < 0.5 then
            willSpawn = false
        end

    end
end

function Nesco:PlaySoundEffect()
    local roomType =  Game():GetRoom():GetType()
    if roomType ~= RoomType.ROOM_BOSS then return end

    local player = Game():GetPlayer(0)
    local soundEffect = Isaac.GetSoundIdByName("DialUp")
    local boss

    for _, entity in ipairs(Isaac.GetRoomEntities()) do
        if entity.IsBoss then
            boss = entity
        end
    end

    if player:GetCollectibleNum(napster) > 0 and boss.IsVisible then
           SFXManager():Play(soundEffect, 1)
    end
end

-- Getting hit triggers CalculateChanceReduction()
Nesco:AddCallback(ModCallbacks.MC_ENTITY_TAKE_DMG, Nesco.CalculateChanceReduction, EntityType.ENTITY_PLAYER)


--going to the next floor calls SpawnPickup
local triggeredNewLevel = false
Nesco:AddCallback(ModCallbacks.MC_POST_NEW_LEVEL, function() triggeredNewLevel = true end)

function TrySpawnPickup()
    if not triggeredNewLevel then return end

    triggeredNewLevel = false
    Nesco:SpawnPickup()
end

Nesco:AddCallback(ModCallbacks.MC_POST_UPDATE, TrySpawnPickup)

--going to the boss room triggers sound effect
local triggeredBossRoomEnter = false
Nesco:AddCallback(ModCallbacks.MC_POST_NEW_ROOM, function () triggeredBossRoomEnter = true end)

function TryPlaySoundEffect()
    if not triggeredBossRoomEnter then return end

    triggeredBossRoomEnter = false
    Nesco:PlaySoundEffect()
end

Nesco:AddCallback(ModCallbacks.MC_POST_UPDATE, TryPlaySoundEffect)