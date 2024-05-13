-- To do :
--Find bot with smaller health than my bot. Within the attack range, attack the bot with a smaller energy than mine, and avoid the  bot with larger energy than my bot.
-- Initializing global variables to store the latest game state and game host process.
LatestGameState = LatestGameState or nil
CRED = "Sa0iBLPNyJQrwpTTG-tWLQU-1QeUAJA73DdxGGiKoJc"
Game = "ERRyYc0K3XurSBjpiTceT7Cg9acJaz-bES6w8SXhk-M"
InAction = InAction or false -- Prevents the agent from taking multiple actions at once.

Logs = Logs or {}

colors = {
    red = "\27[31m",
    green = "\27[32m",
    blue = "\27[34m",
    reset = "\27[0m",
    gray = "\27[90m"
}

-- Function to add log messages
function addLog(msg, text)
    Logs[msg] = Logs[msg] or {}
    table.insert(Logs[msg], text)
end

-- Checks if two points are within a given range.
-- @param x1, y1: Coordinates of the first point.
-- @param x2, y2: Coordinates of the second point.
-- @param range: The maximum allowed distance between the points.
-- @return: Boolean indicating if the points are within the specified range.
function inRange(x1, y1, x2, y2, range)
    return math.abs(x1 - x2) <= range and math.abs(y1 - y2) <= range
end

-- Decides the next action based on player proximity, health, and energy.
function decideNextAction()
    local player = LatestGameState.Players[ao.id]
    local potentialTargets = {}

    -- Find potential targets to defend against or attack
    for targetId, state in pairs(LatestGameState.Players) do
        if targetId ~= ao.id then
            local distance = calculateDistance(player.x, player.y, state.x, state.y)
            local isWeaker = state.health < player.health
            local isInRange = inRange(player.x, player.y, state.x, state.y, 2)

            if isWeaker and isInRange then
                table.insert(potentialTargets, { player = state, distance = distance })
            end
        end
    end

    -- Sort potentialTargets based on distance (closest first)
    table.sort(potentialTargets, function(a, b) return a.distance < b.distance end)
    
    -- Defend against closest weaker player or attack if appropriate
    if #potentialTargets > 0 then
        local targetPlayer = nil
        for id, target in pairs(potentialTargets) do
            if target.energy > player.energy then
                targetPlayer = target
                break
            end
        end
        if targetPlayer ~= nil then
            print(colors.red .. "Attacking weaker player with ID: " .. targetPlayer.id .. colors.reset)
            -- Perform attack action if enough energy and target is in range
            ao.send({
                Target = Game,
                Action = "PlayerAttack",
                Player = ao.id,
                AttackEnergy = tostring(player.energy), -- Adjust attack energy based on strategy
                TargetPlayer = targetPlayer.id
            })
        else
            moveAwayFromTarget(targetPlayer.x, targetPlayer.y)
        end
    else
        print(colors.red .. "No immediate threats. Holding position." .. colors.reset)
        -- Hold position or perform default action (e.g., move randomly)
        moveRandomly()
    end

    InAction = false -- Reset InAction flag
end

-- Function to calculate distance between two points
function calculateDistance(x1, y1, x2, y2)
    return math.sqrt((x1 - x2) ^ 2 + (y1 - y2) ^ 2)
end

-- Helper function: Move away from a specific target
function moveAwayFromTarget(targetX, targetY)
    local player = LatestGameState.Players[ao.id]
    local directionX = ""
    local directionY = ""

    -- Determine the direction to move away from the target
    if targetX > player.x then
        directionX = "Left"
    elseif targetX < player.x then
        directionX = "Right"
    end

    if targetY > player.y then
        directionY = "Up"
    elseif targetY < player.y then
        directionY = "Down"
    end

    if directionX ~= "" or directionY ~= "" then
        local direction = directionY .. directionX
        print(colors.red .. "Moving away from target: " .. direction .. colors.reset)
        ao.send({
            Target = Game,
            Action = "PlayerMove",
            Player = ao.id,
            Direction = direction
        })
    else
        print(colors.red .. "Already away from the target's position." .. colors.reset)
    end
end

-- Helper function: Move cautiously or maintain position
function moveCautiously()
    local directionMap = { "Up", "Down", "Left", "Right" }
    local randomIndex = math.random(#directionMap)
    local direction = directionMap[randomIndex]

    print(colors.red .. "Moving cautiously: " .. direction .. colors.reset)
    ao.send({
        Target = Game,
        Action = "PlayerMove",
        Player = ao.id,
        Direction = direction
    })
end

-- Helper function: Move randomly
function moveRandomly()
    local directionMap = { "Up", "Down", "Left", "Right", "UpRight", "UpLeft", "DownRight", "DownLeft" }
    local randomIndex = math.random(#directionMap)
    local direction = directionMap[randomIndex]

    print(colors.red .. "Moving randomly: " .. direction .. colors.reset)
    ao.send({
        Target = Game,
        Action = "PlayerMove",
        Player = ao.id,
        Direction = direction
    })
end

-- Handler to print game announcements and trigger game state updates.
Handlers.add(
    "PrintAnnouncements",
    Handlers.utils.hasMatchingTag("Action", "Announcement"),
    function(msg)
        if msg.Event == "Started-Waiting-Period" then
            ao.send({ Target = ao.id, Action = "AutoPay" })
        elseif (msg.Event == "Tick" or msg.Event == "Started-Game") and not InAction then
            InAction = true  -- InAction logic added
            ao.send({ Target = Game, Action = "GetGameState" })
        elseif InAction then -- InAction logic added
            print("Previous action still in progress. Skipping.")
        end
        print(colors.green .. msg.Event .. ": " .. msg.Data .. colors.reset)
    end
)

-- Handler to trigger game state updates.
Handlers.add(
    "GetGameStateOnTick",
    Handlers.utils.hasMatchingTag("Action", "Tick"),
    function()
        if not InAction then -- InAction logic added
            InAction = true  -- InAction logic added
            print(colors.gray .. "Getting game state..." .. colors.reset)
            ao.send({ Target = Game, Action = "GetGameState" })
        else
            print("Previous action still in progress. Skipping.")
        end
    end
)

-- Handler to automate payment confirmation when waiting period starts.
Handlers.add(
    "AutoPay",
    Handlers.utils.hasMatchingTag("Action", "AutoPay"),
    function(msg)
        print("Auto-paying confirmation fees.")
        ao.send({ Target = Game, Action = "Transfer", Recipient = Game, Quantity = "1000" })
    end
)

-- Handler to update the game state upon receiving game state information.
Handlers.add(
    "UpdateGameState",
    Handlers.utils.hasMatchingTag("Action", "GameState"),
    function(msg)
        local json = require("json")
        LatestGameState = json.decode(msg.Data)
        ao.send({ Target = ao.id, Action = "UpdatedGameState" })
        print("Game state updated. Print \'LatestGameState\' for detailed view.")
    end
)

-- Handler to decide the next best action.
Handlers.add(
    "decideNextAction",
    Handlers.utils.hasMatchingTag("Action", "UpdatedGameState"),
    function()
        if LatestGameState.GameMode ~= "Playing" then
            InAction = false -- InAction logic added
            return
        end
        print("Deciding next action.")
        decideNextAction()
        ao.send({ Target = ao.id, Action = "Tick" })
    end
)

-- Handler to automatically attack when hit by another player.
Handlers.add(
    "ReturnAttack",
    Handlers.utils.hasMatchingTag("Action", "Hit"),
    function(msg)
        if not InAction then -- InAction logic added
            InAction = true  -- InAction logic added
            local playerEnergy = LatestGameState.Players[ao.id].energy
            if playerEnergy == nil then
                print(colors.red .. "Unable to read energy." .. colors.reset)
                ao.send({ Target = Game, Action = "Attack-Failed", Reason = "Unable to read energy." })
            elseif playerEnergy == 0 then
                print(colors.red .. "Player has insufficient energy." .. colors.reset)
                ao.send({ Target = Game, Action = "Attack-Failed", Reason = "Player has no energy." })
            else
                print(colors.red .. "Returning attack." .. colors.reset)
                ao.send({ Target = Game, Action = "PlayerAttack", Player = ao.id, AttackEnergy = tostring(playerEnergy) })
            end
            InAction = false -- InAction logic added
            ao.send({ Target = ao.id, Action = "Tick" })
        else
            print("Previous action still in progress. Skipping.")
        end
    end
)
