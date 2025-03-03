local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local SharedData = require(ReplicatedStorage.Shared.SharedData)

local MatchData = SharedData.MatchData

local function StartMatch(players: {Player})
    local dataId = MatchData:GetId({
        IsMatch = true,
        TimeLeft = 200
    })

    print(dataId == MatchData:GetId(MatchData:GetData(dataId)))

    for _, player in players do
        MatchData:SetData(player, dataId)
    end

    task.delay(8, function()
        MatchData:RemoveData(players[1])
        -- MatchData:RemoveData(dataId)
    end)

    while task.wait(1) do
        -- MatchData:GetMutable(players[1]).TimeLeft -= 1
        -- MatchData:GetMutable(dataId).TimeLeft -= 1
        MatchData:UpdateData(dataId, function(data)
            data.TimeLeft -= 1
        end)
    end
end

Players.PlayerAdded:Connect(function()
    -- if #Players:GetPlayers() < 2 then
    --     return
    -- end
    StartMatch(Players:GetPlayers())
end)