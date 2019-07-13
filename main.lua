local pillar = require "hour_pillar"
pillar.scale = 7

local last_second = 0
local milli_offset = 0

local hours, minutes, seconds

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
		return (source - vec4(.75,.75,.75,0)) * color;
	}
]])

local horizontal_blur = love.graphics.newShader([[
	extern float size = 1;
	extern int samples = 4;
	extern float[] weights = {.2,.2,.2,.2,.2};

	vec4 effect(vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords) {
		vec4 source = Texel(tex, texture_coords);
		vec4 sum = source * weights[0];
		
		for (int x = 1; x < samples; x++) {
			vec2 offset = vec2(x * size, 0);
			sum += Texel(tex, texture_coords + offset) * weights[x];
		}

		for (int x = 1; x < samples; x++) {
			vec2 offset = vec2(-x * size, 0);
			sum += Texel(tex, texture_coords + offset) * weights[x];
		}
		
		return sum * color;
	}
]])

local vertical_blur = love.graphics.newShader([[
	extern float size = 1;
	extern int samples = 4;
	extern float[] weights = {.2,.2,.2,.2,.2};

	vec4 effect(vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords) {
		vec4 source = Texel(tex, texture_coords);
		vec4 sum = source * weights[0];
		
		for (int y = 1; y < samples; y++) {
			vec2 offset = vec2(0, y * size);
			sum += Texel(tex, texture_coords + offset) * weights[y];
		}

		for (int y = 1; y < samples; y++) {
			vec2 offset = vec2(0, -y * size);
			sum += Texel(tex, texture_coords + offset) * weights[y];
		}
		
		return sum * color;
	}
]])

local source
local downsample1, downsample2, downsample3
local h_blur1, h_blur2, h_blur3

function love.load()
	last_second = tonumber(os.date("%S"))
	love.graphics.setBackgroundColor(0, 0, 0)

	local v = 4
	local dist = {}
	for i=0,v do
		dist[i+1] = 1/math.sqrt(2*math.pi*v)*2.71828^(-i*i/(2*v))
	end

	horizontal_blur:send("weights", unpack(dist))
	vertical_blur:send("weights", unpack(dist))
	horizontal_blur:send("samples", v)
	vertical_blur:send("samples", v)

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

half_pi = math.pi / 2

function love.update(dt)
	local app_milliseconds = os.clock()
	hours, minutes, seconds = tonumber(os.date("%H")), tonumber(os.date("%M")), tonumber(os.date("%S"))

	if seconds ~= last_second then
		milli_offset = app_milliseconds
	end
	last_second = seconds;
	seconds = seconds + app_milliseconds - milli_offset;

	local seconds_rotation = seconds / 30 * math.pi

	for i,p in ipairs(hour_pillar_objects) do
		local i6pi = i / 6 * math.pi

		local vx = math.sin(i6pi) * math.cos(seconds_rotation)
		local vy = -math.cos(i6pi)

		p.position.x = math.cos(seconds_rotation) * math.sin(i6pi) * pillar.scale * 35
		
		p.rotation.x = math.acos(math.sqrt(vy*vy + vx*vx)) * (math.sin(i6pi) * math.sin(seconds_rotation) > 0 and 1 or -1)
		p.rotation.y = seconds_rotation
		p.rotation.z = math.atan2(vy,vx) + half_pi
	end

	--local vx = 0 * math.cos(seconds_rotation)
	--local vy = -1

	local hour_progress = (minutes + seconds / 60) / 60

	current_hour_progress.position.y = -pillar.scale * (35 + 15 * (1 - hour_progress))
	
	current_hour_progress.rotation.x = 0 --[[ math.acos(math.sqrt(vy*vy + vx*vx))]]
	current_hour_progress.rotation.y = seconds_rotation
	current_hour_progress.rotation.z = math.pi --[[math.atan2(vy, vx) + half_pi]]

	current_hour_progress.size.h = 30 * hour_progress

	local second_prog = seconds % 1
	local _second_prog = 1 - second_prog 
	local pulse_power = _second_prog ^ 1.5 * 0.5 + 0.5
	current_hour_progress.emit = {60 * pulse_power, 157 * pulse_power, 255 * pulse_power, 0}

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
		love.graphics.translate(window.w * 0.6667 - (shift.x + shift.vx) / window.w * 32, window.h / 2 - (shift.y + shift.vy) / window.h * 32)

		draw_clock()
		draw_orbs()
	love.graphics.pop()

	love.graphics.setColor(255, 255, 255)

	love.graphics.setShader(cutoff)
	love.graphics.setCanvas(downsample3)
	love.graphics.scale(1/8)
	love.graphics.draw(source)
	love.graphics.origin()
	
	love.graphics.setCanvas(downsample2)
	love.graphics.scale(1/4)
	love.graphics.draw(source)
	love.graphics.origin()

	love.graphics.setCanvas(downsample1)
	love.graphics.scale(1/2)
	love.graphics.draw(source)
	love.graphics.origin()
	
	love.graphics.setShader(horizontal_blur)

	local size = 0.75
	local scale_w = size / window.w
	local scale_h = size / window.h

	horizontal_blur:send("size", scale_w * 8)
	love.graphics.setCanvas(h_blur3)
	love.graphics.draw(downsample3)

	horizontal_blur:send("size", scale_w * 4)
	love.graphics.setCanvas(h_blur2)
	love.graphics.draw(downsample2)

	horizontal_blur:send("size", scale_w * 2)
	love.graphics.setCanvas(h_blur1)
	love.graphics.draw(downsample1)

	love.graphics.setCanvas()
	love.graphics.setShader()
	love.graphics.draw(source)
	love.graphics.setBlendMode("add")
	
	love.graphics.setShader(vertical_blur)
	love.graphics.setColor(255, 255, 255)
	
	love.graphics.scale(8)
	vertical_blur:send("size", scale_h * 8)
	love.graphics.draw(h_blur3)
	love.graphics.origin()

	love.graphics.scale(4)
	vertical_blur:send("size", scale_h * 4)
	love.graphics.draw(h_blur2)
	love.graphics.origin()

	love.graphics.scale(2)
	vertical_blur:send("size", scale_h * 2)
	love.graphics.draw(h_blur1)
	love.graphics.origin()

	love.graphics.setBlendMode("alpha")
end

function love.resize(w, h)
	window.w = w
	window.h = h
	
	source = love.graphics.newCanvas(w, h, "hdr", 4)
	local w1,w2,w3,h1,h2,h3 = w/2,w/4,w/8,h/2,h/4,h/8
	downsample1 = love.graphics.newCanvas(w1, h1)
	downsample2 = love.graphics.newCanvas(w2, h2)
	downsample3 = love.graphics.newCanvas(w3, h3)
	h_blur1 = love.graphics.newCanvas(w1, h1)
	h_blur2 = love.graphics.newCanvas(w2, h2)
	h_blur3 = love.graphics.newCanvas(w3, h3)
end

function love.mousemoved(x, y, dx, dy)
	shift.x, shift.y = x, y
	shift.vx, shift.vy = shift.vx + dx / 2, shift.vy + dy / 2
end

function lerp(x,y,t)
	return y*t+x*(1-t)
end

function draw_clock()
	love.graphics.push()
	love.graphics.rotate(hours / 6 * math.pi)
	
	for i,v in ipairs(hour_pillar_objects) do
		v:draw()
	end
	
	current_hour_progress:draw()
	love.graphics.pop()
end

function draw_orbs()
	love.graphics.push()
	love.graphics.rotate((hours+(minutes/60)) / 6 * math.pi)
	for i=0,6 do
		local x,y = math.sin(i / 7 * 2 * math.pi), math.cos(i / 7 * 2 * math.pi)
		local spin = seconds / 1 * math.pi
		local nx,ny = x * math.cos(spin) - y * math.sin(spin), x * math.sin(spin) + y * math.cos(spin)
		nx = nx * math.sin(seconds / 1.5 * math.pi)
		if (i <= tonumber(os.date("%w"))) then
			love.graphics.setColor(255, 390, 550, 255)
		else
			love.graphics.setColor(450, 390, 255, 255)
		end
		love.graphics.circle("fill", -15*pillar.scale*nx, -15*pillar.scale*ny, pillar.scale * 1.25, 16)
	end
	love.graphics.pop()
end