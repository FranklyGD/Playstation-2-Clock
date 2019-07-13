local hour_pillar = {}

hour_pillar.scale = 1;
hour_pillar.side_reflection_color = {17, 105, 240, 255}

function hour_pillar:new()
	local o = {}

	o.position = {
		x = 0,
		y = 0
	}

	o.rotation = {
		x = 0,
		y = 0,
		z = 0
	}

	o.size = {
		r = 3,
		h = 30
	}

	o.color = {255,255,255,255}
	o.emit = {0,0,0,0}

	setmetatable(o, self)
	self.__index = self
	return o
end

function hour_pillar:draw()
	local sin_x = math.sin(self.rotation.x)
	
	love.graphics.push()
		love.graphics.translate(self.position.x, self.position.y)
		love.graphics.rotate(self.rotation.z)
		love.graphics.setColor(255, 255, 255)
		
		-- Sides
		local tri_height = self.size.r / 2 * 3 ^ 0.5
		for i=0,2 do
			local offset = math.pi / 3 * i
			love.graphics.push()

				local rotation_offset = offset + self.rotation.y
				local cos_rot_off = math.cos(rotation_offset)
				local facing = cos_rot_off * math.cos(self.rotation.x)
				local flip = (facing > 0 and 1 or -1)
				facing = math.abs(facing)
				local side_reflect = 1 - (math.abs(math.asin(facing) - 0.5) * 2)

				local final_color = {self.color[1], self.color[2], self.color[3], self.color[4]}

				for i=1,4 do
					final_color[i] = lerp(self.side_reflection_color[i] * side_reflect, final_color[i], facing) + self.emit[i]
				end

				love.graphics.setColor(final_color)

				love.graphics.translate(tri_height * math.cos(rotation_offset - half_pi) * flip * self.scale, tri_height * sin_x * cos_rot_off * -flip * self.scale)
				love.graphics.scale(cos_rot_off, 1)
				love.graphics.shear(0, math.cos(rotation_offset - half_pi) * sin_x)
				love.graphics.scale(1, math.cos(self.rotation.x))

				love.graphics.rectangle("fill", -self.size.r / 2 * self.scale, -self.size.h / 2 * self.scale, self.size.r * self.scale, self.size.h * self.scale)
			
			love.graphics.pop()
		end

		-- Cap
		love.graphics.push()

			local facing = math.abs(sin_x)
			local side_reflect = 1 - (math.abs(math.asin(facing) - 0.5) * 2)

			local final_color = {self.color[1], self.color[2], self.color[3], self.color[4]}

			for i=1,4 do
				final_color[i] = lerp(self.side_reflection_color[i] * side_reflect, final_color[i], facing) + self.emit[i]
			end

			love.graphics.setColor(final_color)
			love.graphics.translate(0, self.size.h / 2 * self.scale * math.cos(self.rotation.x % math.pi))
			love.graphics.scale(1, sin_x)
			love.graphics.rotate(self.rotation.y)

			love.graphics.circle("fill", 0, 0, self.size.r * self.scale, 6)

		love.graphics.pop()
	love.graphics.pop()
end

return hour_pillar