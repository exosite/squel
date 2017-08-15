--[[--
squel
@module squel
]]
local L = require('lodash') or require('src.lodash')
local R = require('moses') or require('src.moses')
local Object = require('object') or require('src.object')

-- append to string if non-empty
local function _pad(str, pad)
	return #str > 0 and str .. pad or str
end

-- Extend given object's with other objects' properties, overriding existing ones if necessary
local function _extend(dst, ...)
	local srcs = { ... }
	if (dst and #srcs > 0) then
		for _, src in pairs(srcs) do
			if (type(src) == 'table') then
				for key, val in pairs(src) do
					dst[key] = val
				end
			end
		end
	end

	return dst
end

-- get whether object is a plain object
local function _isPlainObject(obj)
	return not getmetatable(obj)
end

-- clone given item
local function _clone(src)
	if (type(src) == 'table') then
		if (src.meta and src.meta.super == Object) then
			return src
		end
		if (type(src.clone) == 'function') then
			return src:clone()
		end
		local ret = {}
		for key, val in pairs(src) do
			if (type(val) ~= 'function') then
				ret[key] = _clone(val)
			end
		end
		return ret
	else
		return src
	end
end

--[[
 * Register a value type handler
 *
 * Note: this will override any existing handler registered for this value type.
 ]]
local function registerValueHandler(handlers, typeName, handler)
	local typeofType = type(typeName)

	if (typeofType ~= 'table' and typeofType ~= 'string') then
		error('type must be a class constructor or string')
	end

	if (type(handler) ~= 'function') then
		error('handler must be a function')
	end

	for _, typeHandler in ipairs(handlers) do
		if (typeHandler.type == typeName) then
			typeHandler.handler = handler

			return
		end
	end

	table.insert(handlers, {
		type = typeName,
		handler = handler,
	})
end

--[[
 * Get value type handler for given type
 ]]
local function getValueHandler(value, ...)
	local handlerLists = { ... }
	for _, handlers in ipairs(handlerLists) do
		for _, typeHandler in ipairs(handlers) do
			-- if type is a string then use `typeof` or else use `instanceof`
			if (type(value) == typeHandler.type or
					(type(typeHandler.type) ~= 'string' and Object.instanceof(value, typeHandler.type))) then
				return typeHandler.handler
			end
		end
	end
end

--[[
 * Build base squel classes and methods
 ]]
local function _buildSquel(flavour)
	local cls = {
		_isSquelBuilder = function(obj)
			return type(obj) == 'table' and not not obj._toParamString
		end
	}

	-- default query builder options
	cls.DefaultQueryBuilderOptions = {
		-- If true then table names will be rendered inside quotes.
		-- The quote character used is configurable via the nameQuoteCharacter option.
		autoQuoteTableNames = false,
		-- If true then field names will rendered inside quotes.
		-- The quote character used is configurable via the nameQuoteCharacter option.
		autoQuoteFieldNames = false,
		-- If true then alias names will rendered inside quotes.
		-- The quote character used is configurable via the `tableAliasQuoteCharacter` and `fieldAliasQuoteCharacter` options.
		autoQuoteAliasNames = true,
		-- If true then table alias names will rendered after AS keyword.
		useAsForTableAliasNames = false,
		-- The quote character used for when quoting table and field names
		nameQuoteCharacter = '`',
		-- The quote character used for when quoting table alias names
		tableAliasQuoteCharacter = '`',
		-- The quote character used for when quoting table alias names
		fieldAliasQuoteCharacter = '"',
		-- Custom value handlers where key is the value type and the value is the handler function
		valueHandlers = {},
		-- Character used to represent a parameter value
		parameterCharacter = '?',
		-- Numbered parameters returned from toParam() as $1, $2, etc.
		numberedParameters = false,
		-- Numbered parameters prefix character(s)
		numberedParametersPrefix = '$',
		-- Numbered parameters start at this number.
		numberedParametersStartAt = 1,
		-- If true then replaces all single quotes within strings.
		-- The replacement string used is configurable via the `singleQuoteReplacement` option.
		replaceSingleQuotes = false,
		-- The string to replace single quotes with in query strings
		singleQuoteReplacement = "''",
		-- String used to join individual blocks in a query when it's stringified
		separator = ' ',
		-- Function for formatting string values prior to insertion into query string
		stringFormatter = nil,
	}

	-- Global custom value handlers for all instances of builder
	cls.globalValueHandlers = {}

	--[[
	# ---------------------------------------------------------------------------------------------------------
	# ---------------------------------------------------------------------------------------------------------
	# Custom value types
	# ---------------------------------------------------------------------------------------------------------
	# ---------------------------------------------------------------------------------------------------------
	 ]]

	-- Register a new value handler
	cls.registerValueHandler = function(typeName, handler)
		registerValueHandler(cls.globalValueHandlers, typeName, handler)
	end

	--[[
	# ---------------------------------------------------------------------------------------------------------
	# ---------------------------------------------------------------------------------------------------------
	# Base classes
	# ---------------------------------------------------------------------------------------------------------
	# ---------------------------------------------------------------------------------------------------------
	]]

	-- Base class for cloneable builders
	cls.Cloneable = Object:extend()
		function cls.Cloneable.initialize()
		end

		--[[
		 * Clone this builder
		 ]]
		function cls.Cloneable:clone()
			local newInstance = self.meta.__index:new()

			return _extend(newInstance, _clone(_extend({}, self)))
		end

	-- Base class for all builders
	cls.BaseBuilder = cls.Cloneable:extend()
		--[[
		 * Constructor.
		 * self.param  {Object} options Overriding one or more of `cls.DefaultQueryBuilderOptions`.
		 ]]
		function cls.BaseBuilder:initialize(options)
			cls.Cloneable.initialize(self)

			self.options = _extend({}, cls.DefaultQueryBuilderOptions, options)
		end

		--[[
		 * Register a custom value handler for this builder instance.
		 *
		 * Note: this will override any globally registered handler for this value type.
		 ]]
		function cls.BaseBuilder:registerValueHandler(typeName, handler)
			registerValueHandler(self.options.valueHandlers, typeName, handler)

			return self
		end

		--[[
		 * Sanitize given expression.
		 ]]
		function cls.BaseBuilder._sanitizeExpression(_, expr)
			-- If it's not a base builder instance
			if (not (cls._isSquelBuilder(expr))) then
				-- It must then be a string
				if (type(expr) ~= 'string') then
					error('expression must be a string or builder instance')
				end
			end

			return expr
		end

		--[[
		 * Sanitize the given name.
		 *
		 * The 'type' parameter is used to construct a meaningful error message in case validation fails.
		 ]]
		function cls.BaseBuilder._sanitizeName(_, value, typeName)
			if (type(value) ~= 'string') then
				error(('%s must be a string'):format(tostring(typeName)))
			end

			return value
		end

		function cls.BaseBuilder:_sanitizeField(item)
			if (not (cls._isSquelBuilder(item))) then
				item = self:_sanitizeName(item, 'field name')
			end

			return item
		end

		function cls.BaseBuilder._sanitizeBaseBuilder(_, item)
			if (cls._isSquelBuilder(item)) then
				return item
			end

			error('must be a builder instance')
		end

		function cls.BaseBuilder:_sanitizeTable(item)
			if (type(item) ~= 'string') then
				local ok
				ok, item = pcall(self._sanitizeBaseBuilder, self, item)
				if (not ok) then
					error('table name must be a string or a builder')
				end
			else
				item = self:_sanitizeName(item, 'table')
			end

			return item
		end

		function cls.BaseBuilder:_sanitizeTableAlias(item)
			return self:_sanitizeName(item, 'table alias')
		end

		function cls.BaseBuilder:_sanitizeFieldAlias(item)
			return self:_sanitizeName(item, 'field alias')
		end

		-- Sanitize the given limit/offset value.
		function cls.BaseBuilder._sanitizeLimitOffset(_, value)
			value = tonumber(value)

			if (value == nil or 0 > value or value ~= value) then
				error('limit/offset must be >= 0')
			end

			return math.floor(value)
		end

		-- Santize the given field value
		function cls.BaseBuilder:_sanitizeValue(item)
			local itemType = type(item)

			if (nil == item) then
				-- nil is allowed
				return item
			elseif ('string' == itemType or 'number' == itemType or 'boolean' == itemType) then
				-- primitives are allowed
				return item
			elseif (cls._isSquelBuilder(item)) then
				-- Builders allowed
				return item
			else
				local typeIsValid = (
					not not getValueHandler(item, self.options.valueHandlers, cls.globalValueHandlers))

				if (not typeIsValid) then
					error('field value must be a string, number, boolean, nil or one of the registered custom value types')
				end
			end

			return item
		end

		-- Escape a string value, e.g. escape quotes and other characters within it.
		function cls.BaseBuilder:_escapeValue(value)
			return (not self.options.replaceSingleQuotes) and value or (
				value:gsub("'", self.options.singleQuoteReplacement)
			)
		end

		function cls.BaseBuilder:_formatTableName(item)
			if (self.options.autoQuoteTableNames) then
				local quoteChar = self.options.nameQuoteCharacter

				item = ('%s%s%s'):format(quoteChar, item, quoteChar)
			end

			return item
		end

		function cls.BaseBuilder:_formatFieldAlias(item)
			if (self.options.autoQuoteAliasNames) then
				local quoteChar = self.options.fieldAliasQuoteCharacter

				item = ('%s%s%s'):format(quoteChar, item, quoteChar)
			end

			return item
		end

		function cls.BaseBuilder:_formatTableAlias(item)
			if (self.options.autoQuoteAliasNames) then
				local quoteChar = self.options.tableAliasQuoteCharacter

				item = ('%s%s%s'):format(quoteChar, item, quoteChar)
			end

			return (self.options.useAsForTableAliasNames)
				and ('AS %s'):format(item)
				or item
		end

		function cls.BaseBuilder:_formatFieldName(item, formattingOptions)
			formattingOptions = formattingOptions or {}
			if (self.options.autoQuoteFieldNames) then
				local quoteChar = self.options.nameQuoteCharacter

				if (formattingOptions.ignorePeriodsForFieldNameQuotes) then
					-- a.b.c -> `a.b.c`
					item = ('%s%s%s'):format(quoteChar, item, quoteChar)
				else
					-- a.b.c -> `a`.`b`.`c`
					item = R(L.split(item, '.'))
						:map(function(_, v)
							-- treat '*' as special case (#79)
							return ('*' == v and v or ('%s%s%s'):format(quoteChar, v, quoteChar))
						end)
						:join('.')
						:value()
				end
			end

			return item
		end

		-- Format the given custom value
		function cls.BaseBuilder:_formatCustomValue(value, asParam, formattingOptions)
			-- user defined custom handlers takes precedence
			local customHandler =
				getValueHandler(value, self.options.valueHandlers, cls.globalValueHandlers)

			-- use the custom handler if available
			if (customHandler) then
				value = customHandler(value, asParam, formattingOptions)
			end

			return {
				formatted = not not customHandler,
				value = value,
			}
		end

		--[[
		 * Format given value for inclusion into parameter values array.
		 ]]
		function cls.BaseBuilder:_formatValueForParamArray(value, formattingOptions)
			formattingOptions = formattingOptions or {}
			if (_isPlainObject(value) and R.isArray(value)) then
				return R.map(value, function(_, v)
					return self:_formatValueForParamArray(v, formattingOptions)
				end)
			else
				return self:_formatCustomValue(value, true, formattingOptions).value
			end
		end

		--[[
		 * Format the given field value for inclusion into the query string
		 ]]
		function cls.BaseBuilder:_formatValueForQueryString(initialValue, formattingOptions)
			formattingOptions = formattingOptions or {}
			local _formatCustomValue = self:_formatCustomValue(initialValue, false, formattingOptions)
			local formatted, value = _formatCustomValue.formatted, _formatCustomValue.value

			-- if formatting took place then return it directly
			if (formatted) then
				return self:_applyNestingFormatting(value)
			end

			-- if it's an array then format each element separately
			if (R.isArray(value)) then
				value = R(value)
					:map(function(_, v)
						return self:_formatValueForQueryString(v)
					end)
					:join(', ')
					:value()

				value = self:_applyNestingFormatting(value)
			else
				local typeofValue = type(value)

				if (value == nil or value == 'NULL') then
					value = 'NULL'
				elseif (typeofValue == 'boolean') then
					value = value and 'TRUE' or 'FALSE'
				elseif (cls._isSquelBuilder(value)) then
					value = self:_applyNestingFormatting(value:toString())
				elseif (typeofValue ~= 'number') then
					-- if it's a string and we have custom string formatting turned on then use that
					if ('string' == typeofValue and self.options.stringFormatter) then
						return self.options.stringFormatter(value)
					end

					if (formattingOptions.dontQuote) then
						value = ('%s'):format(value)
					else
						local escapedValue = self:_escapeValue(value)

						value = ("'%s'"):format(escapedValue)
					end
				end
			end

			return value
		end

		function cls.BaseBuilder._applyNestingFormatting(_, str, nesting)
			if (nesting == nil) then
				nesting = true
			end
			if (str and type(str) == 'string' and nesting) then
				-- apply brackets if they're not already existing
				local alreadyHasBrackets = ('(' == str:sub(1, 1) and ')' == str:sub(-1, -1))

				if (alreadyHasBrackets) then
					-- check that it's the form '((x)..(y))' rather than '(x)..(y)'
					local index, open = 1, 1

					while (#str - 1 >= index + 1) do
						index = index + 1
						local c = str:sub(index, index)

						if ('(' == c) then
							open = open + 1
						elseif (')' == c) then
							open = open - 1
							if (1 > open) then
								alreadyHasBrackets = false

								break
							end
						end
					end
				end

				if (not alreadyHasBrackets) then
					str = ('(%s)'):format(str)
				end
			end

			return str
		end

		--[[
		 * Build given string and its corresponding parameter values into
		 * output.
		 *
		 * @param {String} str
		 * @param {Array}  values
		 * @param {Object} [options] Additional options.
		 * @param {Boolean} [options.buildParameterized] Whether to build paramterized string. Default is false.
		 * @param {Boolean} [options.nested] Whether this expression is nested within another.
		 * @param {Boolean} [options.formattingOptions] Formatting options for values in query string.
		 * @return {Object}
		 ]]
		function cls.BaseBuilder:_buildString(str, values, options)
			options = options or {}
			local nested, buildParameterized, formattingOptions =
				options.nested, options.buildParameterized, options.formattingOptions

			values = values or {}
			str = str or ''

			local formattedStr, curValue, formattedValues = '', 0, {}

			local paramChar = self.options.parameterCharacter

			local index = 1

			while (#str >= index) do
				-- param char?
				if (str:sub(index, index + #paramChar - 1) == paramChar) then
					curValue = curValue + 1
					local value = values[curValue]

					if (buildParameterized) then
						if (cls._isSquelBuilder(value)) then
							local ret = value:_toParamString({
								buildParameterized = buildParameterized,
								nested = true,
							})

							formattedStr = formattedStr .. ret.text
							R.push(formattedValues, unpack(ret.values))
						else
							value = self:_formatValueForParamArray(value, formattingOptions)

							if (R.isArray(value)) then
								-- Array(6) -> '(??, ??, ??, ??, ??, ??)'
								local tmpStr = R(value)
									:map(function()
										return paramChar
									end)
									:join(', ')
									:value()

								formattedStr = ('%s(%s)'):format(formattedStr, tmpStr)

								R.push(formattedValues, unpack(value))
							else
								formattedStr = formattedStr .. paramChar

								table.insert(formattedValues, value)
							end
						end
					else
						formattedStr = formattedStr ..
							self:_formatValueForQueryString(value, formattingOptions)
					end

					index = index + #paramChar
				else
					formattedStr = formattedStr .. str:sub(index, index)

					index = index + 1
				end
			end

			return {
				text = self:_applyNestingFormatting(formattedStr, not not nested),
				values = formattedValues,
			}
		end

		--[[
		 * Build all given strings and their corresponding parameter values into
		 * output.
		 *
		 * @param {Array} strings
		 * @param {Array}  strValues array of value arrays corresponding to each string.
		 * @param {Object} [options] Additional options.
		 * @param {Boolean} [options.buildParameterized] Whether to build paramterized string. Default is false.
		 * @param {Boolean} [options.nested] Whether this expression is nested within another.
		 * @return {Object}
		 ]]
		function cls.BaseBuilder:_buildManyStrings(strings, strValues, options)
			options = options or {}
			local totalStr, totalValues = {}, {}

			for index, inputString in ipairs(strings) do
				local inputValues = strValues[index]

				local _buildString = self:_buildString(inputString, inputValues, {
					buildParameterized = options.buildParameterized,
					nested = false,
				})
				local text, values = _buildString.text, _buildString.values

				table.insert(totalStr, text)
				R.push(totalValues, unpack(values))
			end

			totalStr = table.concat(totalStr, self.options.separator)

			return {
				text = #totalStr > 0
					and self:_applyNestingFormatting(totalStr, not not options.nested)
					or '',
				values = totalValues,
			}
		end

		--[[
		 * Get parameterized representation of this instance.
		 *
		 * @param {Object} [options] Options.
		 * @param {Boolean} [options.buildParameterized] Whether to build paramterized string. Default is false.
		 * @param {Boolean} [options.nested] Whether this expression is nested within another.
		 * @return {Object}
		 ]]
		function cls.BaseBuilder._toParamString()
			error('Not yet implemented')
		end

		--[[
		 * Get the expression string.
		 * @return {String}
		 ]]
		function cls.BaseBuilder:toString(options)
			options = options or {}
			return self:_toParamString(options).text
		end

		--[[
		 * Get the parameterized expression string.
		 * @return {Object}
		 ]]
		function cls.BaseBuilder:toParam(options)
			options = options or {}
			return self:_toParamString(_extend({}, options, {
				buildParameterized = true,
			}))
		end

	--[[
	# ---------------------------------------------------------------------------------------------------------
	# ---------------------------------------------------------------------------------------------------------
	# cls.Expressions
	# ---------------------------------------------------------------------------------------------------------
	# ---------------------------------------------------------------------------------------------------------
	]]

	--[[
	 * An SQL expression builder.
	 *
	 * SQL expressions are used in WHERE and ON clauses to filter data by various criteria.
	 *
	 * Expressions can be nested. Nested expression contains can themselves
	 * contain nested expressions. When rendered a nested expression will be
	 * fully contained within brackets.
	 *
	 * All the build methods in this object return the object instance for chained method calling purposes.
	 ]]
	cls.Expression = cls.BaseBuilder:extend()
		-- Initialise the expression.
		function cls.Expression:initialize(options)
			cls.BaseBuilder.initialize(self, options)

			self._nodes = {}
		end

		-- Combine the current expression with the given expression using the intersection operator (AND).
		function cls.Expression:AND(expr, ...)
			local params = { ... }
			expr = self:_sanitizeExpression(expr)

			table.insert(self._nodes, {
				type = 'AND',
				expr = expr,
				para = params,
			})

			return self
		end

		-- Combine the current expression with the given expression using the union operator (OR).
		function cls.Expression:OR(expr, ...)
			local params = { ... }
			expr = self:_sanitizeExpression(expr)

			table.insert(self._nodes, {
				type = 'OR',
				expr = expr,
				para = params,
			})

			return self
		end

		function cls.Expression:_toParamString(options)
			options = options or {}
			local totalStr, totalValues = {}, {}

			for _, _node in ipairs(self._nodes) do
				local typeName, expr,  para = _node.type, _node.expr, _node.para

				local _toParamString = (cls._isSquelBuilder(expr))
					and expr:_toParamString({
							buildParameterized = options.buildParameterized,
							nested = true,
						})
					or self:_buildString(expr, para, {
							buildParameterized = options.buildParameterized,
						})
				local text, values = _toParamString.text, _toParamString.values

				if (#totalStr > 0) then
					table.insert(totalStr, typeName)
				end

				table.insert(totalStr, text)
				R.push(totalValues, unpack(values))
			end

			totalStr = table.concat(totalStr, ' ')

			return {
				text = self:_applyNestingFormatting(totalStr, not not options.nested),
				values = totalValues,
			}
		end

	--[[
	# ---------------------------------------------------------------------------------------------------------
	# ---------------------------------------------------------------------------------------------------------
	# cls.Case
	# ---------------------------------------------------------------------------------------------------------
	# ---------------------------------------------------------------------------------------------------------
	]]

	--[[
	 * An SQL CASE expression builder.
	 *
	 * SQL cases are used to select proper values based on specific criteria.
	 ]]
	cls.Case = cls.BaseBuilder:extend()
		function cls.Case:initialize(fieldName, options)
			options = options or {}
			cls.BaseBuilder.initialize(self, options)

			if (_isPlainObject(fieldName)) then
				options = fieldName

				fieldName = nil
			end

			if (fieldName) then
				self._fieldName = self:_sanitizeField( fieldName )
			end

			self.options = _extend({}, cls.DefaultQueryBuilderOptions, options)

			self._cases = {}
			self._elseValue = nil
		end

		function cls.Case:WHEN(expression, ...)
			local values = { ... }
			R.addTop(self._cases, {
				expression = expression,
				values = values,
			})

			return self
		end

		function cls.Case:THEN(result)
			if (#self._cases == 0) then
				error('WHEN() needs to be called first')
			end

			self._cases[1].result = result

			return self
		end

		function cls.Case:ELSE(elseValue)
			self._elseValue = elseValue

			return self
		end

		function cls.Case:_toParamString(options)
			options = options or {}
			local totalStr, totalValues = '', {}

			for _, _case in ipairs(self._cases) do
				local expression, values, result = _case.expression, _case.values, _case.result
				totalStr = _pad(totalStr, ' ')

				local ret = self:_buildString(expression, values, {
					buildParameterized = options.buildParameterized,
					nested = true,
				})

				totalStr = totalStr .. ('WHEN %s THEN %s'):format(ret.text, self:_formatValueForQueryString(result))
				R.push(totalValues, unpack(ret.values))
			end

			if (#totalStr > 0) then
				totalStr = totalStr .. (' ELSE %s END'):format(self:_formatValueForQueryString(self._elseValue))

				if (self._fieldName) then
					totalStr = ('%s %s'):format(self._fieldName, totalStr)
				end

				totalStr = ('CASE %s'):format(totalStr)
			else
				totalStr = self:_formatValueForQueryString(self._elseValue)
			end

			return {
				text = totalStr,
				values = totalValues,
			}
		end

	--[[
	# ---------------------------------------------------------------------------------------------------------
	# ---------------------------------------------------------------------------------------------------------
	# Building blocks
	# ---------------------------------------------------------------------------------------------------------
	# ---------------------------------------------------------------------------------------------------------
	]]

	--[[
	# A building block represents a single build-step within a query building process.
	#
	# Query builders consist of one or more building blocks which get run in a particular order. Building blocks can
	# optionally specify methods to expose through the query builder interface. They can access all the input data for
	# the query builder and manipulate it as necessary, as well as append to the final query string output.
	#
	# If you wish to customize how queries get built or add proprietary query phrases and content then it is recommended
	# that you do so using one or more custom building blocks.
	#
	# Original idea posted in https://github.com/hiddentao/export/issues/10#issuecomment-15016427
	]]
	cls.Block = cls.BaseBuilder:extend()
		function cls.Block:initialize(options)
			cls.BaseBuilder.initialize(self, options)
		end

		--[[
		# Get input methods to expose within the query builder.
		#
		# By default all methods except the following get returned:
		#   methods prefixed with _
		#   constructor and toString()
		#
		# @return Object key -> function pairs
		]]
		function cls.Block:exposedMethods()
			local ret = {}

			local obj = self

			while (obj ~= Object) do
				for key, val in pairs(obj) do
					if (key ~= 'initialize' and type(val) == 'function' and
						key:sub(1, 1) ~= '_' and not cls.Block[key]) then
						ret[key] = val
					end
				end

				obj = getmetatable(obj).__index
			end

			return ret
		end

	-- A fixed string which always gets output
	cls.StringBlock = cls.Block:extend()
		function cls.StringBlock:initialize(options, str)
			cls.Block.initialize(self, options)

			self._str = str
		end

		function cls.StringBlock:_toParamString()
			return {
				text = self._str,
				values = {},
			}
		end

	-- A function string block
	cls.FunctionBlock = cls.Block:extend()
		function cls.FunctionBlock:initialize(options)
			cls.Block.initialize(self, options)

			self._strings = {}
			self._values = {}
		end

		function cls.FunctionBlock:FUNCTION(str, ...)
			local values = { ... }
			table.insert(self._strings, str)
			table.insert(self._values, values)
		end

		function cls.FunctionBlock:_toParamString(options)
			options = options or {}
			return self:_buildManyStrings(self._strings, self._values, options)
		end

	-- value handler for FunctionValueBlock objects
	cls.registerValueHandler(cls.FunctionBlock, function(value, asParam)
		if (asParam == nil) then
			asParam = false
		end
		return asParam and value:toParam() or value:toString()
	end)

	--[[
	# Table specifier base class
	]]
	cls.AbstractTableBlock = cls.Block:extend()
		--[[
		 * @param {Boolean} [options.singleTable] If true then only allow one table spec.
		 * @param {String} [options.prefix] String prefix for output.
		 ]]
		function cls.AbstractTableBlock:initialize(options)
			cls.Block.initialize(self, options)

			self._tables = {}
		end

		--[[
		# Update given table.
		#
		# An alias may also be specified for the table.
		#
		# Concrete subclasses should provide a method which calls this
		]]
		function cls.AbstractTableBlock:_table(tableName, alias)
			alias = alias and self:_sanitizeTableAlias(alias) or alias
			tableName = self:_sanitizeTable(tableName)

			if (self.options.singleTable) then
				self._tables = {}
			end

			table.insert(self._tables, {
				table = tableName,
				alias = alias,
			})
		end

		-- get whether a table has been set
		function cls.AbstractTableBlock:_hasTable()
			return 0 < #self._tables
		end

		--[[
		 * @override
		 ]]
		function cls.AbstractTableBlock:_toParamString(options)
			options = options or {}
			local totalStr, totalValues = '', {}

			if (self:_hasTable()) then
				-- retrieve the parameterised queries
				for _, _table in ipairs(self._tables) do
					local tableName, alias = _table.table, _table.alias
					totalStr = _pad(totalStr, ', ')

					local tableStr

					if (cls._isSquelBuilder(tableName)) then
						local _toParamString = tableName:_toParamString({
							buildParameterized = options.buildParameterized,
							nested = true,
						})
						local text, values = _toParamString.text, _toParamString.values

						tableStr = text
						R.push(totalValues, unpack(values))
					else
						tableStr = self:_formatTableName(tableName)
					end

					if (alias) then
						tableStr = tableStr .. (' %s'):format(self:_formatTableAlias(alias))
					end

					totalStr = totalStr .. tableStr
				end

				if (self.options.prefix) then
					totalStr = ('%s %s'):format(self.options.prefix, totalStr)
				end
			end

			return {
				text = totalStr,
				values = totalValues,
			}
		end

	-- target table for DELETE queries, DELETE <??> FROM
	cls.TargetTableBlock = cls.AbstractTableBlock:extend()
		function cls.TargetTableBlock:target(tableName)
			self:_table(tableName)
		end

	-- Update Table
	cls.UpdateTableBlock = cls.AbstractTableBlock:extend()
		function cls.UpdateTableBlock:table(tableName, alias)
			self:_table(tableName, alias)
		end

		function cls.UpdateTableBlock:_toParamString(options)
			options = options or {}
			if (not self:_hasTable()) then
				error('table() needs to be called')
			end

			return cls.AbstractTableBlock._toParamString(self, options)
		end

	-- FROM table
	cls.FromTableBlock = cls.AbstractTableBlock:extend()
		function cls.FromTableBlock:initialize(options)
			cls.AbstractTableBlock.initialize(self, _extend({}, options, {
				prefix = 'FROM',
			}))
		end

		function cls.FromTableBlock:from(tableName, alias)
			self:_table(tableName, alias)
		end

	-- INTO table
	cls.IntoTableBlock = cls.AbstractTableBlock:extend()
		function cls.IntoTableBlock:initialize(options)
			cls.AbstractTableBlock.initialize(self, _extend({}, options, {
				prefix = 'INTO',
				singleTable = true,
			}))
		end

		function cls.IntoTableBlock:into(tableName)
			self:_table(tableName)
		end

		function cls.IntoTableBlock:_toParamString(options)
			options = options or {}
			if (not self:_hasTable()) then
				error('into() needs to be called')
			end

			return cls.AbstractTableBlock._toParamString(self, options)
		end

	-- (SELECT) Get field
	cls.GetFieldBlock = cls.Block:extend()
		function cls.GetFieldBlock:initialize(options)
			cls.Block.initialize(self, options)

			self._fields = {}
		end

		--[[
		# Add the given fields to the final result set.
		#
		# The parameter is an Object containing field names (or database functions) as the keys and aliases for the fields
		# as the values. If the value for a key is nil then no alias is set for that field.
		#
		# Internally this method simply calls the field() method of this block to add each individual field.
		#
		# options.ignorePeriodsForFieldNameQuotes - whether to ignore period (.) when automatically quoting the field name
		]]
		function cls.GetFieldBlock:fields(fields, options)
			options = options or {}
			if (R.isArray(fields)) then
				for _, field in ipairs(fields) do
					self:field(field, nil, options)
				end
			else
				for field, alias in pairs(fields) do
					if (alias == 'NULL') then
						alias = nil
					end
					self:field(field, alias, options)
				end
			end
		end

		--[[
		# Add the given field to the final result set.
		#
		# The 'field' parameter does not necessarily have to be a fieldname. It can use database functions too,
		# e.g. DATE_FORMAT(a.started, '%H')
		#
		# An alias may also be specified for this field.
		#
		# options.ignorePeriodsForFieldNameQuotes - whether to ignore period (.) when automatically quoting the field name
		]]
		function cls.GetFieldBlock:field(field, alias, options)
			options = options or {}
			alias = alias and self:_sanitizeFieldAlias(alias) or alias
			field = self:_sanitizeField(field)

			-- if field-alias combo already present then don't add
			local existingField = R.filter(self._fields, function(_, f)
				return f.name == field and f.alias == alias
			end)
			if (#existingField > 0) then
				return self
			end

			table.insert(self._fields, {
				name = field,
				alias = alias,
				options = options,
			})
		end

		function cls.GetFieldBlock:_toParamString(options)
			options = options or {}
			local queryBuilder, buildParameterized = options.queryBuilder, options.buildParameterized

			local totalStr, totalValues = '', {}

			for _, _field in ipairs(self._fields) do
				totalStr = _pad(totalStr, ', ')

				local name, alias = _field.name, _field.alias
				options = _field.options

				if (type(name) == 'string') then
					totalStr = totalStr .. self:_formatFieldName(name, options)
				else
					local ret = name:_toParamString({
						nested = true,
						buildParameterized = buildParameterized,
					})

					totalStr = totalStr .. ret.text
					R.push(totalValues, unpack(ret.values))
				end

				if (alias) then
					totalStr = totalStr .. (' AS %s'):format(self:_formatFieldAlias(alias))
				end
			end

			if (not (#totalStr > 0)) then
				-- if select query and a table is set then all fields wanted
				local fromTableBlock = queryBuilder and queryBuilder:getBlock(cls.FromTableBlock)
				if (fromTableBlock and fromTableBlock:_hasTable()) then
					totalStr = '*'
				end
			end

			return {
				text = totalStr,
				values = totalValues,
			}
		end

	-- Base class for setting fields to values (used for INSERT and UPDATE queries)
	cls.AbstractSetFieldBlock = cls.Block:extend()
		function cls.AbstractSetFieldBlock:initialize(options)
			cls.Block.initialize(self, options)

			self:_reset()
		end

		function cls.AbstractSetFieldBlock:_reset()
			self._fields = {}
			self._values = {{}}
			self._valueOptions = {{}}
		end

		-- Update the given field with the given value.
		-- This will override any previously set value for the given field.
		function cls.AbstractSetFieldBlock:_set(field, value, valueOptions)
			valueOptions = valueOptions or {}
			if (#self._values > 1) then
				error('Cannot set multiple rows of fields this way.')
			end

			if (type(value) ~= 'nil') then
				value = self:_sanitizeValue(value)
			end

			field = self:_sanitizeField(field)

			-- Explicity overwrite existing fields
			local index = R.indexOf(self._fields, field)

			-- if field not defined before
			if (nil == index) then
				table.insert(self._fields, field)
				index = #self._fields
			end

			self._values[1][index] = value
			self._valueOptions[1][index] = valueOptions
		end

		-- Insert fields based on the key/value pairs in the given object
		function cls.AbstractSetFieldBlock:_setFields(fields, valueOptions)
			valueOptions = valueOptions or {}
			if (type(fields) ~= 'table') then
				error('Expected an table but got ' .. type(fields))
			end

			for field, value in pairs(fields) do
				self:_set(field, value, valueOptions)
			end
		end

		-- Insert multiple rows for the given fields. Accepts an array of objects.
		-- This will override all previously set values for every field.
		function cls.AbstractSetFieldBlock:_setFieldsRows(fieldsRows, valueOptions)
			valueOptions = valueOptions or {}
			if (not R.isArray(fieldsRows)) then
				error('Expected an array of objects but got ' .. type(fieldsRows))
			end

			-- Reset the objects stored fields and values
			self:_reset()

			-- for each row
			for rowIndex, fieldRow in ipairs(fieldsRows) do

				-- for each field
				for field, value in pairs(fieldRow) do

					field = self:_sanitizeField(field)
					value = self:_sanitizeValue(value)

					local fieldIndex = R.indexOf(self._fields, field)

					if (1 < rowIndex and nil == fieldIndex) then
						error('All fields in subsequent rows must match the fields in the first row')
					end

					-- Add field only if it hasn't been added before
					if (nil == fieldIndex) then
						table.insert(self._fields, field)
						fieldIndex = #self._fields
					end

					-- The first value added needs to add the array
					if (not R.isArray(self._values[rowIndex])) then
						self._values[rowIndex] = {}
						self._valueOptions[rowIndex] = {}
					end

					self._values[rowIndex][fieldIndex] = value
					self._valueOptions[rowIndex][fieldIndex] = valueOptions
				end
			end
		end

	-- (UPDATE) SET field=value
	cls.SetFieldBlock = cls.AbstractSetFieldBlock:extend()
		function cls.SetFieldBlock:set(field, value, options)
			self:_set(field, value, options)
		end

		function cls.SetFieldBlock:setFields(fields, valueOptions)
			self:_setFields(fields, valueOptions)
		end

		function cls.SetFieldBlock:_toParamString(options)
			options = options or {}
			local buildParameterized = options.buildParameterized

			if (0 >= #self._fields) then
				error('set() needs to be called')
			end

			local totalStr, totalValues = '', {}

			for index, _field in ipairs(self._fields) do
				totalStr = _pad(totalStr, ', ')

				local field = self:_formatFieldName(_field)
				local value = self._values[1][index]

				-- e.g. field can be an expression such as `count = count + 1`
				if (nil == field:find('=')) then
					field = ('%s = %s'):format(field, self.options.parameterCharacter)
				end

				local ret = self:_buildString(
					field,
					{ value },
					{
						buildParameterized = buildParameterized,
						formattingOptions = self._valueOptions[1][index],
					}
				)

				totalStr = totalStr .. ret.text
				R.push(totalValues, unpack(ret.values))
			end

			return {
				text = ('SET %s'):format(totalStr),
				values = totalValues,
			}
		end

	-- (INSERT INTO) ... field ... value
	cls.InsertFieldValueBlock = cls.AbstractSetFieldBlock:extend()
		function cls.InsertFieldValueBlock:set(field, value, options)
			options = options or {}
			self:_set(field, value, options)
		end

		function cls.InsertFieldValueBlock:setFields(fields, valueOptions)
			self:_setFields(fields, valueOptions)
		end

		function cls.InsertFieldValueBlock:setFieldsRows(fieldsRows, valueOptions)
			self:_setFieldsRows(fieldsRows, valueOptions)
		end

		function cls.InsertFieldValueBlock:_toParamString(options)
			options = options or {}
			local buildParameterized = options.buildParameterized

			local fieldString = R(self._fields)
				:map(function(_, f) return self:_formatFieldName(f) end)
				:join(', ')
				:value()

			local valueStrings, totalValues = {}, {}

			for outerIndex, outerValue in ipairs(self._values) do
				valueStrings[outerIndex] = ''

				for innerIndex, innerValue in ipairs(outerValue) do
					local ret =
						self:_buildString(self.options.parameterCharacter, { innerValue }, {
							buildParameterized = buildParameterized,
							formattingOptions = self._valueOptions[outerIndex][innerIndex],
						})

					R.push(totalValues, unpack(ret.values))

					valueStrings[outerIndex] = _pad(valueStrings[outerIndex], ', ')
					valueStrings[outerIndex] = valueStrings[outerIndex] .. ret.text
				end
			end

			return {
				text = #fieldString > 0
					and ('(%s) VALUES (%s)'):format(fieldString, table.concat(valueStrings, '), ('))
					or '',
				values = totalValues
			}
		end

	-- (INSERT INTO) ... field ... (SELECT ... FROM ...)
	cls.InsertFieldsFromQueryBlock = cls.Block:extend()
		function cls.InsertFieldsFromQueryBlock:initialize(options)
			options = options or {}
			cls.Block.initialize(self, options)

			self._fields = {}
			self._query = nil
		end

		function cls.InsertFieldsFromQueryBlock:fromQuery(fields, selectQuery)
			self._fields = R.map(fields, function(_, v)
				return self:_sanitizeField(v)
			end)

			self._query = self:_sanitizeBaseBuilder(selectQuery)
		end

		function cls.InsertFieldsFromQueryBlock:_toParamString(options)
			options = options or {}
			local totalStr, totalValues = '', {}

			if (#self._fields > 0 and self._query) then
				local _toParamString = self._query:_toParamString({
					buildParameterized = options.buildParameterized,
					nested = true,
				})
				local text, values = _toParamString.text, _toParamString.values

				totalStr = ('(%s) %s'):format(table.concat(self._fields, ', '), self:_applyNestingFormatting(text))
				totalValues = values
			end

			return {
				text = totalStr,
				values = totalValues,
			}
		end

	-- DISTINCT
	cls.DistinctBlock = cls.Block:extend()
		-- Add the DISTINCT keyword to the query.
		function cls.DistinctBlock:distinct()
			self._useDistinct = true
		end

		function cls.DistinctBlock:_toParamString()
			return {
				text = self._useDistinct and 'DISTINCT' or '',
				values = {},
			}
		end

	-- GROUP BY
	cls.GroupByBlock = cls.Block:extend()
		function cls.GroupByBlock:initialize(options)
			cls.Block.initialize(self, options)

			self._groups = {}
		end

		-- Add a GROUP BY transformation for the given field.
		function cls.GroupByBlock:group(field)
			table.insert(self._groups, self:_sanitizeField(field))
		end

		function cls.GroupByBlock:_toParamString()
			return {
				text = #self._groups > 0 and ('GROUP BY %s'):format(table.concat(self._groups, ', ')) or '',
				values = {},
			}
		end

	cls.AbstractVerbSingleValueBlock = cls.Block:extend()
		--[[
		 * @param options.verb The prefix verb string.
		 ]]
		function cls.AbstractVerbSingleValueBlock:initialize(options)
			cls.Block.initialize(self, options)

			self._value = 0
		end

		function cls.AbstractVerbSingleValueBlock:_setValue(value)
			self._value = self:_sanitizeLimitOffset(value)
		end

		function cls.AbstractVerbSingleValueBlock:_toParamString(options)
			options = options or {}
			local expr = (0 < self._value)
				and ('%s %s'):format(self.options.verb, self.options.parameterCharacter)
				or ''

			local values = (nil ~= self._value)
				and { self._value }
				or {}

			return self:_buildString(expr, values, options)
		end

	-- OFFSET x
	cls.OffsetBlock = cls.AbstractVerbSingleValueBlock:extend()
		function cls.OffsetBlock:initialize(options)
			cls.AbstractVerbSingleValueBlock.initialize(self, _extend({}, options, {
				verb = 'OFFSET'
			}))
		end

		--[[
		# Set the OFFSET transformation.
		#
		# Call this will override the previously set offset for this query. Also note that Passing 0 for 'max' will remove
		# the offset.
		]]
		function cls.OffsetBlock:offset(start)
			self:_setValue(start)
		end

	-- LIMIT
	cls.LimitBlock = cls.AbstractVerbSingleValueBlock:extend()
		function cls.LimitBlock:initialize(options)
			cls.AbstractVerbSingleValueBlock.initialize(self, _extend({}, options, {
				verb = 'LIMIT'
			}))
		end

		--[[
		# Set the LIMIT transformation.
		#
		# Call this will override the previously set limit for this query. Also note that Passing 0 for 'max' will remove
		# the limit.
		]]
		function cls.LimitBlock:limit(limit)
			self:_setValue(limit)
		end

	-- Abstract condition base class
	cls.AbstractConditionBlock = cls.Block:extend()
		--[[
		 * @param {String} options.verb The condition verb.
		 ]]
		function cls.AbstractConditionBlock:initialize(options)
			cls.Block.initialize(self, options)

			self._conditions = {}
		end

		--[[
		# Add a condition.
		#
		# When the final query is constructed all the conditions are combined using the intersection (AND) operator.
		#
		# Concrete subclasses should provide a method which calls this
		]]
		function cls.AbstractConditionBlock:_condition(condition, ...)
			local values = { ... }
			condition = self:_sanitizeExpression(condition)

			table.insert(self._conditions, {
				expr = condition,
				values = values,
			})
		end

		function cls.AbstractConditionBlock:_toParamString(options)
			options = options or {}
			local totalStr, totalValues = {}, {}

			for _, _condition in ipairs(self._conditions) do
				local expr, values = _condition.expr, _condition.values
				local ret = (cls._isSquelBuilder(expr))
					and expr:_toParamString({
							buildParameterized = options.buildParameterized,
						})
					or self:_buildString(expr, values, {
							buildParameterized = options.buildParameterized,
						})

				if (#ret.text > 0) then
					table.insert(totalStr, ret.text)
				end

				R.push(totalValues, unpack(ret.values))
			end

			if (#totalStr > 0) then
				totalStr = table.concat(totalStr, ') AND (')
			end

			return {
				text = #totalStr > 0 and ('%s (%s)'):format(self.options.verb, totalStr) or '',
				values = totalValues,
			}
		end

	-- WHERE
	cls.WhereBlock = cls.AbstractConditionBlock:extend()
		function cls.WhereBlock:initialize(options)
			cls.AbstractConditionBlock.initialize(self, _extend({}, options, {
				verb = 'WHERE'
			}))
		end

		function cls.WhereBlock:where(condition, ...)
			self:_condition(condition, ...)
		end

	-- HAVING
	cls.HavingBlock = cls.AbstractConditionBlock:extend()
		function cls.HavingBlock:initialize(options)
			cls.AbstractConditionBlock.initialize(self, _extend({}, options, {
				verb = 'HAVING'
			}))
		end

		function cls.HavingBlock:having(condition, ...)
			self:_condition(condition, ...)
		end

	-- ORDER BY
	cls.OrderByBlock = cls.Block:extend()
		function cls.OrderByBlock:initialize(options)
			cls.Block.initialize(self, options)

			self._orders = {}
		end

		--[[
		# Add an ORDER BY transformation for the given field in the given order.
		#
		# To specify descending order pass false for the 'dir' parameter.
		]]
		function cls.OrderByBlock:order(field, dir, ...)
			local values = { ... }
			field = self:_sanitizeField(field)

			if (not (type(dir) == 'string')) then
				if (dir == nil) then
					dir = 'ASC' -- Default to asc
				else
					dir = dir and 'ASC' or 'DESC' -- Convert truthy to asc
				end
			end

			table.insert(self._orders, {
				field = field,
				dir = dir,
				values = values,
			})
		end

		function cls.OrderByBlock:_toParamString(options)
			options = options or {}
			local totalStr, totalValues = '', {}

			for _, _order in ipairs(self._orders) do
				local field, dir, values = _order.field, _order.dir, _order.values
				totalStr = _pad(totalStr, ', ')

				local ret = self:_buildString(field, values, {
					buildParameterized = options.buildParameterized,
				})

				totalStr = totalStr .. ret.text
				R.push(totalValues, unpack(ret.values))

				if (dir ~= nil) then
					totalStr = totalStr .. (' %s'):format(dir)
				end
			end

			return {
				text = #totalStr > 0 and ('ORDER BY %s'):format(totalStr) or '',
				values = totalValues,
			}
		end

	-- JOIN
	cls.JoinBlock = cls.Block:extend()
		function cls.JoinBlock:initialize(options)
			cls.Block.initialize(self, options)

			self._joins = {}
		end

		--[[
		# Add a JOIN with the given table.
		#
		# 'table' is the name of the table to join with.
		#
		# 'alias' is an optional alias for the table name.
		#
		# 'condition' is an optional condition (containing an SQL expression) for the JOIN.
		#
		# 'type' must be either one of INNER, OUTER, LEFT or RIGHT. Default is 'INNER'.
		#
		]]
		function cls.JoinBlock:join(tableName, alias, condition, typeName)
			typeName = typeName or 'INNER'
			tableName = self:_sanitizeTable(tableName, true)
			alias = alias and self:_sanitizeTableAlias(alias) or alias
			condition = condition and self:_sanitizeExpression(condition) or condition

			table.insert(self._joins, {
				type = typeName,
				table = tableName,
				alias = alias,
				condition = condition,
			})
		end

		function cls.JoinBlock:left_join(tableName, alias, condition)
			self:join(tableName, alias, condition, 'LEFT')
		end

		function cls.JoinBlock:right_join(tableName, alias, condition)
			self:join(tableName, alias, condition, 'RIGHT')
		end

		function cls.JoinBlock:outer_join(tableName, alias, condition)
			self:join(tableName, alias, condition, 'OUTER')
		end

		function cls.JoinBlock:left_outer_join(tableName, alias, condition)
			self:join(tableName, alias, condition, 'LEFT OUTER')
		end

		function cls.JoinBlock:full_join(tableName, alias, condition)
			self:join(tableName, alias, condition, 'FULL')
		end

		function cls.JoinBlock:cross_join(tableName, alias, condition)
			self:join(tableName, alias, condition, 'CROSS')
		end

		function cls.JoinBlock:_toParamString(options)
			options = options or {}
			local totalStr, totalValues = '', {}

			for _, _join in ipairs(self._joins) do
				local typeName, tableName, alias, condition = _join.type, _join.table, _join.alias, _join.condition
				totalStr = _pad(totalStr, self.options.separator)

				local tableStr

				if (cls._isSquelBuilder(tableName)) then
					local ret = tableName:_toParamString({
						buildParameterized = options.buildParameterized,
						nested = true
					})

					R.push(totalValues, unpack(ret.values))
					tableStr = ret.text
				else
					tableStr = self:_formatTableName(tableName)
				end

				totalStr = totalStr .. ('%s JOIN %s'):format(typeName, tableStr)

				if (alias) then
					totalStr = totalStr .. (' %s'):format(self:_formatTableAlias(alias))
				end

				if (condition) then
					totalStr = totalStr .. ' ON '

					local ret

					if (cls._isSquelBuilder(condition)) then
						ret = condition:_toParamString({
							buildParameterized = options.buildParameterized,
						})
					else
						ret = self:_buildString(condition, {}, {
							buildParameterized = options.buildParameterized,
						})
					end

					totalStr = totalStr .. self:_applyNestingFormatting(ret.text)
					R.push(totalValues, unpack(ret.values))
				end
			end

			return {
				text = totalStr,
				values = totalValues,
			}
		end

	-- UNION
	cls.UnionBlock = cls.Block:extend()
		function cls.UnionBlock:initialize(options)
			cls.Block.initialize(self, options)

			self._unions = {}
		end

		--[[
		# Add a UNION with the given table/query.
		#
		# 'table' is the name of the table or query to union with.
		#
		# 'type' must be either one of UNION or UNION ALL.... Default is 'UNION'.
		]]
		function cls.UnionBlock:union(tableName, typeName)
			typeName = typeName or 'UNION'
			tableName = self:_sanitizeTable(tableName)

			table.insert(self._unions, {
				type = typeName,
				table = tableName,
			})
		end

		-- Add a UNION ALL with the given table/query.
		function cls.UnionBlock:union_all(tableName)
			self:union(tableName, 'UNION ALL')
		end

		function cls.UnionBlock:_toParamString(options)
			options = options or {}
			local totalStr, totalValues = '', {}

			for _, _union in ipairs(self._unions) do
				local typeName, tableName = _union.type, _union.table
				totalStr = _pad(totalStr, self.options.separator)

				local tableStr

				if (Object.instanceof(tableName, cls.BaseBuilder)) then
					local ret = tableName:_toParamString({
						buildParameterized = options.buildParameterized,
						nested = true
					})

					tableStr = ret.text
					R.push(totalValues, unpack(ret.values))
				else
					totalStr = self:_formatTableName(tableName)
				end

				totalStr = totalStr .. ('%s %s'):format(typeName, tableStr)
			end

			return {
				text = totalStr,
				values = totalValues,
			}
		end

	--[[
	# ---------------------------------------------------------------------------------------------------------
	# ---------------------------------------------------------------------------------------------------------
	# Query builders
	# ---------------------------------------------------------------------------------------------------------
	# ---------------------------------------------------------------------------------------------------------
	]]

	--[[
	# Query builder base class
	#
	# Note that the query builder does not check the final query string for correctness.
	#
	# All the build methods in this object return the object instance for chained method calling purposes.
	]]
	cls.QueryBuilder = cls.BaseBuilder:extend()
		--[[
		# Constructor
		#
		# blocks - array of cls.BaseBuilderBlock instances to build the query with.
		]]
		function cls.QueryBuilder:initialize(options, blocks)
			cls.BaseBuilder.initialize(self, options)

			self.blocks = blocks or {}

			-- Copy exposed methods into myself
			for _, block in ipairs(self.blocks) do
				local exposedMethods = block:exposedMethods()

				for methodName, methodBody in pairs(exposedMethods) do
					if (nil ~= self[methodName]) then
						error(('Builder already has a builder method called: %s'):format(methodName))
					end

					self[methodName] = function(this, ...)
						methodBody(block, ...)

						return this
					end
				end
			end
		end

		--[[
		# Register a custom value handler for this query builder and all its contained blocks.
		#
		# Note: This will override any globally registered handler for this value type.
		]]
		function cls.QueryBuilder:registerValueHandler(typeName, handler)
			for _, block in ipairs(self.blocks) do
				block:registerValueHandler(typeName, handler)
			end

			return cls.BaseBuilder.registerValueHandler(self, typeName, handler)
		end

		--[[
		# Update query builder options
		#
		# This will update the options for all blocks too. Use this method with caution as it allows you to change the
		# behaviour of your query builder mid-build.
		]]
		function cls.QueryBuilder:updateOptions(options)
			self.options = _extend({}, self.options, options)

			for _, block in ipairs(self.blocks) do
				block.options = _extend({}, block.options, options)
			end
		end

		-- Get the final fully constructed query param obj.
		function cls.QueryBuilder:_toParamString(options)
			options = options or {}
			options = _extend({}, self.options, options)

			local blockResults = R.map(self.blocks, function(_, b)
				return b:_toParamString({
					buildParameterized = options.buildParameterized,
					queryBuilder = self,
				})
			end)

			local blockTexts = R.map(blockResults, function(_, b) return b.text end)
			local blockValues = R.map(blockResults, function(_, b) return b.values end)

			local totalStr = R(blockTexts)
				:filter(function(_, v) return 0 < #v end)
				:join(options.separator)
				:value()

			local totalValues = R.flatten(blockValues)

			if (not options.nested) then
				if (options.numberedParameters) then
					local index = (nil ~= options.numberedParametersStartAt)
						and options.numberedParametersStartAt
						or 1

					-- construct regex for searching
					local regex = options.parameterCharacter:gsub('[-[]{}()*+?.,\\^$|#%s]', '%$&')

					totalStr = totalStr:gsub(regex, function()
						local s = ('%s%s'):format(options.numberedParametersPrefix, index)
						index = index + 1
						return s
					end)
				end
			end

			return {
				text = self:_applyNestingFormatting(totalStr, not not options.nested),
				values = totalValues,
			}
		end

		-- Deep clone
		function cls.QueryBuilder:clone()
			local blockClones = R.map(self.blocks, function(_, v)
				return v:clone()
			end)

			return self.meta.__index:new(self.options, blockClones)
		end

		-- Get a specific block
		function cls.QueryBuilder:getBlock(blockType)
			local filtered = R.filter(self.blocks, function(_, b)
				return Object.instanceof(b, blockType)
			end)

			return filtered[1]
		end

	-- SELECT query builder.
	cls.Select = cls.QueryBuilder:extend()
		function cls.Select:initialize(options, blocks)
			blocks = blocks or {
				cls.StringBlock:new(options, 'SELECT'),
				cls.FunctionBlock:new(options),
				cls.DistinctBlock:new(options),
				cls.GetFieldBlock:new(options),
				cls.FromTableBlock:new(options),
				cls.JoinBlock:new(options),
				cls.WhereBlock:new(options),
				cls.GroupByBlock:new(options),
				cls.HavingBlock:new(options),
				cls.OrderByBlock:new(options),
				cls.LimitBlock:new(options),
				cls.OffsetBlock:new(options),
				cls.UnionBlock:new(options),
			}

			cls.QueryBuilder.initialize(self, options, blocks)
		end

	-- UPDATE query builder.
	cls.Update = cls.QueryBuilder:extend()
		function cls.Update:initialize(options, blocks)
			blocks = blocks or {
				cls.StringBlock:new(options, 'UPDATE'),
				cls.UpdateTableBlock:new(options),
				cls.SetFieldBlock:new(options),
				cls.WhereBlock:new(options),
				cls.OrderByBlock:new(options),
				cls.LimitBlock:new(options),
			}

			cls.QueryBuilder.initialize(self, options, blocks)
		end

	-- DELETE query builder.
	cls.Delete = cls.QueryBuilder:extend()
		function cls.Delete:initialize(options, blocks)
			blocks = blocks or {
				cls.StringBlock:new(options, 'DELETE'),
				cls.TargetTableBlock:new(options),
				cls.FromTableBlock:new(_extend({}, options, { singleTable = true })),
				cls.JoinBlock:new(options),
				cls.WhereBlock:new(options),
				cls.OrderByBlock:new(options),
				cls.LimitBlock:new(options),
			}

			cls.QueryBuilder.initialize(self, options, blocks)
		end

	-- An INSERT query builder.
	cls.Insert = cls.QueryBuilder:extend()
		function cls.Insert:initialize(options, blocks)
			blocks = blocks or {
				cls.StringBlock:new(options, 'INSERT'),
				cls.IntoTableBlock:new(options),
				cls.InsertFieldValueBlock:new(options),
				cls.InsertFieldsFromQueryBlock:new(options),
			}

			cls.QueryBuilder.initialize(self, options, blocks)
		end

	local _squel = {
		VERSION = '5.7.0',
		flavour = flavour,
		expr = function(options)
			return cls.Expression:new(options)
		end,
		case = function(name, options)
			return cls.Case:new(name, options)
		end,
		select = function(options, blocks)
			return cls.Select:new(options, blocks)
		end,
		update = function(options, blocks)
			return cls.Update:new(options, blocks)
		end,
		insert = function(options, blocks)
			return cls.Insert:new(options, blocks)
		end,
		delete = function(options, blocks)
			return cls.Delete:new(options, blocks)
		end,
		str = function(...)
			local inst = cls.FunctionBlock:new()
			inst:FUNCTION(...)
			return inst
		end,
		registerValueHandler = cls.registerValueHandler,
	}

	-- aliases
	_squel.remove = _squel.delete

	-- classes
	_squel.cls = cls

	return _squel
end

--[[
# ---------------------------------------------------------------------------------------------------------
# ---------------------------------------------------------------------------------------------------------
# Exported instance (and for use by flavour definitions further down).
# ---------------------------------------------------------------------------------------------------------
# ---------------------------------------------------------------------------------------------------------
]]

local squel = _buildSquel()

--[[
# ---------------------------------------------------------------------------------------------------------
# ---------------------------------------------------------------------------------------------------------
# Squel SQL flavours
# ---------------------------------------------------------------------------------------------------------
# ---------------------------------------------------------------------------------------------------------
]]

-- Available flavours
squel.flavours = {}

-- Setup Squel for a particular SQL flavour
squel.useFlavour = function(flavour)
	if (not flavour) then
		return squel
	end

	if (type(squel.flavours[flavour]) == 'function') then
		local s = _buildSquel(flavour)

		squel.flavours[flavour](s)

		-- add in flavour methods
		s.flavours = squel.flavours
		s.useFlavour = squel.useFlavour

		return s
	else
		error(('Flavour not available: %s'):format(flavour))
	end
end

-- This file contains additional Squel commands for use with the Postgres DB engine
squel.flavours.postgres = function(_squel)
	local cls = _squel.cls

	cls.DefaultQueryBuilderOptions.numberedParameters = true
	cls.DefaultQueryBuilderOptions.numberedParametersStartAt = 1
	cls.DefaultQueryBuilderOptions.autoQuoteAliasNames = false
	cls.DefaultQueryBuilderOptions.useAsForTableAliasNames = true

	cls.PostgresOnConflictKeyUpdateBlock = cls.AbstractSetFieldBlock:extend()
		function cls.PostgresOnConflictKeyUpdateBlock:onConflict(index, fields)
			self._dupIndex = self:_sanitizeField(index)

			if (fields) then
				for field, value in pairs(fields) do
					self:_set(field, value)
				end
			end
		end

		function cls.PostgresOnConflictKeyUpdateBlock:onConflictOnConstraint(constraint, fields)
			self._onConstraint = true
			self._dupIndex = self:_sanitizeField(constraint)

			if (fields) then
				for field, value in pairs(fields) do
					self:_set(field, value)
				end
			end
		end

		function cls.PostgresOnConflictKeyUpdateBlock:_toParamString(options)
			options = options or {}
			local totalStr, totalValues = '', {}

			for index, field in ipairs(self._fields) do
				totalStr = _pad(totalStr, ', ')

				local value = self._values[1][index]

				local valueOptions = self._valueOptions[1][index]

				-- e.g. if field is an expression such as: count = count + 1
				if (type(value) == 'nil') then
					totalStr = totalStr .. field
				else
					local ret = self:_buildString(
							('%s = %s'):format(field, self.options.parameterCharacter),
							{ value },
							{
								buildParameterized = options.buildParameterized,
								formattingOptions = valueOptions,
							}
					)

					totalStr = totalStr .. ret.text
					R.push(totalValues, unpack(ret.values))
				end
			end

			local template = self._onConstraint
					and 'ON CONFLICT ON CONSTRAINT %s DO '
					or 'ON CONFLICT (%s) DO '

			return {
				text = self._dupIndex and (template):format(self._dupIndex)
					.. (not (#totalStr > 0) and 'NOTHING' or ('UPDATE SET %s'):format(totalStr)) or '',
				values = totalValues,
			}
		end

	-- RETURNING
	cls.ReturningBlock = cls.Block:extend()
		function cls.ReturningBlock:initialize(options)
			cls.Block.initialize(self, options)
			self._fields = {}
		end

		function cls.ReturningBlock:returning(field, alias, options)
			options = options or {}
			alias = alias and self:_sanitizeFieldAlias(alias) or alias
			field = self:_sanitizeField(field)

			-- if field-alias combo already present then don't add
			local existingField = R.filter(self._fields, function(_, f)
				return f.name == field and f.alias == alias
			end)
			if (#existingField > 0) then
				return self
			end

			table.insert(self._fields, {
				name = field,
				alias = alias,
				options = options,
			})
		end

		function cls.ReturningBlock:_toParamString(options)
			options = options or {}
			local buildParameterized = options.buildParameterized

			local totalStr, totalValues = '', {}

			for _, field in ipairs(self._fields) do
				totalStr = _pad(totalStr, ', ')

				local name, alias = field.name, field.alias
				options = field.options

				if (type(name) == 'string') then
					totalStr = totalStr .. self:_formatFieldName(name, options)
				else
					local ret = name:_toParamString({
						nested = true,
						buildParameterized = buildParameterized,
					})

					totalStr = totalStr .. ret.text
					R.push(totalValues, unpack(ret.values))
				end

				if (alias) then
					totalStr = totalStr .. (' AS %s'):format(self:_formatFieldAlias(alias))
				end
			end

			return {
				text = #totalStr > 0 and ('RETURNING %s'):format(totalStr) or '',
				values = totalValues
			}
		end

	-- WITH
	cls.WithBlock = cls.Block:extend()
		function cls.WithBlock:initialize(options)
			cls.Block.initialize(self, options)
			self._tables = {}
		end

		function cls.WithBlock:with(alias, tableName)
			table.insert(self._tables, { alias = alias, table = tableName })
		end

		function cls.WithBlock:_toParamString(options)
			options = options or {}
			local parts  = {}
			local values = {}

			for _, _table in ipairs(self._tables) do
				local alias, tableName = _table.alias, _table.table
				local ret = tableName:_toParamString({
					buildParameterized = options.buildParameterized,
					nested = true
				})

				table.insert(parts, ('%s AS %s'):format(alias, ret.text))
				R.push(values, unpack(ret.values))
			end

			return {
				text = #parts > 0 and ('WITH %s'):format(table.concat(parts, ', ')) or '',
				values = values,
			}
		end

	-- DISTINCT [ON]
	cls.DistinctOnBlock = cls.Block:extend()
		function cls.DistinctOnBlock:initialize(options)
			cls.Block.initialize(self, options)

			self._distinctFields = {}
		end

		function cls.DistinctOnBlock:distinct(...)
			local fields = { ... }
			self._useDistinct = true

			-- Add all fields to the DISTINCT ON clause.
			for _, field in ipairs(fields) do
				table.insert(self._distinctFields, self:_sanitizeField(field))
			end
		end

		function cls.DistinctOnBlock:_toParamString()
			local text = ''

			if (self._useDistinct) then
				text = 'DISTINCT'

				if (#self._distinctFields > 0) then
						text = text .. (' ON (%s)'):format(table.concat(self._distinctFields, ', '))
				end
			end

			return {
				text = text,
				values = {}
			}
		end

	-- SELECT query builder.
	cls.Select = cls.QueryBuilder:extend()
		function cls.Select:initialize(options, blocks)
			blocks = blocks or {
				cls.WithBlock:new(options),
				cls.StringBlock:new(options, 'SELECT'),
				cls.FunctionBlock:new(options),
				cls.DistinctOnBlock:new(options),
				cls.GetFieldBlock:new(options),
				cls.FromTableBlock:new(options),
				cls.JoinBlock:new(options),
				cls.WhereBlock:new(options),
				cls.GroupByBlock:new(options),
				cls.HavingBlock:new(options),
				cls.OrderByBlock:new(options),
				cls.LimitBlock:new(options),
				cls.OffsetBlock:new(options),
				cls.UnionBlock:new(options)
			}

			cls.QueryBuilder.initialize(self, options, blocks)
		end

	-- INSERT query builder
	cls.Insert = cls.QueryBuilder:extend()
		function cls.Insert:initialize(options, blocks)
			blocks = blocks or {
				cls.WithBlock:new(options),
				cls.StringBlock:new(options, 'INSERT'),
				cls.IntoTableBlock:new(options),
				cls.InsertFieldValueBlock:new(options),
				cls.InsertFieldsFromQueryBlock:new(options),
				cls.PostgresOnConflictKeyUpdateBlock:new(options),
				cls.ReturningBlock:new(options),
			}

			cls.QueryBuilder.initialize(self, options, blocks)
		end

	-- UPDATE query builder
	cls.Update = cls.QueryBuilder:extend()
		function cls.Update:initialize(options, blocks)
			blocks = blocks or {
				cls.WithBlock:new(options),
				cls.StringBlock:new(options, 'UPDATE'),
				cls.UpdateTableBlock:new(options),
				cls.SetFieldBlock:new(options),
				cls.FromTableBlock:new(options),
				cls.WhereBlock:new(options),
				cls.OrderByBlock:new(options),
				cls.LimitBlock:new(options),
				cls.ReturningBlock:new(options),
			}

			cls.QueryBuilder.initialize(self, options, blocks)
		end

	-- DELETE query builder
	cls.Delete = cls.QueryBuilder:extend()
		function cls.Delete:initialize(options, blocks)
			blocks = blocks or {
				cls.WithBlock:new(options),
				cls.StringBlock:new(options, 'DELETE'),
				cls.TargetTableBlock:new(options),
				cls.FromTableBlock:new(_extend({}, options, { singleTable = true })),
				cls.JoinBlock:new(options),
				cls.WhereBlock:new(options),
				cls.OrderByBlock:new(options),
				cls.LimitBlock:new(options),
				cls.ReturningBlock:new(options),
			}

			cls.QueryBuilder.initialize(self, options, blocks)
		end
end

return squel
