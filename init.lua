geodes_lib = {}

local geode_tech_map = {}
local mapgen_registered = false
local c_air = core.get_content_id("air")

local function generate_geode_vm(pos, radius, inner_cid, inner_alt_cid, inner_alt_chance, shell_cids, data, area)
    local shell_count = #shell_cids
    local total_radius = radius + 1 + shell_count
    
    local shell_radii_sq = {}
    for i = 1, shell_count do
        local r = total_radius - (i - 1)
        shell_radii_sq[i] = r * r
    end
    local core_radius_sq = (radius + 1) * (radius + 1)
    local cavity_radius_sq = radius * radius

    local math_random = math.random
    local alt_chance = inner_alt_chance or 10
    
    for z = -total_radius, total_radius do
        for y = -total_radius, total_radius do
            for x = -total_radius, total_radius do
                local dist_sq = x*x + y*y + z*z
                
                if dist_sq < shell_radii_sq[1] then
                    local index = area:index(pos.x + x, pos.y + y, pos.z + z)
                    
                    if index and data[index] then
                        if dist_sq < cavity_radius_sq then
                            data[index] = c_air
                        elseif dist_sq < core_radius_sq then
                            data[index] = (math_random(1, alt_chance) == 1) and inner_alt_cid or inner_cid
                        else
                            for i = shell_count, 1, -1 do
                                if dist_sq < shell_radii_sq[i] then
                                    data[index] = shell_cids[i]
                                    break
                                end
                            end
                        end
                    end
                end
            end
        end
    end
end

local function register_mapgen_callback()
    if mapgen_registered then return end

    core.register_on_generated(function(minp, maxp, seed)
        local vm, emin, emax = core.get_mapgen_object("voxelmanip")
        if not vm then return end

        local area = VoxelArea:new{MinEdge = emin, MaxEdge = emax}
        local data = vm:get_data()
        local modified = false

        for tech_cid, defs in pairs(geode_tech_map) do
            for _, def in ipairs(defs) do
                if not def.resolved then
                    def.inner_cid = core.get_content_id(def.inner_name)
                    def.inner_alt_cid = core.get_content_id(def.inner_alt_name)
                    def.wherein_cid = core.get_content_id(def.wherein_name)
                    def.shell_cids = {}
                    for _, name in ipairs(def.shell_names) do
                        table.insert(def.shell_cids, core.get_content_id(name))
                    end
                    def.resolved = true
                end
            end
        end

        for index = 1, #data do
            local cid = data[index]
            local defs = geode_tech_map[cid]
            if defs then
                local pos = area:position(index)
                for _, def in ipairs(defs) do
                    if math.random(1, 100) <= def.generation_chance then
                        generate_geode_vm(
                            pos,
                            math.random(def.radius_min, def.radius_max),
                            def.inner_cid,
                            def.inner_alt_cid,
                            def.inner_alt_chance,
                            def.shell_cids,
                            data,
                            area
                        )
                    else
                        data[index] = def.wherein_cid
                    end
                    modified = true
                end
            end
        end

        if modified then
            vm:set_data(data)
            vm:set_lighting({day = 0, night = 0}) 
            vm:calc_lighting()
            vm:write_to_map()
        end
    end)

    mapgen_registered = true
end

function geodes_lib:register_geode(data)
    local inner = data.inner
    local id = data.id or ""
    local technical_name = inner .. "_technical_mapgen" .. id

    core.register_node(technical_name, {
        description = "Geode Technical Node",
        groups = {not_in_creative_inventory = 1},
    })

    core.register_ore({
        ore_type = "scatter",
        ore = technical_name,
        wherein = data.wherein or "mapgen_stone",
        clust_scarcity = data.scarcity * data.scarcity * data.scarcity,
        clust_num_ores = 1,
        clust_size = 1,
        y_min = data.y_min,
        y_max = data.y_max,
    })

    local def = {
        inner_name = data.inner,
        inner_alt_name = data.inner_alt or data.inner,
        inner_alt_chance = data.inner_alt_chance or 10,
        shell_names = data.shell or {},
        wherein_name = data.wherein or "mapgen_stone",
        radius_min = data.radius_min or 2,
        radius_max = data.radius_max or 5,
        generation_chance = data.generation_chance or 100,
        resolved = false
    }

    core.register_on_mods_loaded(function()
        local tech_cid = core.get_content_id(technical_name)
        geode_tech_map[tech_cid] = geode_tech_map[tech_cid] or {}
        table.insert(geode_tech_map[tech_cid], def)
    end)

    register_mapgen_callback()
end
