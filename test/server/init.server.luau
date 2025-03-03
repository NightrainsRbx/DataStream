local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local SharedData = require(ReplicatedStorage.Shared.SharedData)

local RoundData = SharedData.RoundData
local PlayerData = SharedData.PlayerData

RoundData:SetData({
    TimeLeft = 300
})

Players.PlayerAdded:Connect(function(player: Player)
    PlayerData:SetData(player, {
        Coins = math.random(100, 200),
        Inventory = {}
    })

    task.wait(3)

    -- local dataMut = PlayerData:GetMutable(player)
    -- dataMut.Coins += 50
    -- table.insert(dataMut.Inventory, "Axe")
    PlayerData:UpdateData(player, function(data)
        data.Coins += 50
        table.insert(data.Inventory, "Axe")
    end)
end)

Players.PlayerRemoving:Connect(function(player: Player)
    PlayerData:RemoveData(player)
end)

-- local roundDataMut = RoundData:GetMutable()
-- while task.wait(1) do
--     roundDataMut.TimeLeft -= 1
-- end

while task.wait(1) do
    RoundData:UpdateData(function(data)
        data.TimeLeft -= 1
    end)
end