--[[--
lodash
@module lodash
]]
local R = require('moses')

local lodash = {}

--[[--
Casts `value` as an array if it's not one.

@tparam any value The value to inspect.
@treturn table Returns the cast array.
@usage

castArray(1)
-- => { 1 }

castArray({ a = 1 })
-- => { { a = 1 } }

castArray('abc')
-- => { 'abc' }

castArray()
-- => {}

local array = {1, 2, 3}
print(castArray(array) == array)
-- => true
]]
function lodash.castArray(...)
	local args = { ... }
	if (#args == 0) then
		return setmetatable({}, { __type = 'slice' })
	end
	local value = args[1]
	if (not R.isArray(value)) then
		return setmetatable({ value }, { __type = 'slice' })
	end
	if (#value == 0) then
		return setmetatable({}, { __type = 'slice' })
	end
	return value
end

--[[--
Clamps `number` within the inclusive `lower` and `upper` bounds.

@tparam number number The number to clamp.
@tparam number lower The lower bound.
@tparam number upper The upper bound.
@treturn number Returns the clamped number.
@usage

clamp(-10, -5, 5)
-- => -5

clamp(10, -5, 5)
-- => 5
]]
function lodash.clamp(number, lower, upper)
	number = tonumber(number)
	lower = tonumber(lower) or 0 / 0
	upper = tonumber(upper) or 0 / 0
	lower = lower == lower and lower or 0
	upper = upper == upper and upper or 0
	if (number == number) then
		number = number <= upper and number or upper
		number = number >= lower and number or lower
	end
	return number
end

--[[--
Checks if `string` ends with the given target string.

@tparam[opt=''] string str The string to inspect.
@tparam string target The string to search for.
@tparam[opt=#str] number position The position to search up to.
@treturn boolean Returns `true` if `string` ends with `target`, else `false`.
@usage

endsWith('abc', 'c')
-- => true

endsWith('abc', 'b')
-- => false

endsWith('abc', 'b', 2)
-- => true
]]
function lodash.endsWith(str, target, position)
	local length = #str
	position = position == nil and length or tonumber(position) or 0 / 0
	if (position < 0 or position ~= position) then
		position = 0
	elseif (position > length) then
		position = length
	end
	local last = position
	position = position - #target
	return position >= 0 and str:sub(position + 1, last) == target
end

--[[--
Converts the characters "&", "<", ">", '"', and "'" in `string` to their
corresponding HTML entities.

Though the ">" character is escaped for symmetry, characters like
">" and "/" don't need escaping in HTML and have no special meaning
unless they're part of a tag or unquoted attribute value. See
[Mathias Bynens's article](https://mathiasbynens.be/notes/ambiguous-ampersands)
(under "semi-related fun fact") for more details.

When working with HTML you should always
[quote attribute values](http://wonko.com/post/html-escaping) to reduce
XSS vectors.

@tparam[opt=''] string str The string to escape.
@treturn string Returns the escaped string.
@usage

escape('fred, barney, & pebbles')
-- => 'fred, barney, &amp pebbles'
]]
function lodash.escape(str)
	local htmlEscapes = {
		['&'] = '&amp;',
		['<'] = '&lt;',
		['>'] = '&gt;',
		['"'] = '&quot;',
		["'"] = '&#39;'
	}
	return str:gsub('[&<>"\']', htmlEscapes)
end

--[[--
Computes `number` rounded to `precision`.

@tparam number number The number to round.
@tparam[opt=0] number precision The precision to round to.
@treturn number Returns the rounded number.
@usage

round(4.006)
// => 4

round(4.006, 2)
// => 4.01
]]
function lodash.round(number, precision)
	number = tonumber(number) or 0 / 0
	if (number ~= number) then
		return number
	end
	precision = tonumber(precision) or 0 / 0
	if (precision ~= precision) then
		precision = 0
	end
	precision = lodash.clamp(math.floor(precision), 0, 99)
	return tonumber(('%.' .. precision .. 'f'):format(number))
end

-- TODO: https://github.com/lodash/lodash/blob/master/split.js
function lodash.split(str, sep)
	sep = sep or ':'
	local fields = {}
	local pattern = ('([^%s]+)'):format(sep)
	str:gsub(pattern, function(c)
		fields[#fields+1] = c
	end)
	return fields
end

--[[--
Checks if `string` starts with the given target string.

@tparam[opt=''] string str The string to inspect.
@tparam string target The string to search for.
@tparam[opt=0] number position The position to search from.
@treturn boolean Returns `true` if `string` starts with `target`, else `false`.
@usage

startsWith('abc', 'a')
-- => true

startsWith('abc', 'b')
-- => false

startsWith('abc', 'b', 1)
-- => true
]]
function lodash.startsWith(str, target, position)
	local length = #str
	position = tonumber(position) or 0
	if (position < 0 or position ~= position) then
		position = 0
	elseif (position > length) then
		position = length
	end
	target = tostring(target)
	return str:sub(position + 1, position + #target) == target
end

--[[--
The inverse of `escape`this method converts the HTML entities `&amp;`, `&lt;`,
`&gt;`, `&quot;` and `&#39;` in `string` to their corresponding characters.

@tparam[opt=''] string str The string to unescape.
@treturn string Returns the unescaped string.
@usage

unescape('fred, barney, &amp; pebbles')
-- => 'fred, barney, & pebbles'
]]
function lodash.unescape(str)
	local htmlUnescapes = {
		['&lt;'] = '<',
		['&gt;'] = '>',
		['&quot;'] = '"',
		['&#39;'] = "'"
	}
	for entity, chr in pairs(htmlUnescapes) do
		str = str:gsub(entity, chr)
	end
	return str:gsub('&amp;', '&')
end

-- TODO: https://github.com/lodash/lodash/blob/master/zipObject.js
--[[--
This method is like `fromPairs` except that it accepts two arrays, one of
property identifiers and one of corresponding values.

@tparam[opt={}] table props The property identifiers.
@tparam[opt={}] table values The property values.
@treturn table Returns the new object.
@usage

zipObject(['a', 'b'], [1, 2])
-- => { 'a': 1, 'b': 2 }
]]
function lodash.zipObject(props, values)
	local obj = {}
	for index, value in ipairs(props) do
		obj[value] = values[index]
	end
	return obj
end

return lodash
