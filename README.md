# AbioticFactor-Player-Difficulty-Sliders

## Mod Description

Provide Individual Difficulty Sliders for Players in Abiotic Factor
Damage taken, max hp, max stamina, damage resist, etc
Similar to the functionality of the Sandbox.ini, but on a per-player level.

This mod is intended to be installed by the Host Player or on a Dedicated Server install running UE4SS.
Note that I have not tested cross-play functionality, but I hope it will work for all players.

## Requirements

- UE4SS: https://www.nexusmods.com/abioticfactor/mods/35

## Features

Features implemented so far:

### Damage Resist (DR)

Damage Resist Slider in config_user_dmg_resist.lua for config by server admin.
Gives the ability to mitigate or increase damage applied to each player.


Applies a percentage based heal or percentage based boost after incoming damage is applied by the Server.
To set a default DR for each user, add the user's display name to the config_user_dmg_resist.lua file, with a DR value.

    -- Define Per-User % Damage Resist Difficulty Slider
    -- Format: ["steam_display_name"] = #
    -- Normal Range of Values are -100 to 100
    --
    -- Examples:
    -- 100 = User will heal all incoming damage
    --  50 = User will heal 50% of all incoming damage
    --   0 = No Additional Damage Resist (Server Defaults)
    -- -10 = User will take 10% additional incoming damage
    -- -50 = User will take 50% additional incoming damage

Text Chat Commands to allow players to adjust their settings in-game to their liking.

SetMyDamageResist integer_value
i.e "SetMyDamageResist 50" to give your char an additional 20% Damage Resist

Or the shorthand command "smdr"

"smdr 20"


#### Damage Resist Limitations

Because of the way the Abiotic_PlayerCharacter_C:ProcessDamage function is hooked, damage will have already been applied to the player by the server.
The current version of this mod simply either adds back lost Heath to random limbs, (or in the case of -negative DR removes additional health from the player).
Effectively this means the player can still be one-shot on higher difficulties when the incoming damage is very high.
This is more likely when the EnemyPlayerDamageMultiplier was increased in the SandboxSettings.ini file for the world.

Currently the mod checks for the Display Name, this will inevitably cause conflict problems if players have the same name. 
It may be possible to get the player's unique SteamID, game-tag, or play-id with UE4SS and use that instead.


## Future Improvement Ideas

Find a way to hook earlier to adjust incoming damage before it is applied to the player

1. Find a way to config users by a unique userid (SteamID, game-tag, play-id, etc) instead of by displayname

2. Sliders for:
- Max Health
- Health Regen
- Stamina Usage
- Stamina Regen
- Move Speed
- XP-Gain Rate / Per-Skill-Gain Rates
- Bone-Breakage On/Off
- Apply Challenge Debufs


