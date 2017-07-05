--[[--
object
@module object
]]
local Object = {}

Object.meta = { __index = Object }

function Object.instanceof(obj, class)
	if type(obj) ~= 'table' or obj.meta == nil or not class then
		return false
	end
	if obj.meta.__index == class then
		return true
	end
	local meta = obj.meta
	while meta do
		if meta.super == class then
			return true
		elseif meta.super == nil then
			return false
		end
		meta = meta.super.meta
	end
	return false
end

function Object:create()
	local meta = rawget(self, 'meta')
	if not meta then
		error('Cannot inherit from instance object')
	end
	return setmetatable({}, meta)
end

function Object:extend()
	local obj = self:create()
	local meta = {}
	for k, v in pairs(self.meta) do
		meta[k] = v
	end
	meta.__index = obj
	meta.super = self
	obj.meta = meta
	return obj
end

function Object:new(...)
	local obj = self:create()
	if type(obj.initialize) == 'function' then
		obj:initialize(...)
	end
	return obj
end

return Object
