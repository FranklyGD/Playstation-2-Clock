local pillar = require "hour_pillar"
pillar.scale = 7

local last_second = 0
local milli_offset = 0

local hour_pillar_objects = {}
local current_hour_progress

local window = {
	w = 0,
	h = 0
}

local shift = { x = 0, y = 0, vx = 0, vy = 0 }

local cutoff = love.graphics.newShader([[
	vec4 effect(vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords) {
		vec4 source = Texel(tex, texture_coords);
		return source - vec4(.75,.75,.75,0);
	}
]])

local horizontal_blur = love.graphics.newShader([[
	extern float size = 1;
	extern int samples = 4;

	vec4 effect(vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords) {
		vec4 source = Texel(tex, texture_coords);
		vec4 sum = vec4(0);
		
		for (int x = -samples; x <= samples; x++) {
			vec2 offset = vec2(x * size, 0);
			sum += Texel(tex, texture_coords + offset);
		}
		
		return sum / (2 * samples + 1) * color;
	}
]])

local vertical_blur = love.graphics.newShader([[
	extern float size = 1;
	extern int samples = 4;

	vec4 effect(vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords) {
		vec4 source = Texel(tex, texture_coords);
		vec4 sum = vec4(0);
		
		for (int y = -samples; y <= samples; y++) {
			vec2 offset = vec2(0, y * size);
			sum += Texel(tex, texture_coords + offset);
		}
		
		return sum / (2 * samples + 1) * color;
	}
]])

local source
local downsample4
local downsample8
local h_blur4
local h_blur8

function love.load()
	last_second = tonumber(os.date("%S"))
	love.graphics.setBackgroundColor(15, 15, 15)

	horizontal_blur:send("samples", 8)
	vertical_blur:send("samples", 8)

	for i=1,12 do
		local p = pillar:new()
		local pos = p.position
		pos.x, pos.y = math.sin(i/6*math.pi) * pillar.scale * 35, -math.cos(i/6*math.pi) * pillar.scale * 35
		p.rotation.z = i/6*math.pi
		p.color = 12 == i and {151, 239, 254, 32} or {8, 28, 72, 255}

		table.insert(hour_pillar_objects, p)
	end
	
	current_hour_progress = pillar:new()
	current_hour_progress.color = {60, 157, 255, 255}
end

function love.update(dt)
	local app_milliseconds = os.clock()

	local hours = tonumber(os.date("%H"))
	local minutes = tonumber(os.date("%M"))
	local seconds = tonumber(os.date("%S"))

	if seconds ~= last_second then
		milli_offset = app_milliseconds
	end
	last_second = seconds;

	seconds = seconds + app_milliseconds - milli_offset;
	for i,p in ipairs(hour_pillar_objects) do
		local i6pi = i / 6 * math.pi

		local vx = math.sin(i6pi) * math.cos(seconds / 30 * math.pi)
		local vy = -math.cos(i6pi)

		p.position.x = math.cos(seconds / 30 * math.pi) * math.sin(i6pi) * pillar.scale * 35
		
		p.rotation.x = math.acos(math.sqrt(vy*vy + vx*vx)) * (math.sin(i6pi) * math.sin(seconds / 30 * math.pi) > 0 and 1 or -1)
		p.rotation.y = seconds / 30 * math.pi
		p.rotation.z = math.atan2(vy,vx) + math.pi / 2
	end

	local vx = 0 * math.cos(seconds / 30 * math.pi)
	local vy = -1

	local hour_progress = (minutes+seconds/60)/60

	current_hour_progress.position.y = -pillar.scale * (35 + 15 * (1 - hour_progress))
	
	current_hour_progress.rotation.x = math.acos(math.sqrt(vy*vy + vx*vx))
	current_hour_progress.rotation.y = seconds / 30 * math.pi
	current_hour_progress.rotation.z = math.atan2(vy,vx) + math.pi / 2

	current_hour_progress.size.h = 30*(minutes+seconds/60)/60

print (seconds % 1)

	local second_prog = seconds % 1
	local _second_prog = 1 - second_prog 
	local pulse_power = _second_prog ^ 1.5 * 0.5
	current_hour_progress.emit = {60 * (0.5 + pulse_power), 157 * (0.5 + pulse_power), 255 * (0.5 + pulse_power), 0}

	shift.vx = shift.vx * 0.95
	shift.vy = shift.vy * 0.95

	if not love.filesystem.isFused() and love.keyboard.isDown("escape") then
		love.event.push("quit")
	end
end

function love.draw()
	love.graphics.push()
		love.graphics.setCanvas(source)
		love.graphics.clear(love.graphics.getBackgroundColor())
		love.graphics.translate(window.w * 2/3 - (shift.x + shift.vx) / window.w * 32, window.h / 2 - (shift.y + shift.vy) / window.h * 32)
		love.graphics.rotate(tonumber(os.date("%H")) / 6 * math.pi)
		for i,v in ipairs(hour_pillar_objects) do
			v:draw()
		end
		current_hour_progress:draw()

	love.graphics.pop()

	love.graphics.setColor(255, 255, 255)

	love.graphics.setShader(cutoff)
	love.graphics.setCanvas(downsample8)
	love.graphics.scale(1 / 4)
	love.graphics.draw(source)
	love.graphics.origin()

	love.graphics.setCanvas(downsample4)
	love.graphics.scale(1 / 2)
	love.graphics.draw(source)
	love.graphics.origin()
	
	love.graphics.setShader(horizontal_blur)

	horizontal_blur:send("size", 0.75 / window.w * 4)
	love.graphics.setCanvas(h_blur8)
	love.graphics.draw(downsample8)

	horizontal_blur:send("size", 0.75 / window.w * 2)
	love.graphics.setCanvas(h_blur4)
	love.graphics.draw(downsample4)

	love.graphics.setCanvas()
	love.graphics.setShader()
	love.graphics.draw(source)
	love.graphics.setBlendMode("add")
	
	love.graphics.setShader(vertical_blur)
	
	love.graphics.scale(4)
	vertical_blur:send("size", 0.75 / window.h * 4)
	love.graphics.draw(h_blur8)
	love.graphics.origin()

	love.graphics.scale(2)
	vertical_blur:send("size", 0.75 / window.h * 2)
	love.graphics.draw(h_blur4)
	love.graphics.origin()

	love.graphics.setBlendMode("alpha")
end

function love.resize(w, h)
	window.w = w
	window.h = h
	
	source = love.graphics.newCanvas(w, h, "hdr", 4)
	downsample4 = love.graphics.newCanvas(w / 2, h / 2)
	downsample8 = love.graphics.newCanvas(w / 4, h / 4)
	h_blur4 = love.graphics.newCanvas(w / 2, h / 2)
	h_blur8 = love.graphics.newCanvas(w / 4, h / 4)
end

function love.mousemoved(x, y, dx, dy)
	shift.x, shift.y = x, y
	shift.vx, shift.vy = shift.vx + dx / 2, shift.vy + dy / 2
end

function lerp(x,y,t)
	return y*t+x*(1-t)
end