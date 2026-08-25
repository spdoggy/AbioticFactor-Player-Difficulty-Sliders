local LogUtil = require("LogUtil")
local ConfigUtil = require("ConfigUtil")
local ConfigAdmin = require("../config_admin")


-- ============================================================
-- CONFIG
-- ============================================================

local UserConfig = require("../config")
local UserConfigDmgResist = require("../config_user_dmg_resist")
local UserConfigArmorSoftcap = require("../config_user_armor_softcap")
local UserConfigArmorDiminish = require("../config_user_armor_diminish_return_factor")
local Config = ConfigUtil.ValidateConfig(UserConfig, LogUtil.CreateLogger("PDS (Config)", UserConfig))
local Log = LogUtil.CreateLogger("PlayerDiffSliders", Config)
Log("=== [PlayerDiffSliders (PDS)] MOD LOADING ===\n")

-- ============================================================
-- CONSTANTS
-- ============================================================


-- ============================================================
-- STATE
-- ============================================================
local GameStateHookFired = false
local GameStateHookNotified = false

-- ============================================================
-- FUNCTIONS
-- ============================================================
---AAbiotic_PlayerCharacter_C function, that sums Current Limb Health
---@param Player_AAbioticCharacter AAbioticCharacter
local function GetCurrentHealth(Player_AAbioticCharacter) 
    return Player_AAbioticCharacter.CurrentHealth_Head + Player_AAbioticCharacter.CurrentHealth_Torso
        + Player_AAbioticCharacter.CurrentHealth_LeftArm + Player_AAbioticCharacter.CurrentHealth_RightArm
        + Player_AAbioticCharacter.CurrentHealth_LeftLeg + Player_AAbioticCharacter.CurrentHealth_RightLeg
end

-- Server Side Supported
local function HandleClient_ProcessDamage(Context, Damage, DamageType, HitLocation, HitNormal, HitComponent, BoneHitName, DirectionOfSource, Instigator, DamageCauser, HitInfo)
    if not Context then return end
    local Character = Context:get()  -- AAbioticCharacter
    
    -- Check Incoming Damage
    local dmg = Damage:get()
    Log.Debug(string.format("Damage: %.2f", dmg))
    local outSuccess = { Success = false }

    -- Get Player Name
    local steam_display_name = Character.MyPlayerState:GetPlayerName():ToString()
    Log.Debug(string.format("Name: %s", steam_display_name))

    -- Record Starting Health
    local start_health = GetCurrentHealth(Character)
    Log.Debug(string.format("Starting Health: %.2f", start_health))
    if start_health <= 0 then
        Log.Debug("Player is at zero health before damage calculation, terminating..")
        return
    end

    -- Use Defaults, and Exit if the User is not in the config list
    if UserConfigDmgResist[steam_display_name] == nil then
        return
    end
    if UserConfigDmgResist[steam_display_name]*1 == 0.0 then
        Log.Debug(string.format("User %s has a DR of 0%%, returning", steam_display_name))
        return
    end
    if UserConfigDmgResist[steam_display_name] == "0" then
        Log.Debug(string.format("User %s has a DR of 0%%, returning", steam_display_name))
        return
    end

    -- Handle Armor Difficulty Sliders
    Log.Debug(string.format("Character.MaxArmorDamageReduction: %.2f %%", Character.MaxArmorDamageReduction)) -- Default is 0.95 %
    -- TODO

    -- UserConfigArmorSoftcap
    if UserConfigArmorSoftcap[steam_display_name] ~= nil then
        Log.Debug(string.format("Character.ArmorSoftCap: %.2f %%", UserConfigArmorSoftcap[steam_display_name]))
        Character.ArmorSoftCap = UserConfigArmorSoftcap[steam_display_name]
    end  
    
    -- UserConfigArmorDiminish
    if UserConfigArmorDiminish[steam_display_name] ~= nil then
        Log.Debug(string.format("Character.DiminishingReturnScalingFactor: %.4f %%", UserConfigArmorDiminish[steam_display_name]))
        Character.DiminishingReturnScalingFactor = UserConfigArmorDiminish[steam_display_name]
    end  

    -- Caluclate DR Percentage
    dmg_resist = UserConfigDmgResist[steam_display_name]/100
    local targeted_change = dmg*dmg_resist
    local targeted_health = start_health + targeted_change
    Log.Debug(string.format("User %s is registered in config_user_dmg_resist", steam_display_name))
    Log.Debug(string.format("User %s damage resist is %.2f %%", steam_display_name, dmg_resist*100))
    Log.Debug(string.format("User %s additional damage/recover is %.2f hp", steam_display_name, targeted_change))
    Log.Debug(string.format("User %s new HP should be %.2f ", steam_display_name, targeted_health))

    -- Still some loss on this implementation, spreading across multiple limbs and multiplying an adjust
    -- TODO: Method is not precise at all, make some better non-random heal/dmg method
    local break_even_adjust = 2.0 -- prev 1.22
    local limb_spread = 10
    local dmg_adjust = (dmg*break_even_adjust*dmg_resist)/limb_spread
    local current_health = GetCurrentHealth(Character)

    for i = 1, limb_spread do
      
            if current_health <= 0 and dmg_adjust < 0 then
                break
            end
            Character:Server_HealRandomLimb(dmg_adjust, outSuccess)
            Character:OnRep_CurrentHealth()
            Character:OnRep_CurrentLeftLegHealth()
            Character:OnRep_CurrentRightLegHealth()
            Character:OnRep_CurrentRightArmHealth()
            Character:OnRep_CurrentLeftArmHealth()
            Character:OnRep_CurrentTorsoHealth()
            Character:OnRep_CurrentHeadHealth()
            current_health = GetCurrentHealth(Character)
            diff_health = math.abs(targeted_health - current_health)
            Log.Debug(i)
            Log.Debug(string.format("Current Health: %.2f", current_health))
            Log.Debug(string.format("Targeted Health: %.2f", targeted_health))
            Log.Debug(string.format("Diff to Target: %.2f", diff_health))
            Log.Debug(string.format("dmg_adjust: %.2f", dmg_adjust))
    end

    Log.Debug("Health Adj Loop Complete")
    
    -- Character.CurrentHealth_Torso = Character.CurrentHealth_Torso + dmg
    local final_health = GetCurrentHealth(Character)

    if final_health <= 0 then
        print("Player is rendered dead after damage calculation, terminating")
        Character.Server_PerformDeathSequence()
    end

    Log.Debug(string.format("Recover: %.2f", dmg_adjust*limb_spread))
    local actual_change = final_health - start_health
    Log.Debug(string.format("Current Health After: %.2f", final_health))
    Log.Debug(string.format("Actual Change: %.2f", actual_change))


end


function split_str(inputstr, sep)
  if sep == nil then
    sep = "%s"
  end
  local t = {}
  for str in string.gmatch(inputstr, "([^"..sep.."]+)") do
    table.insert(t, str)
  end
  return t
end

-- Server Side Supported
local function Handle_Request_SendTextChatMessage(Context, MessageToSend)
    Log.Debug(">>>> Handle_Request_SendTextChatMessage Fired! <<< ")
    if not Context then return end
    local player_controller = Context:get() -- AAbioticPlayerController

    local steam_display_name = player_controller.MyPlayerCharacter.MyPlayerState:GetPlayerName():ToString()
    local message = MessageToSend:get():ToString()
    local msg_fmt = split_str(message, " ")    
    
    local max_key = 0
    for k in pairs(msg_fmt) do
        if k ~= nil then
            max_key = k
        end
    end
    
    white = {R=1, G=1, B=1, A=1}
    red = {R=1, G=0, B=0, A=1}
    blue = {R=0, G=0, B=1, A=1}
    bg = {R=0, G=1, B=1, A=1}
    green = {R=0, G=1, B=0, A=1}

    if msg_fmt[1] == "DR" and max_key == 3 then
        if steam_display_name ~= ConfigAdmin.admin_name then
            -- player_controller:Local_DisplayTextChatMessage("JPark", bg, "Ah ah ah, You didn't say the magic word..", white, player_controller, false)
            -- Exit Silently
            return
        end
        Log.Debug("Change Damage Resist Command Detected")
        username =msg_fmt[2] 
        new_dr = msg_fmt[3] 

        Log.Debug(string.format("[%s] New Damage Resist: %.2f", username, new_dr))
        UserConfigDmgResist[username] = new_dr*1.0
        player_controller:Local_DisplayTextChatMessage("PDS_Mod", red, string.format("[%s] New Damage Resist: %.2f %%", username, new_dr), red, player_controller, false)
    end
    
    if (msg_fmt[1] == "SetMyDamageResist" or msg_fmt[1] == "smdr") and max_key == 2 then
        Log.Debug("Change Damage Resist Command Detected")
        username = steam_display_name
        new_dr = msg_fmt[2]

        Log.Debug(string.format("[%s] New Damage Resist: %.2f", username, new_dr))
        UserConfigDmgResist[username] = new_dr*1.0
        player_controller:Local_DisplayTextChatMessage("PDS_Mod", red, string.format("[%s] New Damage Resist: %.2f %%", username, new_dr), red, player_controller, false)
    end
    
    
    local msg_out = ""
    if  max_key == 1 then
        if (msg_fmt[1] == "HELP" or msg_fmt[1] == "help"  or msg_fmt[1] == "pds_mod_help") then
            local delay = 2000
            ExecuteWithDelay(delay, function()
                player_controller:Local_DisplayTextChatMessage("PDS_Mod", bg, "Supported Admin Commands:", white, player_controller, false)
                player_controller:Local_DisplayTextChatMessage("PDS_Mod", bg, "DR player_displayname dr_number", green, player_controller, false)                
            end)

            delay = delay + 3000
            ExecuteWithDelay(delay, function()
                player_controller:Local_DisplayTextChatMessage("PDS_Mod", bg, "Supported Player Commands:", white, player_controller, false)
                player_controller:Local_DisplayTextChatMessage("PDS_Mod", bg, "SetMyDamageResist dr_number", green, player_controller, false)
                player_controller:Local_DisplayTextChatMessage("PDS_Mod", bg, "smdr dr_number", green, player_controller, false)
                player_controller:Local_DisplayTextChatMessage("PDS_Mod", bg, "listdr", green, player_controller, false)
                player_controller:Local_DisplayTextChatMessage("PDS_Mod", bg, "pds_mod_help", green, player_controller, false)
            end)
        end

        if msg_fmt[1] == "LISTDR" or msg_fmt[1] == "listdr" or msg_fmt[1] == "ListDR" or msg_fmt[1] == "ListDr" then
            player_controller:Local_DisplayTextChatMessage("PDS_Mod", bg, "Server DR Difficulty Sliders:", white, player_controller, false)
            local delay = 0
            for player in pairs(UserConfigDmgResist) do
                delay = delay + 1000
                ExecuteWithDelay(delay, function()
                    dr_setting = UserConfigDmgResist[player]
                    msg_out = string.format("[%s] Damage Resist: %.2f", player, dr_setting)
                    player_controller:Local_DisplayTextChatMessage("PDS_Mod", bg, msg_out, green, player_controller, false)
                end)
            end
        end
    end
    

end


-- ============================================================
-- INITIALIZATION
-- ============================================================

local function SetupOnGameStateHooks()


    -- Solutions
    -- 1. Some kind of configurable slider system on a per-player level for things like
    --      damage taken, max hp, max staminda, damage resist, etc
    -- 
    -- Problems/Questions
    -- What can we implement server-side only? Sounded like not a whole ton of stuff..
    -- Where can we hook
    
    -- Lets start with Abiotic_PlayerCharacter
    -- /Game/Blueprints/Characters/Abiotic_PlayerCharacter.Abiotic_PlayerCharacter_C
    --   void TryApplyFallDamage(double Distance, FHitResult Hit, bool ClientSideCalculationOnly, bool& AppliedFallDamage, int32& Severity);
    --   void GetDamageResistanceOnLimb(EBodyLimbs Limb, const class UDamageType* DamageType, double& DamageBlockedByArmor);
    --   void GetDamageResistanceFromGear(const class UDamageType* DamageType, class AItem_Gear_ParentBP_C* GearBP, double& DamageBlockedByArmor);
    --   void Client_TakeDamage(FVector DamageDirection, bool FatalBlow, FVector DamageLocation, const class UAbiotic_DamageType_ParentBP_C* DamageType);
    --   void ProcessDamage(double Damage, const class UDamageType* DamageType, FVector HitLocation, FVector HitNormal, class UPrimitiveComponent* HitComponent, FName BoneHitName, FVector DirectionOfSource, class AActor* Instigator, class AActor* DamageCauser, FHitResult HitInfo);


    -- 2. A trinket or armor piece with multiple buffs, buff the armor on the unlocker-armbands etc
    --

    ExecuteWithDelay(2500, function()
    local okHook, errHook = pcall(RegisterHook,
        "/Game/Blueprints/Characters/Abiotic_PlayerCharacter.Abiotic_PlayerCharacter_C:ProcessDamage",
        HandleClient_ProcessDamage
    )
        if not okHook then
            Log.Error("Hook registration failed: %s", tostring(errHook))
        else
            Log("Hook registration success: HandleClient_ProcessDamage")
        end
    end)


    --void Request_SendTextChatMessage(FString MessageToSend);
    ExecuteWithDelay(2500, function()
    local okHook, errHook = pcall(RegisterHook,
        "/Game/Blueprints/Meta/Abiotic_PlayerController.Abiotic_PlayerController_C:Request_SendTextChatMessage",
        Handle_Request_SendTextChatMessage
    )
        if not okHook then
            Log.Error("Hook registration failed: %s", tostring(errHook))
        else
            Log("Hook registration success: Handle_Request_SendTextChatMessage")
        end
    end)


    -- These didn't seem to work? Or do I need to test not using the Chopinator?
    -- /Script/Engine.Actor:ReceiveAnyDamage
    -- /Script/Engine.GameplayStatics:ApplyDamage
    -- /Script/Engine.GameplayStatics:ApplyPointDamage
    -- 



end




local function OnGameState(world)
    GameStateHookFired = true

    if not world:IsValid() then return end

    local fullName = world:GetFullName()
    local mapName = fullName and fullName:match("/Game/Maps/([^%.]+)")
    if not mapName then
        return
    end

    if not GameStateHookNotified then
        GameStateHookNotified = true
        
        SetupOnGameStateHooks()
    end

    if mapName:match("MainMenu") then return end
end



-- Hook GameState:ReceiveBeginPlay
local function OnGameStateHook(Context)
    Log.Debug("[PDS] Abiotic_Survival_GameState:ReceiveBeginPlay fired")

    local gameState = Context:get()
    if not gameState:IsValid() then return end

    local world = gameState:GetWorld()
    if world and world:IsValid() then
        OnGameState(world)
    end
end



-- Setup hooks
local function SetupOnAbioticExeStartHooks()
    Log.Debug("[PDS] SetupOnAbioticExeStartHooks\n")
end


local function PollForMissedHook(attempts)
    attempts = attempts or 0

    if GameStateHookFired then return end

    ExecuteInGameThread(function()
        local base = FindFirstOf("GameStateBase")
        if not base:IsValid() then
            if attempts < 100 then
                ExecuteWithDelay(100, function()
                    PollForMissedHook(attempts + 1)
                end)
            else
                Log.Error("GameStateBase never found after %d attempts", attempts + 1)
            end
            return
        end

        if not hookRegistered then
            local ok = pcall(RegisterHook,
                "/Game/Blueprints/Meta/Abiotic_Survival_GameState.Abiotic_Survival_GameState_C:ReceiveBeginPlay",
                OnGameStateHook
            )
            if ok then
                hookRegistered = true
                Log.Debug("Hook registered")
            end
        end

        local gameState = FindFirstOf("Abiotic_Survival_GameState_C")
        if gameState:IsValid() then
            Log.Debug("Gameplay GameState found, invoking OnGameState")
            local world = gameState:GetWorld()
            if world and world:IsValid() then
                OnGameState(world)
            end
        end
    end)
end





-- Define Hooks for On Menu Start, Before Game is Loaded
ExecuteInGameThread(function()
    SetupOnAbioticExeStartHooks()
end)

-- Define Other Hooks
PollForMissedHook()

Log.Debug("PDS Mod loaded")
