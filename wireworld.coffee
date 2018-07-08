# ~>Wireworld core simulation.
# ==Extnesion methods==
Number::wrap = (max) -> (@ % max + max) % max

#.{ [Classes]
class Cell
	@[name] = idx for name, idx in ['void', 'cond', 'head', 'tail']
	@cycle: (type, shift) -> (type + shift).wrap 4
# -------------------- #
class Matrix2D
	constructor: (@width, @height, @wrap = false, @kind = Array) ->
		if @clear() and @wrap		
			@get = (x, y)					-> @cells[y.wrap(@height) * @width + x.wrap @width]
			@set = (x, y, type = Cell.cond)	-> @cells[y.wrap(@height) * @width + x.wrap @width] = type
		else			
			@get = (x, y)					-> @cells[y * @width + x] if x in [0...@width] and y in [0...@height]
			@set = (x, y, type = Cell.cond)	-> (@cells[y * @width + x]=type) if x in [0...@width] and y in [0...@height]

	clear: (init = 0) ->
		@cells = new @kind(@width * @height).fill init
		return @

	get_row: (idx) ->
		return @cells[idx*@width...(idx+1)*@width]

	reshape: (width, height) ->
		cache = []
		console.log @cells
		for idx in [0...height]
			row = (if idx < @height then Array.from @get_row idx else new Array(@width).fill 0)
			row.length = width
			cache = cache.concat(row.fill 0, @width)
		[@width, @height, @cells] =	[width, height, @kind.from cache]
		return @
# -------------------- #
class Automata extends Matrix2D
	# --Methods goes here.
	constructor: (width = 4, height = 4, wrap = false) ->
		super width, height, wrap, Uint8Array

	clear: (args...) ->
		@ticks = 0
		return super args...

	tick: (steps = 1) ->
		while steps-- and ++@ticks
			@cells = Uint8Array.from (for cell, idx in @cells
				switch cell
					when Cell.head then Cell.tail
					when Cell.tail then Cell.cond
					when Cell.cond # Conductivity
						heads = 0; x = idx % @width; y = idx // @width
						for offset in [[0, 1], [0, -1], [1, 0], [-1, 0], [1, 1], [1, -1], [-1, 1], [-1, -1]]
							heads++ if @get(x + offset[0], y + offset[1]) is Cell.head
						if heads in [1, 2] then Cell.head else Cell.cond
					else cell)
		return @
#.} [Classes]

# Some mandatory export.
try [window.Cell, window.Automata] = [Cell, Automata]