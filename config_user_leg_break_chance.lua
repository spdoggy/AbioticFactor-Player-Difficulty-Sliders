return {
    -- Define Per-User % to break legs on debuff
    -- Format: ["steam_display_name"] = #
    -- Normal Range of Values are 0 to 100
    --
    -- Examples:
    -- 100 = User will ALWAYS break their legs when the server tries to apply the debuff
    --  50 = User will have their debuff removed 50% of the time
    --   0 = User will never suffer broken legs
    ["YourDisplayNameHere"] = 50.0,
    ["2ndPlayerDisplayNameHere"] = 50.0,
}
