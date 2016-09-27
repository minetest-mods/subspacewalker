
local c_subspacesize = 3

local subspacewalker = {}
subspacewalker.users = {}


subspacewalker.enable_ssw = function(itemstack, user, pointed_thing)	
	subspacewalker.users[user:get_player_name()] = user
	print("sww enabled")
end


subspacewalker.disable_user = function(username)
	if username and subspacewalker.users[username] then
		subspacewalker.users[username] = nil
	end
	print("sww disabled")
end


subspacewalker.disable_ssw = function(itemstack, user, pointed_thing)
	subspacewalker.disable_user(user:get_player_name())
end

subspacewalker.ssw_is_enabled = function(user)
	if not user then -- if user leave the game, disable them
		return false
	end

	local item = user:get_wielded_item()
	if not item or item:get_name() ~= "subspacewalker:walker" then
        return false
    end
    return true
end

subspacewalker.hide_node = function(pos)
    local node = minetest.get_node(pos)
    if node and node.name ~= "air" and node.name ~= "subspacewalker:subspace" and node.name ~= 'ignore' then
        -- Save the node's original name
        minetest.get_meta(pos):set_string("subspacewalker", node.name)
        -- Swap in placeholder node
        node.name = "subspacewalker:subspace"
        minetest.swap_node(pos, node)
    end
end

subspacewalker.get_player_y_offset = function(user)
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

local timer = 0
subspacewalker.hide_blocks = function(dtime)
	timer = timer + dtime;
	if timer < 0.25 then
		return
	end

	for name, user in pairs(subspacewalker.users) do
		if not subspacewalker.ssw_is_enabled(user) then
			subspacewalker.disable_user(user:get_player_name())
		else
			local userpos = user:getpos()
			local ydelta = subspacewalker.get_player_y_offset(user)
			for x=userpos.x-c_subspacesize, userpos.x+c_subspacesize do
				for y=userpos.y+ydelta,     userpos.y+c_subspacesize*2 do -- we need the ground under the user
					for z=userpos.z-c_subspacesize, userpos.z+c_subspacesize do
						subspacewalker.hide_node({x=x,y=y,z=z})
					end
				end
			end
		end
	end
end


subspacewalker.restore_blocks = function(pos, node)

	if node.name == 'ignore' then return end

	local can_be_restored = true
-- check if the node can be restored
	for name, user in pairs(subspacewalker.users) do
		if not subspacewalker.ssw_is_enabled(user) then
			subspacewalker.disable_user(user:get_player_name())
		else
			local userpos = user:getpos()
			local ydelta = subspacewalker.get_player_y_offset(user)			
			if ( pos.x >= userpos.x-c_subspacesize-1 and pos.x <= userpos.x+c_subspacesize+1) and  -- "+1" is to avoid flickering of nodes. restoring range is higher then the effect range
			   ( pos.y >= userpos.y+ydelta           and pos.y <= userpos.y+c_subspacesize*2+1 ) and
			   ( pos.z >= userpos.z-c_subspacesize-1 and pos.z <= userpos.z+c_subspacesize+1) then
			   can_be_restored = false  --active user in range
			end			   
		end	
	end

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


------------- Minetest registrations -----------------------
-- tool definition
minetest.register_tool("subspacewalker:walker", {
	description = "Subspace Walker",
	inventory_image = "subspace_walker.png",
	wield_image = "subspace_walker.png",
	tool_capabilities = {},
	range = 0,
	on_use = subspacewalker.enable_ssw,
	on_place = subspacewalker.disable_ssw,
	on_secondary_use = subspacewalker.disable_ssw,
})


-- at specific time the active subspacewalker will checked and nodes hidden
minetest.register_globalstep(subspacewalker.hide_blocks)


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


-- the hidden blocks checks if there can be restored again
minetest.register_abm({
        nodenames = { "subspacewalker:subspace" },
        interval = 0.1,
        chance = 1,
        action = subspacewalker.restore_blocks
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
