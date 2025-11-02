--
-- Copyright (c) Uladzislau Nikalayevich <thenormalnij@gmail.com>. All rights reserved.
-- Licensed under the MIT license. See LICENSE file in the project root for details.
--

---@class ReviveSystem
local ReviveSystem = {}

DebugPrint({ Text = "[REVIVE] Loading ReviveSystem module..." })

-- Load configuration
local Config = ModRequire "config.lua"
ReviveSystem.Config = Config.ReviveSystem or {
    Enabled = true,
    ReviveTime = 3.0,
    ReviveHealthPercent = 0.5,
    InvulnerabilityDuration = 3.0,
    ReviveCooldownPerPlayer = 30.0,
    MaxRevivesPerRoom = nil,
    InterruptOnDamage = true,
    InterruptOnDistance = true,
    MaxInterruptDistance = 300,
}

-- State tracking
ReviveSystem.DownedPlayers = {}
ReviveSystem.ActiveRevivals = {}
ReviveSystem.LastReviveTimes = {}
ReviveSystem.RevivesThisRoom = {}
ReviveSystem.NearbyDownedPlayers = {}
ReviveSystem.RevivalButtonPressed = {}

-- Helper function
local function LogRevive(message)
    DebugPrint({ Text = "[REVIVE] " .. message })
end

---@return boolean
function ReviveSystem.IsEnabled()
    return ReviveSystem.Config and ReviveSystem.Config.Enabled
end

function ReviveSystem.OnPlayerDeath(playerId, hero)
    LogRevive("OnPlayerDeath called for player " .. tostring(playerId))

    if not ReviveSystem.IsEnabled() then
        return
    end

    -- Store downed player information
    ReviveSystem.DownedPlayers[playerId] = {
        hero = hero,
        heroObjectId = hero.ObjectId,
        downedTime = _worldTime or 0
    }

    LogRevive("Player " .. playerId .. " marked as downed")
end

function ReviveSystem.EnterDownedState(playerId, hero)
    LogRevive("EnterDownedState for player " .. playerId)

    if not hero then
        LogRevive("ERROR: Hero is nil!")
        return
    end

    -- Make player invulnerable while downed
    if hero.ObjectId then
        SetPlayerInvulnerable("DownedPlayer")
        LogRevive("Set invulnerable for player " .. playerId)
    end

    -- Make player untargetable by enemies
    hero.Untargetable = true
    LogRevive("Set untargetable for player " .. playerId)

    -- Disable movement by setting speed to 0
    if hero.ObjectId then
        SetUnitProperty({ Id = hero.ObjectId, Property = "Speed", Value = 0 })
        SetUnitProperty({ Id = hero.ObjectId, Property = "ControlFrozen", Value = true })
        LogRevive("Disabled movement for player " .. playerId)
    end

    -- Block all inputs for the downed player
    AddInputBlock({ PlayerIndex = playerId, Name = "DownedPlayer" })
    LogRevive("Blocked inputs for player " .. playerId)

    -- Visual indicator - darken the player
    if hero.ObjectId then
        SetColor({ Id = hero.ObjectId, Color = { 100, 100, 100, 180 } })
        LogRevive("Set downed visual for player " .. playerId)
    end
end

function ReviveSystem.ShouldEnterDownedState(targetPlayerId, hero)
    LogRevive("ShouldEnterDownedState check for P" .. targetPlayerId)

    if not ReviveSystem.IsEnabled() then
        LogRevive("System DISABLED")
        return false
    end

    -- Check if hero has death defiances (last stands) remaining
    if hero.LastStands and TableLength(hero.LastStands) > 0 then
        LogRevive("Has " .. TableLength(hero.LastStands) .. " LastStands - normal death defiance")
        return false
    end

    -- Check if there's another player alive (besides the dying one)
    -- NOTE: This is called BEFORE setting IsDead, so the dying player is still "alive"
    local CoopPlayers = ModRequire "CoopPlayers.lua"
    local aliveHeroes = CoopPlayers.GetAliveHeroes()

    local otherAliveCount = 0
    for _, aliveHero in ipairs(aliveHeroes) do
        local alivePlayerId = CoopPlayers.GetPlayerByHero(aliveHero)
        if alivePlayerId and alivePlayerId ~= targetPlayerId then
            otherAliveCount = otherAliveCount + 1
        end
    end

    LogRevive("Alive count: " .. #aliveHeroes .. ", others: " .. otherAliveCount)

    if otherAliveCount == 0 then
        LogRevive("No other alive players - normal death")
        return false
    end

    -- Check if already being revived
    for reviverPlayerId, revivalData in pairs(ReviveSystem.ActiveRevivals) do
        if revivalData.targetPlayerId == targetPlayerId then
            LogRevive("Already being revived")
            return false
        end
    end

    LogRevive("Should enter downed state: TRUE")
    return true
end

function ReviveSystem.OnDamageInterrupt(playerId)
    -- TODO: Implement damage interruption
end

function ReviveSystem.OnRoomStart()
    LogRevive("OnRoomStart - resetting state")

    -- Clear invulnerability from downed players
    local CoopPlayers = ModRequire "CoopPlayers.lua"
    for playerId, downedData in pairs(ReviveSystem.DownedPlayers) do
        SetPlayerVulnerable("DownedPlayer")
        RemoveInputBlock({ PlayerIndex = playerId, Name = "DownedPlayer" })
        local hero = CoopPlayers.GetHero(playerId)
        if hero and hero.ObjectId then
            SetUnitProperty({ Id = hero.ObjectId, Property = "Speed", Value = hero.DefaultSpeed or 400 })
            SetUnitProperty({ Id = hero.ObjectId, Property = "ControlFrozen", Value = false })
        end
    end

    -- Cancel all active revivals
    for reviverPlayerId in pairs(ReviveSystem.ActiveRevivals) do
        ReviveSystem.CancelRevive(reviverPlayerId)
    end

    ReviveSystem.DownedPlayers = {}
    ReviveSystem.ActiveRevivals = {}
    ReviveSystem.RevivesThisRoom = {}
    ReviveSystem.NearbyDownedPlayers = {}
    ReviveSystem.RevivalButtonPressed = {}
end

function ReviveSystem.CompleteRevive(reviverPlayerId, targetPlayerId)
    LogRevive("CompleteRevive: P" .. reviverPlayerId .. " reviving P" .. targetPlayerId)

    local CoopPlayers = ModRequire "CoopPlayers.lua"
    local HeroContext = ModRequire "HeroContext.lua"

    local targetHero = CoopPlayers.GetHero(targetPlayerId)
    if not targetHero then
        LogRevive("ERROR: Target hero is nil!")
        return
    end

    local downedData = ReviveSystem.DownedPlayers[targetPlayerId]
    if not downedData then
        LogRevive("ERROR: No downed data!")
        return
    end

    -- Restore player to alive state
    targetHero.IsDead = false
    targetHero.Untargetable = false
    LogRevive("Set IsDead = false, Untargetable = false")

    -- Restore health
    targetHero.Health = math.ceil(targetHero.MaxHealth * ReviveSystem.Config.ReviveHealthPercent)
    LogRevive("Restored health to " .. targetHero.Health)

    -- Remove downed invulnerability
    SetPlayerVulnerable("DownedPlayer")

    -- Remove input block
    RemoveInputBlock({ PlayerIndex = targetPlayerId, Name = "DownedPlayer" })
    LogRevive("Restored inputs")

    -- Restore movement
    if targetHero.ObjectId then
        SetUnitProperty({ Id = targetHero.ObjectId, Property = "Speed", Value = targetHero.DefaultSpeed or 400 })
        SetUnitProperty({ Id = targetHero.ObjectId, Property = "ControlFrozen", Value = false })
        LogRevive("Restored movement")
    end

    -- Restore visual appearance
    if targetHero.ObjectId then
        SetColor({ Id = targetHero.ObjectId, Color = { 255, 255, 255, 255 } })
        LogRevive("Restored normal color")
    end

    -- Play effects
    if targetHero.ObjectId then
        PlaySound({ Name = "/SFX/Player Sounds/PlayerHealingPickup", Id = targetHero.ObjectId })
        LogRevive("Played revival sound")
    end

    -- Cleanup downed state
    ReviveSystem.DownedPlayers[targetPlayerId] = nil

    -- Clear revival button state
    ReviveSystem.RevivalButtonPressed[reviverPlayerId] = false

    LogRevive("Revival complete!")
end

function ReviveSystem.StartRevive(reviverPlayerId, targetPlayerId)
    LogRevive("StartRevive: P" .. reviverPlayerId .. " -> P" .. targetPlayerId)

    -- Check if already reviving
    if ReviveSystem.ActiveRevivals[reviverPlayerId] then
        return
    end

    local CoopPlayers = ModRequire "CoopPlayers.lua"
    local targetHero = CoopPlayers.GetHero(targetPlayerId)

    -- Play sound to indicate revival started
    if targetHero and targetHero.ObjectId then
        PlaySound({ Name = "/SFX/Menu Sounds/EquipmentMetaUpgradeLockedIN", Id = targetHero.ObjectId })
    end

    -- Create visual progress meter
    local meterId = nil
    if ScreenCenterX and ScreenCenterY then
        meterId = CreateScreenObstacle({
            Name = "BlankObstacle",
            Group = "Combat_Menu",
            X = ScreenCenterX,
            Y = ScreenCenterY - 100
        })

        SetAnimation({ Name = "HealthBarFill", DestinationId = meterId, Scale = 2.0 })

        CreateTextBox({
            Id = meterId,
            Text = "Reviving... Hold to continue",
            FontSize = 24,
            OffsetY = -50,
            Color = {1.0, 0.8, 0.0, 1.0},
            Font = "AlegreyaSansSCBold",
            ShadowBlur = 0,
            ShadowColor = {0,0,0,1},
            ShadowOffset={0,3},
            Justification = "Center"
        })
    end

    -- Start revival timer
    ReviveSystem.ActiveRevivals[reviverPlayerId] = {
        targetPlayerId = targetPlayerId,
        startTime = _worldTime or 0,
        meterId = meterId
    }

    -- Create thread to handle revival progress
    thread(function()
        local startTime = _worldTime or 0
        local reviveTime = ReviveSystem.Config.ReviveTime

        while true do
            wait(0.05)

            -- Check if revival was cancelled
            if not ReviveSystem.ActiveRevivals[reviverPlayerId] then
                LogRevive("Revival cancelled for P" .. reviverPlayerId)
                -- Cleanup meter
                if meterId then
                    Destroy({ Id = meterId })
                end
                return
            end

            -- Check progress
            local elapsed = (_worldTime or 0) - startTime
            local progress = elapsed / reviveTime

            -- Update visual meter (progress from 0 to 1, showing fill)
            if meterId then
                SetAnimationFrameTarget({
                    Name = "HealthBarFill",
                    Fraction = progress,
                    DestinationId = meterId
                })
            end

            if progress >= 1.0 then
                -- Revival complete!
                LogRevive("Revival timer complete!")
                ReviveSystem.CompleteRevive(reviverPlayerId, targetPlayerId)
                ReviveSystem.ActiveRevivals[reviverPlayerId] = nil
                -- Cleanup meter
                if meterId then
                    Destroy({ Id = meterId })
                end
                return
            end
        end
    end)

    LogRevive("Revival started - need to hold proximity for " .. ReviveSystem.Config.ReviveTime .. "s")
end

function ReviveSystem.CancelRevive(reviverPlayerId)
    if ReviveSystem.ActiveRevivals[reviverPlayerId] then
        LogRevive("Cancelling revival by P" .. reviverPlayerId)
        ReviveSystem.ActiveRevivals[reviverPlayerId] = nil
    end
end

function ReviveSystem.CheckProximityRevival()
    if not ReviveSystem.IsEnabled() then
        return
    end

    local CoopPlayers = ModRequire "CoopPlayers.lua"
    local aliveHeroes = CoopPlayers.GetAliveHeroes()

    -- Check all active revivals - cancel if out of range
    for reviverPlayerId, revivalData in pairs(ReviveSystem.ActiveRevivals) do
        local reviverHero = CoopPlayers.GetHero(reviverPlayerId)
        local targetHero = CoopPlayers.GetHero(revivalData.targetPlayerId)

        if reviverHero and targetHero and reviverHero.ObjectId and targetHero.ObjectId then
            local distance = GetDistance({
                Id = reviverHero.ObjectId,
                DestinationId = targetHero.ObjectId
            })

            if distance >= 150 then
                LogRevive("P" .. reviverPlayerId .. " moved away - cancelling revival")
                ReviveSystem.CancelRevive(reviverPlayerId)
            end
        else
            -- Hero no longer valid
            ReviveSystem.CancelRevive(reviverPlayerId)
        end
    end

    -- Clear all nearby markers first
    ReviveSystem.NearbyDownedPlayers = {}

    -- Check for players near downed players
    for downedPlayerId, downedData in pairs(ReviveSystem.DownedPlayers) do
        local downedHero = CoopPlayers.GetHero(downedPlayerId)

        if downedHero and downedHero.ObjectId and downedHero.IsDead then
            -- Check each alive player for proximity
            for _, aliveHero in ipairs(aliveHeroes) do
                local alivePlayerId = CoopPlayers.GetPlayerByHero(aliveHero)

                if alivePlayerId and alivePlayerId ~= downedPlayerId and aliveHero.ObjectId then
                    local distance = GetDistance({
                        Id = aliveHero.ObjectId,
                        DestinationId = downedHero.ObjectId
                    })

                    -- Store proximity state for button handler to check
                    if distance < 150 then
                        if not ReviveSystem.ActiveRevivals[alivePlayerId] then
                            ReviveSystem.NearbyDownedPlayers[alivePlayerId] = downedPlayerId
                        end
                    end
                end
            end
        else
            -- Player no longer downed, clean up
            ReviveSystem.DownedPlayers[downedPlayerId] = nil
        end
    end
end

function ReviveSystem.OnRevivalButtonPressed(playerId)
    LogRevive("Revival button pressed by P" .. playerId)

    -- Check if player is near a downed player
    if ReviveSystem.NearbyDownedPlayers and ReviveSystem.NearbyDownedPlayers[playerId] then
        local targetPlayerId = ReviveSystem.NearbyDownedPlayers[playerId]

        -- Start revival if not already reviving
        if not ReviveSystem.ActiveRevivals[playerId] then
            LogRevive("Starting revival: P" .. playerId .. " -> P" .. targetPlayerId)
            ReviveSystem.StartRevive(playerId, targetPlayerId)
        end
    else
        LogRevive("No nearby downed players for P" .. playerId)
    end
end

function ReviveSystem.InitHooks()
    LogRevive("InitHooks called - system enabled: " .. tostring(ReviveSystem.IsEnabled()))

    if not ReviveSystem.IsEnabled() then
        return
    end

    -- For now, use simple auto-trigger on proximity
    -- TODO: Add proper button detection later
    LogRevive("Using auto-trigger revival (proximity-based)")

    -- Start proximity checker thread
    thread(function()
        wait(2.0) -- Wait for game to initialize
        LogRevive("Proximity checker started")

        while true do
            wait(0.2) -- Check every 0.2 seconds
            ReviveSystem.CheckProximityRevival()

            -- Auto-start revival when nearby
            for playerId, targetPlayerId in pairs(ReviveSystem.NearbyDownedPlayers or {}) do
                if not ReviveSystem.ActiveRevivals[playerId] then
                    LogRevive("Auto-starting revival: P" .. playerId .. " -> P" .. targetPlayerId)
                    ReviveSystem.StartRevive(playerId, targetPlayerId)
                end
            end
        end
    end)
end

DebugPrint({ Text = "[REVIVE] ReviveSystem module loaded successfully" })

return ReviveSystem
