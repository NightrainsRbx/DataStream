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
    local hash = 5381
	
    for i = 1, #str do
        hash = (bit32.lshift(hash, 5) + hash) + str:byte(i)
    end
	
    return hash
end

return Util