local Util = {}

function Util.deepCopy(tbl: any): any
    local copy = table.clone(tbl)

    for key, value in tbl do
        if type(value) == "table" then
            copy[key] = Util.deepCopy(value)
        end
    end

    return copy
end

function Util.hashString(str: string): number
    local h = 5381;
    for i = 1, #str do
        h = (bit32.lshift(h, 5) + h) + str:byte(i)
    end
    return h
end

return Util