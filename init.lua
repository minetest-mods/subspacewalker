-- constant subspace size
local c_subspacesize = 3

-- Check if the subspace still enabled for user (or can be disabled)
local function ssw_is_enabled(name)
	user = minetest.get_player_by_name(name)
	-- if user leave the game, disable them
	if not user then
		return false
	end
	-- user does not hold the walker in the hand
	local item = user:get_wielded_item()
	if not item or item:get_name() ~= "subspacewalker:walker" then
		return false
	end
	-- all ok, still active
	return true
end

-- get y offset for sneaking or jumping
local function get_player_y_offset(user)
	local control = user:get_player_control()
	local y = 0.5
	if control.jump then
		y = y + 1
	end
	if control.sneak then
		y = y - 1
	end
	return y
end

-- subspacewalker runtime data
local subspacewalker = {
	users_in_subspace = {},
	timer = 0,
}

------------- Minetest registrations -----------------------
-- tool definition
minetest.register_tool("subspacewalker:walker", {
	description = "Subspace Walker",
	inventory_image = "subspace_walker.png",
	wield_image = "subspace_walker.png",
	tool_capabilities = {},
	range = 0,
	on_use = function(itemstack, user, pointed_thing)
		subspacewalker.users_in_subspace[user:get_player_name()] = true
	end,
	on_place = function(itemstack, user, pointed_thing)
		subspacewalker.users_in_subspace[user:get_player_name()] = nil
	end,
	on_secondary_use = function(itemstack, user, pointed_thing)
		subspacewalker.users_in_subspace[user:get_player_name()] = nil
	end
})

-- Globalstep check for nodes to hide
minetest.register_globalstep(function(dtime)
	subspacewalker.timer = subspacewalker.timer + dtime
	if subspacewalker.timer <= 0.3 then
		return
	else
		subspacewalker.timer = 0
	end

	for name,_ in pairs(subspacewalker.users_in_subspace) do
		if not ssw_is_enabled(name) then
			subspacewalker.users_in_subspace[name] = nil
		else
			local userpos = user:getpos()
			local ydelta = get_player_y_offset(user)
			local pos1 = vector.round({x=userpos.x-c_subspacesize, y=userpos.y+ydelta, z=userpos.z-c_subspacesize})
			local pos2 = vector.round({x=userpos.x+c_subspacesize, y=userpos.y+c_subspacesize*2, z=userpos.z+c_subspacesize})

			local manip = minetest.get_voxel_manip()
			local min_c, max_c = manip:read_from_map(pos1, pos2)
			local area = VoxelArea:new({MinEdge=min_c, MaxEdge=max_c})

			local data = manip:get_data()
			local changed = false
			local ssw_id = minetest.get_content_id("subspacewalker:subspace")
			local air_id = minetest.get_content_id("air")

			for i in area:iterp(pos1, pos2) do
				local cur_id = data[i]
				if cur_id and cur_id ~= ssw_id and cur_id ~= air_id then
					local cur_name = minetest.get_name_from_content_id(cur_id)
					data[i] = ssw_id
					minetest.get_meta(area:position(i)):set_string("subspacewalker", cur_name)
					changed = true
				end
			end

			if changed then
				manip:set_data(data)
				manip:write_to_map()
				manip:update_map()
			end
		end
	end
end)

-- node to hide the original one
minetest.register_node("subspacewalker:subspace", {
	drawtype = "airlike",
	paramtype = "light",
	sunlight_propagates = true,
	light_source = 5,
	diggable = false,
	walkable = false,
	groups = {not_in_creative_inventory=1},
	pointable = false,
	drop = ""
})

-- ABM on hidden blocks checks if there can be restored again
minetest.register_abm({
	nodenames = { "subspacewalker:subspace" },
	interval = 0.1,
	chance = 1,
	action = function(pos, node)
		if node.name == 'ignore' then 
			return 
		end

		local can_be_restored = true
		-- check if the node can be restored
		for name, _ in pairs(subspacewalker.users_in_subspace) do
			if not ssw_is_enabled(name) then
				subspacewalker.users_in_subspace[name] = nil
			else
				local userpos = user:getpos()
				local ydelta = get_player_y_offset(user)
				if ( pos.x >= userpos.x-c_subspacesize-1 and pos.x <= userpos.x+c_subspacesize+1) and  -- "+1" is to avoid flickering of nodes. restoring range is higher then the effect range
						( pos.y >= userpos.y+ydelta and pos.y <= userpos.y+c_subspacesize*2+1 ) and
						( pos.z >= userpos.z-c_subspacesize-1 and pos.z <= userpos.z+c_subspacesize+1) then
					can_be_restored = false  --active user in range
				end
			end
		end

		--restore them
		if can_be_restored then
			local node = minetest.get_node(pos)
			local meta = minetest.get_meta(pos)
			local data = meta:to_table()
			node.name = data.fields.subspacewalker
					data.fields.subspacewalker = nil
					meta:from_table(data)
					minetest.swap_node(pos, node)
		end
	end
})

minetest.register_craft({
	output = "subspacewalker:walker",
	width = 1,
	recipe = {
			{"default:diamond"},
			{"default:mese_crystal"},
			{"group:stick"}
	}
})
