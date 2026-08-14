--!strict

--[[
	@name virtual
	@module lume/layout/virtual

	Windowing math plus chunked realisation. Rows are rendered in blocks
	rather than one instance per row: a 5000-line log becomes a few dozen
	labels, which is the difference between smooth and unusable.
]]

--// public api
local Virtual = {}
Virtual.__index = Virtual

function Virtual.new(options)
	return setmetatable({
		itemHeight = options.itemHeight or 18,
		chunkSize = math.max(1, options.chunkSize or 64),
		buffer = options.buffer or 8,

		count = options.count or 0,
		pinned = true,
		offset = 0,
	}, Virtual)
end

function Virtual.setCount(self, count: number)
	self.count = math.max(0, count)
end

function Virtual.contentHeight(self): number
	return self.count * self.itemHeight
end

function Virtual.setOffset(self, offset: number, height: number)
	local limit = math.max(0, self:contentHeight() - height)

	self.offset = math.clamp(offset, 0, limit)
	self.pinned = self.offset >= limit - 1
end

function Virtual.pin(self, height: number)
	self.pinned = true
	self.offset = math.max(0, self:contentHeight() - height)
end

--// range: inclusive first and last index to realise for a viewport height
function Virtual.range(self, height: number): (number, number)
	if self.count == 0 or height <= 0 then
		return 1, 0
	end

	local top = self.pinned and math.max(0, self:contentHeight() - height) or self.offset

	local first = math.max(1, math.floor(top / self.itemHeight) + 1 - self.buffer)
	local last = math.min(self.count, math.ceil((top + height) / self.itemHeight) + self.buffer)

	return first, last
end

--// chunks: block boundaries covering a range, aligned to chunkSize so the
--// same block keys recur between frames and instances can be reused
function Virtual.chunks(self, first: number, last: number)
	local out = {}

	if last < first then
		return out
	end

	local size = self.chunkSize
	local startBlock = math.floor((first - 1) / size)
	local endBlock = math.floor((last - 1) / size)

	for block = startBlock, endBlock do
		local blockFirst = block * size + 1
		local blockLast = math.min(self.count, blockFirst + size - 1)

		table.insert(out, {
			first = blockFirst,
			last = blockLast,
			key = string.format("Chunk_%05d", block),
		})
	end

	return out
end

function Virtual.offsetOf(self, index: number): number
	return (index - 1) * self.itemHeight
end

return Virtual
