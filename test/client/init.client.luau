local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SharedData = require(ReplicatedStorage.Shared.SharedData)

local RoundData = SharedData.RoundData:Wait()
local PlayerData = SharedData.PlayerData:Wait()

print(RoundData:GetData())
print(PlayerData:GetData())

RoundData.Changed:Connect(function() 
    print(RoundData:GetData().TimeLeft)
end)

task.wait(5)

print(PlayerData:GetData())