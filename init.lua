geodes_lib = {}

local function generate_geode_vm(pos, radius, inner_cid, inner_alt_cid, inner_alt_chance, shell_cids, data, area)
end

function geodes_lib:register_geode(data)
    local inner = data.inner
    local id = data.id or ""
    local technical_name = inner .. "_technical_mapgen" .. id
    core.register_alias(technical_name, "air")
end
