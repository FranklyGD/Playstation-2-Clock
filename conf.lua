function love.conf(t)
	t.version = "0.10.2"
	t.accelerometerjoystick = false

	t.window.title = "Playstation 2 Clock"
	t.window.icon = nil -- Will probably add
	t.window.resizable = true
	t.window.fullscreen = true
	t.window.fullscreentype = "desktop"
	t.window.vsync = true

	t.modules.joystick = false
	t.modules.physics = false
	t.modules.touch = false
	t.modules.video = false
end