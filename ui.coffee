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
	_ascii_set	= " .@*"
	_key		= "matrix_data"

	# --Methods goes here.
	constructor: (args...) ->
		super ...args
		try	@ascii = @storage
		catch e
			midline = @height // 2 - 1
			@set x, midline for x in [-10..10]
			@set 11, midline + 1
			@set x, midline + 2 for x in [-10..10]
			@set -10, midline, Cell.tail
			@set -11, midline + 1, Cell.head
		setInterval (-> @storage = @ascii), 1000
		setInterval (->	if @powered and Date.now() - @last_update >= 400 - 4 * Math.min @speed, 100
			@tick(Math.ceil @speed / 100)
			).bind(@), 10

	morph: (x, y, shift = 1) ->
		@set x, y, Cell.cycle @get(x, y), shift
		return @

	resize: (width, height, feeder) ->
		reshape = (width, height) =>
			@cells.length = height
			@cells = for row in @cells
				new_row = new Uint8Array(width)
				new_row.set(row[..width-1]) if row
				new_row
		throw new TypeError("invalid matrix data provided") unless height > 1 and width > 1
		feeder = feeder ? reshape(width, height)
		[@width, @height, @ticks, @cells] = [width, height, 0, feeder]
		return @

	render: (bmp, scale = 1) ->
		ptr	= 0
		for row, y in @cells
			for cell, x in row
				c = [0x000022, 0xffff00, 0x00ffff, 0xff0000][cell] 
				bmp[ptr++] = c>>16 & 255; bmp[ptr++] = c>>8 & 255; bmp[ptr++] = c & 255; bmp[ptr++] = 0xff
		localStorage.setItem(_key, @ascii)
		return @

	tick: (args...) ->
		@last_update = Date.now()
		super ...args

	# --Properties goes here.
	@getter 'storage', ()		-> localStorage.getItem(_key)
	@setter 'storage', (val)	-> localStorage.setItem(_key, val)
	@getter 'ascii', ()			-> ((_ascii_set[cell] for cell in row).join '' for row in @cells).join '\n'
	@setter 'ascii', (val)		->
		val = val.replace /\r/g, ''
		unless val.split('').find (char) -> not (char in _ascii_set or char in '\n')
			height	= (val = val.split '\n').length
			width	= val[0]?.length
		@resize width, height, (Uint8Array.from (_ascii_set.indexOf cell for cell in row) for row in val)
# -------------------- #
class ViewPort
	scroll	= {x: 0, y: 0}
	zoom	= 0

	# --Methods goes here.
	constructor: (@scene, @machine) ->
		[@width, @height]	= [@scene.cameras.main.width, @scene.cameras.main.height]
		@output				= @scene.textures.createCanvas 'cvs', @machine.width, @machine.height
		@tiles				= []

	pick: (screen_x, screen_y) ->
		[(screen_x - @tiles[0].x + @tiles[0].displayOriginX * @zoom) // @zoom,
		(screen_y - @tiles[0].y + @tiles[0].displayOriginY * @zoom) // @zoom]

	sync: () ->
		# Primary rendering.
		@output.setSize @machine.width, @machine.height
		bmp = @output.context.getImageData(0, 0, @machine.width, @machine.height)
		@machine.render bmp.data, @zoom
		# Tiling render.
		tiling = (full, part, corrector) =>
			result = Math.max 1, 2 * Math.sign(corrector) + Math.ceil full / part
			if result % 2 then result else result+1
		xfactor = tiling(@width, @machine.width * @zoom, @scrollX) // 2
		yfactor = tiling(@height, @machine.height * @zoom, @scrollY) // 2
		@output.context.putImageData bmp, 0, 0
		@output.refresh()
		# Adjusting projection.
		tile.destroy() for tile in @tiles
		xstep = @zoom * @machine.width
		ystep = @zoom * @machine.height
		@tiles = []
		for y in [-yfactor..yfactor]
			for x in [-xfactor..xfactor]
				@tiles.push tile = (@scene.add.image @width / 2 + x * xstep + @scrollX * @zoom,
				@height / 2 + y * ystep + @scrollY * @zoom, 'cvs').setScale(@zoom)
				tile.depth = -1

	# --Properties goes here.
	@getter 'zoom',	()			-> zoom
	@setter 'zoom',	(val)		-> zoom = val
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
			title: "Wire=world celluar automata.", version: "0.02"
		@machine = new VisualAutomata @app.canvas.width // init_scale, @app.canvas.height // init_scale, true
		# Error handlers setup.
		window.onerror = (msg, url, ln, col, e) ->
			console.error e
			alert "#{e.toString()} !\nLine №#{ln}[#{col}], #{new URL(url).pathname}"
			return true

	create:	() ->
		# External UI setup.
		@vp			= new ViewPort(@scene, @machine)
		@vp.zoom	= init_scale
		@loader		= document.getElementById('loader')
		@loader.addEventListener 'change', @on.import
		@meters		= {}
		# Experiment.
		for metrics in ['width', 'height']
			@meters[metrics] = document.getElementById metrics
			@meters[metrics].addEventListener 'change', @on.resize
		@meters[metrics].value = @machine[metrics] for metrics in ["width", "height"]
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
		document.addEventListener 'dragover', (e) => e.preventDefault(); e.dataTransfer.dropEffect = 'none'
		document.addEventListener 'drop', (e) => e.preventDefault()
		@app.canvas.addEventListener 'dragover', (e) =>
			e.stopPropagation(); e.preventDefault(); e.dataTransfer.dropEffect = 'copy'
		@app.canvas.addEventListener 'drop', @on.import
		# Keyboard inputs.
		@scene.input.keyboard.on "keydown_#{key}", @on[proc] for key, proc of {
			ENTER:'toggle', DELETE:'clear', SPACE:'step',	ESC: 'exit',	PAGE_UP:'zoomin', PAGE_DOWN:'zoomout',
			PLUS:'haste',	MINUS:'slow',	LEFT:'left',	RIGHT:'right',	UP:'up', DOWN:'down'
		}
		document.addEventListener "keydown", (event) =>
			if event.ctrlKey then switch event.which
				when 83 then @on.save(); event.preventDefault(); return false
				when 76 then @on.load(); event.preventDefault(); return false
		# Clipboard inputs.
		document.addEventListener 'paste', (e) => @machine.ascii = e.clipboardData.getData 'Text'
		document.addEventListener 'copy', (e) =>
			e.clipboardData.setData('text/plain', @machine.ascii)
			e.preventDefault()
		# Mouse inputs.
		scroll_lock = (feed) -> scrolling = if feed then {x: feed.x, y: feed.y} else false
		@app.canvas.addEventListener "wheel", (e) => @on[['zoomin', 'noop', 'zoomout'][1 + Math.sign e.deltaY]]()
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
		# Internal GUI render.
		@tinformer.setText "Zoom: #{@vp.zoom}x [PgUp/PgDn] | Speed: #{@speed}% [+/-] |
		#{@powered.either 'P', 'Unp'}owered [Enter] / SX: #{@vp.scrollX}"
		@binformer.setText "Matrix: #{@machine.width}x#{@machine.height} [Copy/Paste/Del] " +
			@powered.either "#{['|', '/', '-', '\\'][(@machine.ticks // Math.ceil @speed / 100).wrap 4]}",
			"| Cycle: 0x#{@machine.ticks.toString(16)} [Space]"
		# VP render.
		@vp.sync()

	# --Branching goes here.
	@new_branch 'on',
		toggle:	() -> @powered = not @powered;										@
		clear:	() -> @machine.clear();												@
		step:	() -> @machine.tick() unless @powered;								@
		exit:	() -> window.close();												@
		zoomin:	() -> @vp.zoom++ if @vp.zoom < 20;									@
		zoomout:() -> @vp.zoom-- if @vp.zoom > 1;									@
		haste:	() -> @speed += (@speed >= 100).either(100, 10) if @speed < 500;	@
		slow:	() -> @speed -= (@speed >= 200).either(100, 10) if @speed > 10;		@
		resize:	() -> @machine.resize @meters.width.value, @meters.height.value;	@ # REMOVE ME LATER !
		left:	() -> @vp.scrollX++ ;												@
		right:	() -> @vp.scrollX-- ;												@
		up:		() -> @vp.scrollY++ ;												@
		down:	() -> @vp.scrollY-- ;												@
		load:	() -> @loader.click();												@
		save:	() -> 
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