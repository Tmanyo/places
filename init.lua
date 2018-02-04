local places = {}
local first_open = {}

local f = io.open(minetest.get_worldpath() .. "/places.db", "r")
if f == nil then
	local f = io.open(minetest.get_worldpath() .. "/places.db", "w")
	f:write(minetest.serialize(places))
	f:close()
end

function save_places()
	local f = io.open(minetest.get_worldpath() .. "/places.db", "w")
	f:write(minetest.serialize(places))
	f:close()
end

function read_places()
	local f = io.open(minetest.get_worldpath() .. "/places.db", "r")
	local data = minetest.deserialize(f:read("*a"))
	f:close()
	return data
end

places = read_places()

function wrap_text(text, limit)
	local new_text = ""
	local x = 1
	if text:len() > limit then
		while x == 1 do
			local s = text:sub(1,limit)
			local space = s:reverse():find(" ")
			if limit == 1 then
				local letter = s:sub(1,1)
				new_text = new_text .. letter .. ","
				text = text:sub(2, text:len())
			else
				if space == nil then
					local split = s:sub(1,(limit - 1))
					new_text = new_text .. split .. "-,"
					text = text:sub(split:len() + 1,
					text:len())
				else
					local last_space = (limit - space) + 1
					new_text = new_text ..
					minetest.formspec_escape(text:sub(1,last_space)) .. ","
					text = text:sub(last_space + 1,
					text:len())
				end
				if text:len() < limit then
					new_text = new_text .. text
					text = ""
				end
			end
			if text == "" then
				x = 0
			end
		end
	else
		new_text = text
	end
	return new_text
end

function get_preview(player, row)
	local key_table = {}
	local value_table = {}
	local description = {}
	for k,v in pairs(places) do
		table.insert(key_table, k)
		table.insert(value_table, v)
	end
	for k,v in pairs(value_table[row]) do
		if k == "description" then
			description = v
		end
	end
	places_form(player, row, 
	"label[5,1;" .. key_table[row] .. "]" ..
	"image[4.4,1.5;4,3;" .. string.lower(key_table[row]):gsub(" ", "_"):
	gsub("\'", "") .. ".png]" ..
	"textlist[4.5,4.5;3,3.5;description_text;" .. 
	wrap_text(description, 28) .. ";;true]")
end
	

function places_form(player, selected, preview)
	local list = ""
	for k,v in pairs(places) do
		list = list .. k .. ","
	end
	list = list:gsub(",$", "")
	minetest.show_formspec(player:get_player_name(), "places:list",
		"size[8,8]" ..
		"label[.5,0;Single click to view preview. - Double click to teleport.]" ..
		"textlist[0,.5;4,6;place_list;" .. list .. ";" .. selected .. ";false]" ..
		"button[1,7;2,1;add_place;New Place]" ..
		"label[5.4,.5;" .. minetest.colorize("#FF0000", "Preview") .. "]" ..
		preview)
end

function new_place(player)
	minetest.show_formspec(player:get_player_name(), "places:new_place",
		"size[8,8]" ..
		"field[.5,.5;4,1;place_name;Name of Place:;" ..
		minetest.formspec_escape("") .. "]" ..
		"field[5,.5;3,1;location;Coordinates:;" ..
		minetest.formspec_escape("") .. "]" ..
		"textarea[.5,2;7,5;place_description;Description:;" ..
		minetest.formspec_escape("") .. "]" ..
		"button[1,7;2,1;submit;Submit]")
end

minetest.register_privilege("add_place", {
	description = "Can add places to the place list.",
	give_to_singleplayer = false,
})

minetest.register_chatcommand("places", {
	param = "<place_name>",
	description = "<place_name>: Find places of interest!",
	func = function(name, param)
		first_open = 1
		minetest.after(1, function()
			first_open = 0
		end)
		local playername = minetest.get_player_by_name(name)
		local count = 0
		local selected = {}
		for k,v in pairs(places) do
			count = count + 1
			if string.lower(param) == string.lower(k) then
				selected = count
				get_preview(playername, selected)
				return false
			else	
				if places ~= nil then
					local distance_table = {}
					local player_pos = playername:get_pos()
					for k,v in pairs(places) do
						local place_pos = minetest.string_to_pos(v.location)
						table.insert(distance_table,
						vector.distance(player_pos, place_pos))
					end
					local close_place = math.min(unpack(distance_table))
					for k,v in pairs(distance_table) do
						if v == close_place then
							selected = k
						end
					end
				else
					selected = ""
				end
				get_preview(playername, selected)
			end
		end
		if count == 0 then
			places_form(playername, "", "")
		end
	end
})

minetest.register_on_player_receive_fields(function(player, formname, fields)
	if formname == "places:list" then
		if fields.add_place then
			if minetest.check_player_privs(player:get_player_name(),
			{add_place=true}) then
				new_place(player)
			else
				minetest.chat_send_player(player:get_player_name(),
				"[Places] Insufficient Privileges.")
			end
		end
		local key_table = {}
		local value_table = {}
		for k,v in pairs(places) do
			table.insert(key_table, k)
			table.insert(value_table, v)
		end
		local event = minetest.explode_textlist_event(fields.place_list)
		local location = {}
		if event.type == "CHG" then
			if key_table[event.index] and #key_table >= 1 then
				local description = {}
				for k,v in pairs(value_table[event.index]) do
					if k == "description" then
						description = v
					end
				end
				places_form(player, event.index, 
				"label[5,1;" .. key_table[event.index] .. "]" ..
				"image[4.4,1.5;4,3;" .. string.lower(key_table[event.index]):gsub(" ", "_"):
				gsub("\'", "") .. ".png]" ..
				"textlist[4.5,4.5;3,3.5;description_text;" .. 
				wrap_text(description, 28) .. ";;true]")
			end
		elseif event.type == "DCL" then
			if first_open ~= 1 then
				if key_table[event.index] and #key_table >= 1 then
					for k,v in pairs(value_table[event.index]) do
						if k == "location" then
							location = v
						end
					end
					local coordinates = minetest.string_to_pos(location)
					player:setpos(coordinates)
					minetest.chat_send_player(player:get_player_name(),
					"[Places] Successfully Teleported To Place!")
				end
			end
		end
	end
	if formname == "places:new_place" then
		if fields.submit then
			if fields.place_name ~= "" and 
			fields.place_description ~= "" and
			fields.location:match("^.+,.+,.+$") then
				if not places[fields.place_name] then
					places[fields.place_name] = {}
				end
				places[fields.place_name] = {description = 
				fields.place_description, location = fields.location}
				save_places()
				places_form(player, "", "")
			else
				minetest.chat_send_player(player:get_player_name(),
				"[Places] One or several fields have an insufficient value.")
			end
		end
	end
end)
