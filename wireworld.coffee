# ~>Wireworld core simulation.
#.{ [Classes]
class Cell
	@[name] = idx for name, idx in ['void', 'cond', 'head', 'tail']
	@cycle: (type, shift) -> (type + shift) %% 4
# -------------------- #
class Automata
	# --Methods goes here.
	constructor: (@width = 4, @height = 4, @wrap = false) ->
		if @clear() and @wrap
			@get = (x, y)					-> @cells[y %% @height][x %% @width]
			@set = (x, y, type = Cell.cond)	-> @cells[y %% @height][x %% @width] = type
		else			
			@get = (x, y)					-> @cells[y]?[x]
			@set = (x, y, type = Cell.cond)	-> @cells[y]?[x] = type

	clear: (init = Cell.void) ->
		@cells = Array.from Array(@height), (=> new Uint8Array(@width).fill init)
		@ticks = 0
		return @

	tick: (steps = 1) ->
		while steps-- and ++@ticks
			@cells = for row, y in @cells
				Uint8Array.from (for cell, x in row
					switch cell
						when Cell.head then Cell.tail
						when Cell.tail then Cell.cond
						when Cell.cond # Conductivity
							heads = 0
							for [tx, ty] in [[0, 1], [0, -1], [1, 0], [-1, 0], [1, 1], [1, -1], [-1, 1], [-1, -1]]
								heads++ if @get(x + tx, y + ty) is Cell.head
							if heads in [1, 2] then Cell.head else Cell.cond
						else cell)
		return @
#.} [Classes]

# Some mandatory export.
try [window.Cell, window.Automata] = [Cell, Automata]