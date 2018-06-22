class Accum
	@MaxAgit_	= MaxAgit_	= 20
	# --Methods goes here:
	constructor: (@x, @y, @host) ->
		@threshold = MaxAgit_ + 2
		@agitation = @new_agitation = 0
		if (@x + @y) % 2 then @color = "cyan" else @color = "gold"
		if Math.abs(@host.width // 2 - @x) + Math.abs(@host.height // 2 - @y) < @host.width * 0.5
			@flag = 1; @threshold -= 1; @alpha = 1#2
		else @alpha = 0.5

	agitate: (strength = 1) ->
		@new_agitation = contain @new_agitation + strength, -MaxAgit_, @threshold

	neighbor: (x_offset, y_offset) ->
		@host.find_cell (contain @x + x_offset, 0, @host.width - 1),
						(contain @y + y_offset, 0, @host.height - 1)

	render: (out) ->
		agit_val		= Math.abs(@agitation)
		sizing			= @host.buffer.width / @host.width
		if @flag then margin = agit_val / MaxAgit_ else margin = (1 - agit_val / MaxAgit_)
		margin			= margin * (@host.buffer.width // @host.width // 2 - 2)
		start_margin	= 1 + margin
		inner_size		= sizing - margin * 2 - 2
		#.Actual render.
		out.fillStyle	= @color
		out.globalAlpha	= (agit_val / MaxAgit_) * @alpha
		out.fillRect(start_margin + @x * sizing, start_margin + @y * sizing, inner_size, inner_size)

	sync: () ->
		@agitation = @new_agitation

	local: contain = (value, min, max) ->
		Math.min(Math.max(value, min), max)

class Field
	InformLine_ = 45
	InformMargin_ = 10
	# --Methods goes here:
	constructor: (@width, @height, @buffer, @viewport) ->
		@matrix = new Array (cell_count = @height * @width)
		for cell in [0...cell_count]
			@matrix[cell] = new Accum cell % @width, cell // @width, @
		@init_signal()

	init_signal: () ->
		@find_cell(0, 0)					.agitate 1
		@find_cell(@width - 1, 0)			.agitate 1
		@find_cell(0, @height - 1)			.agitate 1
		@find_cell(@width - 1, @height - 1)	.agitate 1
		@find_cell(@width // 2, @height // 2).agitate 1

	find_cell: (x, y) ->
		@matrix[x + y * @height]
#############################################
	sync: () ->
		signal = (cell, x_offset, y_offset) ->
			if (target = cell.neighbor(x_offset, y_offset)).agitation <= Accum.MaxAgit_ and target.agitation >= 0
				target.agitate()
		#.Actual syncing loop:
		for cell in @matrix
			if cell.agitation >= Accum.MaxAgit_ 
				signal(cell, 1, 0); signal(cell, -1, 0)
				signal(cell, 0, 1); signal(cell, 0, -1)
				cell.agitate(-Accum.MaxAgit_)
			else if cell.agitation then cell.agitate()
#############################################
	inform_line: (out, text, height) ->
		out.fillStyle = 'rgba(0, 0, 0, 0.75)'
		out.fillRect(0, height, @viewport.width, 45)
		out.font = "bold 33px Constantia";
		out.globalAlpha = 0.75
		out.fillStyle = 'lawngreen'
		out.textAlign = 'center'
		out.fillText(text, @viewport.width / 2, height + 33)

	visualize: () ->
		out = @buffer.getContext '2d'						# Context extraction.
		view_out = @viewport.getContext '2d'				# Additional context extraction.
		out.globalAlpha = 1; out.fillStyle	= "black"		# Preliminary cls setup.
		out.fillRect 0, 0, @buffer.width, @buffer.height	# Clear buffer.
		# .Accum rendering loop.
		for cell in @matrix									# Accum rendering loop.
			cell.sync(); cell.render out 

		#.Tiler emulation.
		view_out.globalAlpha = 1
		view_out.drawImage(@buffer, 0, 0)
		view_out.drawImage(@buffer, @buffer.width, 0)
		view_out.drawImage(@buffer, 0, @buffer.height)
		view_out.drawImage(@buffer, @buffer.width, @buffer.height)
		#...Things
		@inform_line view_out, ":[stagnant flow v0.3]:", 10
		@inform_line view_out, "...Developed by Victoria A. Guevara...", @viewport.height-InformLine_-InformMargin_
		view_out.globalAlpha = 1
		view_out.fillStyle = 'rgba(0, 0, 0, 0.75)'
		view_out.fillRect(InformMargin_, 0, InformLine_, @viewport.height)
		view_out.fillRect(@viewport.width-InformLine_-InformMargin_, 0, InformLine_, @viewport.height)
		#.Actual syncing.
		@viewport.style.webkitTransform = 'scale(1)'

# -Main code goes here:
fld = new Field(51, 51, document.getElementById('buffer'), document.getElementById('viewport'))
setInterval (() => fld.sync(); fld.visualize()), 1000 // 50