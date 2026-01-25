-- Trigger Types
-- Defines the specific points in the game loop where item effects can trigger

return {
    -- Level Triggers
    LEVEL_START = "LEVEL_START",               -- At the start of a level
    LEVEL_WON = "LEVEL_WON",                   -- Goal reached (moment win is detected)
    LEVEL_RESULT_ENTER = "LEVEL_RESULT_ENTER", -- Entering result/reward phase
    SHOP_ENTER = "SHOP_ENTER",                 -- Entering the shop
    SHOP_EXIT = "SHOP_EXIT",                   -- Leaving the shop / Next Level

    -- Hand Triggers
    HAND_START = "HAND_START",                       -- Start of a hand (before any roll)
    HAND_FIRST_ROLL_START = "HAND_FIRST_ROLL_START", -- First roll of a hand
    HAND_LAST_ROLL_START = "HAND_LAST_ROLL_START",   -- Last roll of a hand (rollsRemaining = 1)
    HAND_ACCEPTED = "HAND_ACCEPTED",                 -- Hand accepted (commit)
    HAND_SCORED = "HAND_SCORED",                     -- After hand is scored (finalizeHand)

    -- Economy Triggers
    SHOP_GENERATE_OFFER = "SHOP_GENERATE_OFFER", -- Generating shop items
    SHOP_PURCHASE = "SHOP_PURCHASE",             -- Buying an item
    MONEY_GAIN = "MONEY_GAIN",                   -- Gaining money
    MONEY_SPEND = "MONEY_SPEND",                 -- Spending money
}
