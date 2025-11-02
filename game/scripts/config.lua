--
-- Copyright (c) Uladzislau Nikalayevich <thenormalnij@gmail.com>. All rights reserved.
-- Licensed under the MIT license. See LICENSE file in the project root for details.
--

---@class CoopModConfig
local Config = {
    -- Choose loot delivery type here
    -- Possible values: "Shared", "RoomDuplicated"
    --
    -- Shared - rooms generate one reward. Only one player can pick it up.
    -- The game has a query that select a player context for a reward.
    -- E.g. Player 1 boon room, meta progress room, Player 2 boon room, Player 1 boon room...
    --
    -- RoomDuplicated - rooms generate two reward for each player.
    LootDelivery = "RoomDuplicated",

    -- This config is used for the "RoomDuplicated" loot delivery option
    RoomDuplicatedDelivery = {
        -- Enables duplication of the Chaos boons.
        DuplicateChaosBoon = false;
    },
    Player1HasOutline = true;
    Player1Outline = {
        R = 0,
        G = 0,
        B = 200,
        Opacity = 0.6,
        Thickness = 2,
        Threshold = 0.6,
    };
    Player2HasOutline = true,
    Player2Outline = {
        R = 0,
        G = 200,
        B = 0,
        Opacity = 0.6,
        Thickness = 2,
        Threshold = 0.6,
    };
    TextAbovePlayersEnabled = false;
    TextAbovePlayersParams = {
        -- CreateTextBox params
        OffsetX = 0,
        OffsetY = -150,
        FontSize = 28,
        Color = { 255, 255, 255, 255 },
        ShadowColor = { 0, 0, 0, 240 },
        ShadowOffset = { 0, 2 },
        ShadowBlur = 0,
        OutlineThickness = 3,
        OutlineColor = { 0, 0, 0, 1 },
        Font = "AlegreyaSansSCRegular",
        Justification = "Center"
    },
    Debug = {
        OneHit = false,
        P1GodMode = false,
        P2GodMode = false,
    },

    -- Revive System Configuration
    ReviveSystem = {
        -- Enable/disable the revive system
        Enabled = true,

        -- Time in seconds required to revive a downed player
        ReviveTime = 3.0,

        -- Percentage of max health restored when revived (0.5 = 50%)
        ReviveHealthPercent = 0.5,

        -- Duration in seconds of invulnerability after being revived
        InvulnerabilityDuration = 3.0,

        -- Cooldown in seconds before a player can revive again
        ReviveCooldownPerPlayer = 30.0,

        -- Maximum number of revives per room (nil = unlimited)
        MaxRevivesPerRoom = nil,

        -- Whether to interrupt revival when reviver takes damage
        InterruptOnDamage = true,

        -- Whether to interrupt revival when players are too far apart
        InterruptOnDistance = true,

        -- Maximum distance (in game units) before revival is interrupted
        MaxInterruptDistance = 300,
    }
}

return Config
