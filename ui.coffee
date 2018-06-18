# ~Wireworld visual simulator.
# ==Extnesion methods==
Function::getter = (name, proc)	-> Object.defineProperty @prototype, name, {get: proc, configurable: true}
Function::setter = (name, proc)	-> Object.defineProperty @prototype, name, {set: proc, configurable: true}
Boolean::either	= (true_val, false_val = '') -> if @valueOf() then true_val else false_val
Function::new_branch = (name, body) -> @getter name, -> new BranchProxy @, body
BranchProxy = (root, body) -> # Auxilary proc for new_branch.
	Object.setPrototypeOf (new Proxy body, 
		{get: (self, key) -> if typeof (val = self[key]) is 'function' then val.bind(self) else val}), root

#.{ [Classes]
class VisualAutomata extends Automata
	powered:	false
	speed:		90
	last_update: 0
	_ascii_set =  " .@*"

	# --Methods goes here.
	constructor: (args...) ->
		super ...args
		setInterval (-> @tick() if @powered and Date.now() - @last_update >= 400 - @speed * 4).bind(@), 10

	morph: (x, y, shift = 1) ->
		@set x, y, Cell.cycle @get(x, y), shift
		return @

	resize: (width, height, feeder = @clear()) ->
		throw new TypeError("invalid matrix data provided") unless height > 1 and width > 1
		[@width, @height, @ticks, @cells] = [width, height, 0, feeder]
		return @

	render: (bmp, scale = 1) ->
		ptr	= 0
		for row, y in @cells
			for cell, x in row
				c = [0x000022, 0xffff00, 0x00ffff, 0xff0000][cell] 
				bmp[ptr++] = c>>16 & 255; bmp[ptr++] = c>>8 & 255; bmp[ptr++] = c & 255; bmp[ptr++] = 0xff
		return @

	tick: (args...) ->
		@last_update = Date.now()
		super ...args

	# --Properties goes here.
	@getter 'ascii', ()	-> ((_ascii_set[cell] for cell in row).join '' for row in @cells).join '\n'
	@setter 'ascii', (val) ->
		val = val.replace /\r/g, ''
		unless val.split('').find (char) -> not (char in _ascii_set or char in '\n')
			height	= (val = val.split '\n').length
			width	= val[0]?.length
		@resize width, height, (Uint8Array.from (_ascii_set.indexOf cell for cell in row) for row in val)
# -------------------- #
class ViewPort
	scroll = {x: 0, y: 0}

	# --Methods goes here.
	constructor: (@scene, @machine) ->
		[@width, @height]	= [@scene.cameras.main.width, @scene.cameras.main.height]
		@output				= @scene.textures.createCanvas 'cvs', @machine.width, @machine.height
		@proj				= @scene.add.image @width / 2, @height / 2, 'cvs'

	pick: (screen_x, screen_y) ->
		[(screen_x - @proj.x + @proj.displayOriginX * @zoom) // @zoom,
		(screen_y - @proj.y + @proj.displayOriginY * @zoom) // @zoom]

	sync: () ->
		# Primary rendering.
		bmp = @output.context.getImageData(0, 0, @machine.width, @machine.height)
		@machine.render bmp.data, @zoom
		# Tiling render.
		tiling = (full, part, corrector) =>
			result = Math.max 1, 2 * Math.sign(corrector) + Math.ceil full / part
			if result % 2 then result else result+1
		xfactor = tiling(@width, @machine.width * @zoom, @scrollX)
		yfactor = tiling(@height, @machine.height * @zoom, @scrollY)
		@output.setSize @machine.width * xfactor, @machine.height * yfactor
		for x in [0..xfactor]
			@output.context.putImageData(bmp, x * @machine.width, y * @machine.height) for y in [0..yfactor]
		@output.refresh()
		# Adjusting projection.
		@proj.destroy()
		@proj = @scene.add.image @width / 2 + @scrollX * @zoom, @height / 2 + @scrollY * @zoom, 'cvs'
		.setScale(@zoom)
		@proj.depth = -1

	# --Properties goes here.
	@getter 'zoom',	()			-> @proj.scaleX
	@setter 'zoom',	(val)		-> @proj.setScale(val)
	@getter 'scrollX', ()		-> scroll.x
	@setter 'scrollX', (val)	-> scroll.x = val.wrap @machine.width
	@getter 'scrollY', ()		-> scroll.y
	@setter 'scrollY', (val)	-> scroll.y = val.wrap @machine.height
# -------------------- #
class UI
	init_scale	= 6
	scrolling	= false

	# --Methods goes here.
	constructor: () ->
		# Primary setup.
		self	= @
		@app	= new Phaser.Game
			type: Phaser.AUTO, width: 900, height: 600, parent: 'vp'
			scene: {preload: (-> self.scene = @), create: @create.bind(@), update: @update.bind(@)}
			title: "Wire=world celluar automata.", version: "0.1"
		@machine = new VisualAutomata @app.canvas.width // init_scale, @app.canvas.height // init_scale, true
		# Error handlers setup.
		window.onerror = (msg, url, ln, col,e) ->
			alert "#{e.toString()} !\nLine №#{ln}[#{col}], #{new URL(url).pathname}"
			return true
		# Some brief signaler.
		midline =  @machine.height // 2 - 1
		@machine.set x, midline for x in [-10..10]
		@machine.set 11, midline + 1
		@machine.set x, midline + 2 for x in [-10..10]
		@machine.set -10, midline, Cell.tail
		@machine.set -11, midline + 1, Cell.head

	create:	() ->
		# External UI setup.
		@vp			= new ViewPort(@scene, @machine)
		@vp.zoom	= init_scale
		@loader		= document.getElementById('loader')
		@loader.addEventListener 'change', @on.import, false
		# Internal UI setup.
		infobar		= (y) =>
			bar = @scene.add.text(@vp.width / 2, y, "{I am error}").setOrigin 0.5
			y	= bar.y - bar.displayOriginY - 1
			for x in [0..@vp.width] by 3
				@decor.lineBetween(x, y, x, y + bar.displayHeight + 2)
			return bar
		@decor		= @scene.add.graphics 0, 0
		@decor.lineStyle 1, 0x0000ff, .3
		@tinformer	= infobar 20
		@binformer	= infobar @vp.height - 20
		# Drag/drop setup.
		document.addEventListener 'dragover', (e) =>
			e.stopPropagation(); e.preventDefault(); e.dataTransfer.dropEffect = 'copy'
		document.addEventListener 'drop', @on.import, false
		# Keyboard inputs.
		@scene.input.keyboard.on "keydown_#{key}", @on[proc] for key, proc of {
			ENTER:'toggle', DELETE:'clear', SPACE:'step',	ESC: 'exit',	PAGE_UP:'zoomin', PAGE_DOWN:'zoomout',
			PLUS:'haste',	MINUS:'slow',	LEFT:'left',	RIGHT:'right',	UP:'up', DOWN:'down'
		}
		window.addEventListener "keydown", (event) =>
			if event.ctrlKey then switch event.which
				when 83 then @on.save()
				when 76 then @on.load()
		# Clipboard inputs.
		window.addEventListener 'paste', (e) => @machine.ascii = e.clipboardData.getData 'Text'
		window.addEventListener 'copy', (e) =>
			e.clipboardData.setData('text/plain', @machine.ascii)
			e.preventDefault()
		# Mouse inputs.
		scroll_lock = (feed) -> scrolling = if feed then {x: feed.x, y: feed.y} else false
		window.addEventListener "wheel", (e) => @on[['zoomin', 'noop', 'zoomout'][1 + Math.sign e.deltaY]]()
		@scene.input.on 'pointerup', ((ptr) => scroll_lock() if ptr.buttons > 2), ui
		@scene.input.on 'pointerdown', ((ptr) ->
			switch ptr.buttons
				when 1 then shift = 1
				when 2 then shift = -1
				else return scroll_lock ptr
			@machine.morph ...(@vp.pick ptr.x, ptr.y), shift), ui
		@scene.input.on 'pointermove', ((ptr) ->
			if scrolling
				@vp.scrollX += (ptr.x - scrolling.x) // @vp.zoom
				@vp.scrollY += (ptr.y - scrolling.y) // @vp.zoom
				scroll_lock ptr
			), ui

	update:	() ->
		# GUI render.
		@tinformer.setText "Zoom: #{@vp.zoom}x [PgUp/PgDn] | Speed: #{@speed}% [+/-] |
		#{@powered.either 'P', 'Unp'}owered [Enter]"
		@binformer.setText "Matrix: #{@machine.width}x#{@machine.height} [Copy/Paste/Del]" +
			@powered.either "", " | Cycle: 0x#{@machine.ticks.toString(16)} [Space]"
		# VP render.
		@vp.sync()

	# --Branching goes here.
	@new_branch 'on',
		toggle:	() -> @powered = not @powered;						@
		clear:	() -> @machine.clear();								@
		step:	() -> @machine.tick() unless @powered;				@
		exit:	() -> window.close();								@
		zoomin:	() -> @vp.zoom++ if @vp.zoom < 20;					@
		zoomout:() -> @vp.zoom-- if @vp.zoom > 1;					@
		haste:	() -> @speed += 10 if @speed < 100;					@
		slow:	() -> @speed -= 10 if @speed > 10;					@
		left:	() -> @vp.scrollX++ ;								@
		right:	() -> @vp.scrollX-- ;								@
		up:		() -> @vp.scrollY++ ;								@
		down:	() -> @vp.scrollY-- ;								@
		load:	() -> @loader.click();								@
		save:	() -> 
			console.log new Blob([@machine.ascii], {type: "text/plain;charset=utf-8"})
			saveAs new Blob([@machine.ascii], {type: "text/plain;charset=utf-8"}),
				"[#{@machine.width}x#{@machine.height}] matrix.w=w"
			return @
		import: (e) ->
			e.stopPropagation()
			e.preventDefault()
			e.feed = e.dataTransfer ? e.target
			if feed = e.feed.files[0]
				reader = new FileReader()
				reader.onload = (e) => @machine.ascii = e.target.result
				reader.readAsText feed
			return @
		noop:	() -> @

	# --Properties goes here.
	@getter 'speed', ()			-> @machine.speed
	@setter 'speed', (val)		-> @machine.speed = val
	@getter 'powered',	()		-> @machine.powered
	@setter 'powered',	(val)	-> @machine.powered = val
#.} [Classes]

# ==Main code==
window.ui = new UI