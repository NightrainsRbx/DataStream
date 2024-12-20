local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SharedData = require(ReplicatedStorage.Shared.SharedData)

local RoundData = SharedData.MatchData:Wait()
local PlayerData = SharedData.PlayerData:Wait()

print(RoundData:GetData())
print(PlayerData:GetData())

RoundData.Changed:Connect(function()
    print(RoundData:GetData().TimeLeft)
end)

RoundData.Removed:Connect(function()
    print("removed", RoundData:HasData())
end)

task.wait(4)

print(PlayerData:GetData())