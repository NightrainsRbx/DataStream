local RunService = game:GetService("RunService")

local RemoteEvent: RemoteEvent = 
    if RunService:IsServer() then Instance.new("RemoteEvent", script) 
    else script:WaitForChild("RemoteEvent")

local RemoteFunction: RemoteFunction = 
    if RunService:IsServer() then Instance.new("RemoteFunction", script) 
    else script:WaitForChild("RemoteFunction")

local Middleware = {}

function Middleware.FireAllClients(...: any)
    RemoteEvent:FireAllClients(...)
end

function Middleware.FireClient(player: Player, ...: any)
    RemoteEvent:FireClient(player, ...)
end

function Middleware.OnClientEvent(callback: (...any) -> ())
    RemoteEvent.OnClientEvent:Connect(callback)
end

function Middleware.InvokeServer(...: any): any
    return RemoteFunction:InvokeServer(...)
end

function Middleware.OnServerInvoke(callback: (Player, ...any) -> any)
    RemoteFunction.OnServerInvoke = function(player, ...)
        return callback(player, ...)
    end
end

return Middleware