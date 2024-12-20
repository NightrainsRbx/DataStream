local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players") 

local SharedData = require(ReplicatedStorage.Shared.SharedData)

local RoundData = SharedData.RoundData
local PlayerData = SharedData.PlayerData

RoundData:SetData({
    TimeLeft = 300
})

Players.PlayerAdded:Connect(function(player)
    PlayerData:SetData(player, {
        Coins = 100,
        Inventory = {}
    })

    task.wait(3)

    local dataMut = PlayerData:GetDataMutable(player)
    dataMut.Coins += 50
    table.insert(dataMut.Inventory, "Axe")
end)

Players.PlayerRemoving:Connect(function(player)
    PlayerData:RemoveData(player)
end)

local roundDataMut = RoundData:GetDataMutable()
while task.wait(1) do
    roundDataMut.TimeLeft -= 1
end