local match = require('luassert.match')
local Object = require('object')
local R = require('moses')
local squel = require('squel')

it('Version number', function()
	assert.is_equal('5.7.0', squel.VERSION)
end)

it('Default flavour', function()
	assert.is_equal(nil, squel.flavour)
end)

describe('Cloneable base class', function()
	it('>> clone()', function()
		local Child = squel.cls.Cloneable:extend()
			function Child:initialize()
				self.a = 1
				self.b = 2.2
				self.c = true
				self.d = 'str'
				self.e = { 1 }
				self.f = { a = 1 }
			end

		local child = Child:new()

		local copy = child:clone()
		assert.is_equal(true, Object.instanceof(copy, Child))

		child.a = 2
		child.b = 3.2
		child.c = false
		child.d = 'str2'
		R.push(child.e, 2)
		child.f.b = 1

		assert.is_equal(1, copy.a)
		assert.is_equal(2.2, copy.b)
		assert.is_equal(true, copy.c)
		assert.is_equal('str', copy.d)
		assert.is_same({ 1 }, copy.e)
		assert.is_same({ a = 1 }, copy.f)
	end)
end)

describe('Default query builder options', function()
	it('default options', function()
		assert.is_same({
			autoQuoteTableNames = false,
			autoQuoteFieldNames = false,
			autoQuoteAliasNames = true,
			useAsForTableAliasNames = false,
			nameQuoteCharacter = '`',
			tableAliasQuoteCharacter = '`',
			fieldAliasQuoteCharacter = '"',
			valueHandlers = {},
			parameterCharacter = '?',
			numberedParameters = false,
			numberedParametersPrefix = '$',
			numberedParametersStartAt = 1,
			replaceSingleQuotes = false,
			singleQuoteReplacement = '\'\'',
			separator = ' ',
			stringFormatter = nil
		}, squel.cls.DefaultQueryBuilderOptions)
	end)
end)

describe('Register global custom value handler', function()
	local originalHandlers

	before_each(function()
		originalHandlers = R.clone(squel.cls.globalValueHandlers, true)
		squel.cls.globalValueHandlers = {}
	end)

	after_each(function()
		squel.cls.globalValueHandlers = originalHandlers
	end)

	it('default', function()
		local handler = function() return 'test' end
		squel.registerValueHandler(Object, handler)
		squel.registerValueHandler('boolean', handler)

		assert.is_equal(2, #squel.cls.globalValueHandlers)
		assert.is_same({ type = Object, handler = handler }, squel.cls.globalValueHandlers[1])
		assert.is_same({ type = 'boolean', handler = handler }, squel.cls.globalValueHandlers[2])
	end)

	it('type should be class constructor', function()
		assert.is_error(function()
			squel.registerValueHandler(1, nil)
		end, 'type must be a class constructor or string')
	end)

	it('handler should be function', function()
		assert.is_error(function()
			squel.registerValueHandler(Object, 1)
		end, 'handler must be a function')
	end)

	it('overrides existing handler', function()
		local handler = function() return 'test' end
		local handler2 = function() return 'test2' end
		squel.registerValueHandler(Object, handler)
		squel.registerValueHandler(Object, handler2)

		assert.is_same(1, #squel.cls.globalValueHandlers)
		assert.is_same({ type = Object, handler = handler2 }, squel.cls.globalValueHandlers[1])
	end)
end)

describe('str()', function()
	it('constructor', function()
		local f = squel.str('GETDATE(?)', 12, 23)
		assert.is_equal(true, Object.instanceof(f, squel.cls.FunctionBlock))
		assert.is_equal('GETDATE(?)', f._strings[1])
		assert.is_same({ 12, 23 }, f._values[1])
	end)

	describe('custom value handler', function()
		local handler
		local inst

		before_each(function()
			inst = squel.str('G(?, ?)', 12, 23, 65)

			local handlerConfig = R.findWhere(squel.cls.globalValueHandlers, {
				type = squel.cls.FunctionBlock
			})

			handler = handlerConfig.handler
		end)

		it('toString', function()
			assert.is_equal(handler(inst), inst:toString())
		end)

		it('toParam', function()
			assert.is_same(handler(inst, true), inst:toParam())
		end)
	end)
end)

describe('Load an SQL flavour', function()
	local flavoursBackup

	before_each(function()
		flavoursBackup = squel.flavours
		squel.flavours = {}
	end)

	after_each(function()
		squel.flavours = flavoursBackup
	end)

	it('invalid flavour', function()
		assert.is_error(function()
			squel.useFlavour('test')
		end, 'Flavour not available: test')
	end)

	it('flavour reference should be a function', function()
		squel.flavours.test = 'blah'
		assert.is_error(function()
			squel.useFlavour('test')
		end, 'Flavour not available: test')
	end)

	it('flavour setup function gets executed', function()
		local testSpy = spy.new(function() end)
		squel.flavours.test = function(...) testSpy(...) end
		local ret = squel.useFlavour('test')
		assert.spy(testSpy).is_called(1)
		assert.is_equal(true, not not ret.select())
	end)

	it('can switch flavours', function()
		squel.flavours.test = function(s)
			s.cls.dummy = 1
		end
		squel.flavours.test2 = function(s)
			s.cls.dummy2 = 2
		end
		local ret = squel.useFlavour('test')
		assert.is_equal(1, ret.cls.dummy)

		ret = squel.useFlavour('test2')
		assert.is_equal(nil, ret.cls.dummy)
		assert.is_equal(2, ret.cls.dummy2)

		ret = squel.useFlavour()
		assert.is_equal(nil, ret.cls.dummy)
		assert.is_equal(nil, ret.cls.dummy2)
	end)

	it('can get current flavour', function()
		local flavour = 'test'
		squel.flavours[flavour] = function() end

		local ret = squel.useFlavour(flavour)
		assert.is_equal(flavour, ret.flavour)
	end)

	it('can mix flavours - #255', function()
		squel.flavours.flavour1 = function(s) return s end
		squel.flavours.flavour2 = function(s) return s end
		local squel1 = squel.useFlavour('flavour1')
		local squel2 = squel.useFlavour('flavour2')

		local expr1 = squel1.expr():AND('1 = 1')
		assert.is_equal('SELECT * FROM test `t` WHERE (1 = 1)', squel2.select():from('test', 't'):where(expr1):toString())
	end)
end)

describe('Builder base class', function()
	local cls
	local inst
	local originalHandlers

	before_each(function()
		cls = squel.cls.BaseBuilder
		inst = cls:new()

		originalHandlers = R.clone(squel.cls.globalValueHandlers, true)
	end)

	after_each(function()
		squel.cls.globalValueHandlers = originalHandlers
	end)

	it('instanceof Cloneable', function()
		assert.is_equal(true, Object.instanceof(inst, squel.cls.Cloneable))
	end)

	describe('constructor', function()
		it('default options', function()
			assert.is_same(squel.cls.DefaultQueryBuilderOptions, inst.options)
		end)

		it('overridden options', function()
			inst = cls:new({
				dummy1 = 'str',
				dummy2 = 12.3,
				usingValuePlaceholders = true,
				dummy3 = true,
				globalValueHandlers = { 1 }
			})

			local expectedOptions = R.extend({}, squel.cls.DefaultQueryBuilderOptions, {
				dummy1 = 'str',
				dummy2 = 12.3,
				usingValuePlaceholders = true,
				dummy3 = true,
				globalValueHandlers = { 1 }
			})

			assert.is_same(expectedOptions, inst.options)
		end)
	end)

	describe('registerValueHandler', function()
		after_each(function()
			squel.cls.DefaultQueryBuilderOptions.valueHandlers = {}
		end)

		it('default', function()
			local handler = function() return 'test' end
			inst:registerValueHandler(Object, handler)
			inst:registerValueHandler('number', handler)

			assert.is_equal(2, #inst.options.valueHandlers)
			assert.is_same({ type = Object, handler = handler }, inst.options.valueHandlers[1])
			assert.is_same({ type = 'number', handler = handler }, inst.options.valueHandlers[2])
		end)

		it('type should be class constructor', function()
			assert.is_error(function()
				inst:registerValueHandler(1, nil)
			end, 'type must be a class constructor or string')
		end)

		it('handler should be function', function()
			assert.is_error(function()
				inst:registerValueHandler(Object, 1)
			end, 'handler must be a function')
		end)

		it('returns instance for chainability', function()
			local handler = function() return 'test' end
			assert.is_same(inst, inst:registerValueHandler(Object, handler))
		end)

		it('overrides existing handler', function()
			local handler = function() return 'test' end
			local handler2 = function() return 'test2' end

			inst:registerValueHandler(Object, handler)
			inst:registerValueHandler(Object, handler2)
			assert.is_equal(1, #inst.options.valueHandlers)
			assert.is_same({ type = Object, handler = handler2 }, inst.options.valueHandlers[1])
		end)

		it('does not touch global value handlers list', function()
			local oldGlobalHandlers = squel.cls.globalValueHandlers

			local handler = function() return 'test' end
			inst:registerValueHandler(Object, handler)

			assert.is_same(oldGlobalHandlers, squel.cls.globalValueHandlers)
		end)
	end)

	describe('_sanitizeExpression', function()
		describe('if Expression', function()
			it('empty expression', function()
				local e = squel.expr()
				assert.is_same(e, inst:_sanitizeExpression(e))
			end)

			it('non-empty expression', function()
				local e = squel.expr():AND("s.name <> 'Fred'")
				assert.is_same(e, inst:_sanitizeExpression(e))
			end)
		end)

		it('if Expression', function()
			local s = squel.str('s')
			assert.is_same(s, inst:_sanitizeExpression(s))
		end)

		it('if string', function()
			local s = 'BLA BLA'
			assert.is_equal('BLA BLA', inst:_sanitizeExpression(s))
		end)

		it('if neither expression, builder nor String', function()
			assert.is_error(function()
				inst:_sanitizeExpression(1)
			end, 'expression must be a string or builder instance')
		end)
	end)

	describe('_sanitizeName', function()
		it('if string', function()
			assert.is_equal('bla', inst:_sanitizeName('bla'))
		end)

		it('if boolean', function()
			assert.is_error(function()
				inst:_sanitizeName(true, 'bla')
			end, 'bla must be a string')
		end)

		it('if integer', function()
			assert.is_error(function()
				inst:_sanitizeName(1)
			end, 'nil must be a string')
		end)

		it('if float', function()
			assert.is_error(function()
				inst:_sanitizeName(1.2, 'meh')
			end, 'meh must be a string')
		end)

		it('if array', function()
			assert.is_error(function()
				inst:_sanitizeName({ 1 }, 'yes')
			end, 'yes must be a string')
		end)

		it('if object', function()
			assert.is_error(function()
				inst:_sanitizeName(Object:new(), 'yes')
			end, 'yes must be a string')
		end)

		it('if nil', function()
			assert.is_error(function()
				inst:_sanitizeName(nil, 'no')
			end, 'no must be a string')
		end)
	end)

	describe('_sanitizeField', function()
		it('default', function()
			local sanitizeNameSpy = spy.on(inst, '_sanitizeName')

			assert.is_equal('abc', inst:_sanitizeField('abc'))

			assert.spy(sanitizeNameSpy).is_called_with(match.is_ref(inst), 'abc', 'field name')
			inst._sanitizeName:revert()
		end)

		it('QueryBuilder', function()
			local s = squel.select():from('scores'):field('MAX(score)')
			assert.is_same(s, inst:_sanitizeField(s))
		end)
	end)

	describe('_sanitizeBaseBuilder', function()
		it('is not base builder', function()
			assert.is_error(function()
				inst:_sanitizeBaseBuilder(nil)
			end, 'must be a builder instance')
		end)

		it('is a query builder', function()
			local qry = squel.select()
			assert.is_same(qry, inst:_sanitizeBaseBuilder(qry))
		end)
	end)

	describe('_sanitizeTable', function()
		it('default', function()
			local sanitizeNameSpy = spy.on(inst, '_sanitizeName')

			assert.is_equal('abc', inst:_sanitizeTable('abc'))

			assert.spy(sanitizeNameSpy).is_called_with(match.is_ref(inst), 'abc', 'table')
			inst._sanitizeName:revert()
		end)

		it('not a string', function()
			assert.is_error(function()
				inst:_sanitizeTable(nil)
			end, 'table name must be a string or a builder')
		end)

		it('query builder', function()
			local select = squel.select()
			assert.is_same(select, inst:_sanitizeTable(select, true))
		end)
	end)

	describe('_sanitizeFieldAlias', function()
		it('default', function()
			local sanitizeNameSpy = spy.on(inst, '_sanitizeName')

			inst:_sanitizeFieldAlias('abc')

			assert.spy(sanitizeNameSpy).is_called_with(match.is_ref(inst), 'abc', 'field alias')
			inst._sanitizeName:revert()
		end)
	end)

	describe('_sanitizeTableAlias', function()
		it('default', function()
			local sanitizeNameSpy = spy.on(inst, '_sanitizeName')

			inst:_sanitizeTableAlias('abc')

			assert.spy(sanitizeNameSpy).is_called_with(match.is_ref(inst), 'abc', 'table alias')
			inst._sanitizeName:revert()
		end)
	end)

	describe('_sanitizeLimitOffset', function()
		it('nil', function()
			assert.is_error(function()
				inst:_sanitizeLimitOffset(nil)
			end, 'limit/offset must be >= 0')
		end)

		it('float', function()
			assert.is_equal(1, inst:_sanitizeLimitOffset(1.2))
		end)

		it('boolean', function()
			assert.is_error(function()
				inst:_sanitizeLimitOffset(false)
			end, 'limit/offset must be >= 0')
		end)

		it('string', function()
			assert.is_equal(2, inst:_sanitizeLimitOffset('2'))
		end)

		it('table', function()
			assert.is_error(function()
				inst:_sanitizeLimitOffset({})
			end, 'limit/offset must be >= 0')
		end)

		it('number >= 0', function()
			assert.is_equal(0, inst:_sanitizeLimitOffset(0))
			assert.is_equal(1, inst:_sanitizeLimitOffset(1))
		end)

		it('number < 0', function()
			assert.is_error(function()
				inst:_sanitizeLimitOffset(-1)
			end, 'limit/offset must be >= 0')
		end)
	end)

	describe('_sanitizeValue', function()
		after_each(function()
			squel.cls.globalValueHandlers = {}
		end)

		it('if string', function()
			assert.is_equal('bla', inst:_sanitizeValue('bla'))
		end)

		it('if boolean', function()
			assert.is_equal(true, inst:_sanitizeValue(true))
			assert.is_equal(false, inst:_sanitizeValue(false))
		end)

		it('if integer', function()
			assert.is_equal(-1, inst:_sanitizeValue(-1))
			assert.is_equal(0, inst:_sanitizeValue(0))
			assert.is_equal(1, inst:_sanitizeValue(1))
		end)

		it('if float', function()
			assert.is_equal(-1.2, inst:_sanitizeValue(-1.2))
			assert.is_equal(1.2, inst:_sanitizeValue(1.2))
		end)

		it('if table', function()
			assert.is_error(function()
				inst:_sanitizeValue({})
			end, 'field value must be a string, number, boolean, nil or one of the registered custom value types')
		end)

		it('if nil', function()
			assert.is_equal(nil, inst:_sanitizeValue(nil))
		end)

		it('if BaseBuilder', function()
			local s = squel.select()
			assert.is_same(s, inst:_sanitizeValue(s))
		end)

		describe('custom handlers', function()
			it('global', function()
				squel.registerValueHandler(Object, R.identity)
				local obj = Object:new()
				assert.is_same(obj, inst:_sanitizeValue(obj))
			end)

			it('instance', function()
				inst:registerValueHandler(Object, R.identity)
				local obj = Object:new()
				assert.is_same(obj, inst:_sanitizeValue(obj))
			end)
		end)
	end)

	describe('_escapeValue', function()
		it(function()
			inst.options.replaceSingleQuotes = false
			assert.is_equal("te'st", inst:_escapeValue("te'st"))

			inst.options.replaceSingleQuotes = true
			assert.is_equal("te''st", inst:_escapeValue("te'st"))

			inst.options.singleQuoteReplacement = '--'
			assert.is_equal('te--st', inst:_escapeValue("te'st"))
		end)
	end)

	describe('_formatTableName', function()
		it('default', function()
			assert.is_equal('abc', inst:_formatTableName('abc'))
		end)

		describe('auto quote names', function()
			before_each(function()
				inst.options.autoQuoteTableNames = true
			end)

			it('default quote character', function()
				assert.is_equal('`abc`', inst:_formatTableName('abc'))
			end)

			it('custom quote character', function()
				inst.options.nameQuoteCharacter = '|'
				assert.is_equal('|abc|', inst:_formatTableName('abc'))
			end)
		end)
	end)

	describe('_formatTableAlias', function()
		it('default', function()
			assert.is_equal('`abc`', inst:_formatTableAlias('abc'))
		end)

		it('custom quote character', function()
			inst.options.tableAliasQuoteCharacter = '~'
			assert.is_equal('~abc~', inst:_formatTableAlias('abc'))
		end)

		it('auto quote alias names is OFF', function()
			inst.options.autoQuoteAliasNames = false
			assert.is_equal('abc', inst:_formatTableAlias('abc'))
		end)

		it('AS is turned ON', function()
			inst.options.autoQuoteAliasNames = false
			inst.options.useAsForTableAliasNames = true
			assert.is_equal('AS abc', inst:_formatTableAlias('abc'))
		end)
	end)

	describe('_formatFieldAlias', function()
		it('default', function()
			assert.is_equal('"abc"', inst:_formatFieldAlias('abc'))
		end)

		it('custom quote character', function()
			inst.options.fieldAliasQuoteCharacter = '~'
			assert.is_equal('~abc~', inst:_formatFieldAlias('abc'))
		end)

		it('auto quote alias names is OFF', function()
			inst.options.autoQuoteAliasNames = false
			assert.is_equal('abc', inst:_formatFieldAlias('abc'))
		end)
	end)

	describe('_formatFieldName', function()
		it('default', function()
			assert.is_equal('abc', inst:_formatFieldName('abc'))
		end)

		describe('auto quote names', function()
			before_each(function()
				inst.options.autoQuoteFieldNames = true
			end)

			it('default quote character', function()
				assert.is_equal('`abc`.`def`', inst:_formatFieldName('abc.def'))
			end)

			it('do not quote *', function()
				assert.is_equal('`abc`.*', inst:_formatFieldName('abc.*'))
			end)

			it('custom quote character', function()
				inst.options.nameQuoteCharacter = '|'
				assert.is_equal('|abc|.|def|', inst:_formatFieldName('abc.def'))
			end)

			it('ignore periods when quoting', function()
				assert.is_equal('`abc.def`', inst:_formatFieldName('abc.def', { ignorePeriodsForFieldNameQuotes = true }))
			end)
		end)
	end)

	describe('_formatCustomValue', function()
		after_each(function()
			squel.cls.DefaultQueryBuilderOptions.valueHandlers = {}
		end)

		it('not a custom value type', function()
			assert.is_same({ formatted = false, value = nil }, inst:_formatCustomValue(nil))
			assert.is_same({ formatted = false, value = 'abc' }, inst:_formatCustomValue('abc'))
			assert.is_same({ formatted = false, value = 12 }, inst:_formatCustomValue(12))
			assert.is_same({ formatted = false, value = 1.2 }, inst:_formatCustomValue(1.2))
			assert.is_same({ formatted = false, value = true }, inst:_formatCustomValue(true))
			assert.is_same({ formatted = false, value = false }, inst:_formatCustomValue(false))
		end)

		describe('custom value type', function()
			it('global', function()
				local myObj = Object:new()

				squel.registerValueHandler(Object, function() return 3.14 end)
				squel.registerValueHandler('boolean', function(v) return 'a' .. tostring(v) end)

				assert.is_same({ formatted = true, value = 3.14 }, inst:_formatCustomValue(myObj))
				assert.is_same({ formatted = true, value = 'atrue' }, inst:_formatCustomValue(true))
			end)

			it('instance', function()
				local myObj = Object:new()

				inst:registerValueHandler(Object, function() return 3.14 end)
				inst:registerValueHandler('number', function(v) return tostring(v) .. 'a' end)

				assert.is_same({ formatted = true, value = 3.14 }, inst:_formatCustomValue(myObj))
				assert.is_same({ formatted = true, value = '5.2a' }, inst:_formatCustomValue(5.2))
			end)

			it('instance handler takes precedence over global', function()
				inst:registerValueHandler(Object, function() return 'hello' end)
				squel.registerValueHandler(Object, function() return 'goodbye' end)

				assert.is_same({ formatted = true, value = 'hello' }, inst:_formatCustomValue(Object:new()))

				inst = cls:new({
					valueHandlers = {}
				})
				assert.is_same({ formatted = true, value = 'goodbye' }, inst:_formatCustomValue(Object:new()))
			end)

			it('whether to format for parameterized output', function()
				inst:registerValueHandler(Object, function(_, asParam)
					return asParam and 'foo' or 'bar'
				end)

				local val = Object:new()

				assert.is_same({ formatted = true, value = 'foo' }, inst:_formatCustomValue(val, true))
				assert.is_same({ formatted = true, value = 'bar' }, inst:_formatCustomValue(val))
			end)

			it('additional formatting options', function()
				inst:registerValueHandler(Object, function(_, _, options)
					return options.dontQuote and 'foo' or '"foo"'
				end)

				local val = Object:new()

				assert.is_same({ formatted = true, value = 'foo' }, inst:_formatCustomValue(val, true, { dontQuote = true }))
				assert.is_same({ formatted = true, value = '"foo"' }, inst:_formatCustomValue(val, true, { dontQuote = false }))
			end)
		end)
	end)

	describe('_formatValueForParamArray', function()
		it('Query builder', function()
			local s = squel.select():from('table')
			assert.is_same(s, inst:_formatValueForParamArray(s))
		end)

		it('else calls _formatCustomValue', function()
			local _formatCustomValue = inst._formatCustomValue
			local formatCustomValueSpy = spy.new(function(_, _, asParam)
				return {
					formatted = true,
					value = 'test' .. (asParam and 'foo' or 'bar')
				}
			end)
			inst._formatCustomValue = formatCustomValueSpy

			assert.is_equal('testfoo', inst:_formatValueForParamArray(nil))
			assert.is_equal('testfoo', inst:_formatValueForParamArray('abc'))
			assert.is_equal('testfoo', inst:_formatValueForParamArray(12))
			assert.is_equal('testfoo', inst:_formatValueForParamArray(1.2))

			local opts = { dummy = true }
			assert.is_equal('testfoo', inst:_formatValueForParamArray(true, opts))
			assert.is_equal('testfoo', inst:_formatValueForParamArray(false))

			assert.spy(formatCustomValueSpy).is_called(6)
			assert.spy(formatCustomValueSpy).is_called_with(match.is_ref(inst), match._, match._, opts)
			inst._formatCustomValue = _formatCustomValue
		end)

		it('Array - recursively calls itself on each element', function()
			local formatValueForParamArraySpy = spy.on(inst, '_formatValueForParamArray')

			local v = {
				squel.select():from('table'),
				1.2
			}

			local opts = { dummy = true }
			local res = inst:_formatValueForParamArray(v, opts)

			assert.is_same(v, res)

			assert.spy(formatValueForParamArraySpy).is_called(3)
			assert.spy(formatValueForParamArraySpy).is_called_with(match.is_ref(inst), v[1], opts)
			assert.spy(formatValueForParamArraySpy).is_called_with(match.is_ref(inst), v[2], opts)
			inst._formatValueForParamArray:revert()
		end)
	end)

	describe('_formatValueForQueryString', function()
		it('nil', function()
			assert.is_equal('NULL', inst:_formatValueForQueryString(nil))
		end)

		it('boolean', function()
			assert.is_equal('TRUE', inst:_formatValueForQueryString(true))
			assert.is_equal('FALSE', inst:_formatValueForQueryString(false))
		end)

		it('integer', function()
			assert.is_equal(12, inst:_formatValueForQueryString(12))
		end)

		it('float', function()
			assert.is_equal(1.2, inst:_formatValueForQueryString(1.2))
		end)

		describe('string', function()
			it('NULL', function()
				assert.is_equal('NULL', inst:_formatValueForQueryString('NULL'))
			end)

			it('have string formatter function', function()
				inst.options.stringFormatter = function(str) return 'N(' .. str .. ')' end

				assert.is_equal('N(test)', inst:_formatValueForQueryString('test'))
			end)

			it('default', function()
				local _escapeValue = inst._escapeValue
				local escapedValue = nil
				local escapedValueSpy = spy.new(function(_, str)
					return escapedValue or str
				end)
				inst._escapeValue = escapedValueSpy

				assert.is_equal("'test'", inst:_formatValueForQueryString('test'))
				assert.spy(escapedValueSpy).is_called_with(match.is_ref(inst), 'test')
				escapedValue = 'blah'
				assert.is_equal("'blah'", inst:_formatValueForQueryString('test'))
				inst._escapeValue = _escapeValue
			end)

			it('dont quote', function()
				local _escapeValue = inst._escapeValue
				local escapedValue = nil
				local escapedValueSpy = spy.new(function(_, str)
					return escapedValue or str
				end)
				inst._escapeValue = escapedValueSpy

				assert.is_equal('test', inst:_formatValueForQueryString('test', { dontQuote = true }))
				assert.spy(inst._escapeValue).is_not_called()
				inst._escapeValue = _escapeValue
			end)
		end)

		it('Array - recursively calls itself on each element', function()
			local formatValueForQueryStringSpy = spy.on(inst, '_formatValueForQueryString')

			local expected = "('test', 123, TRUE, 1.2, NULL)"
			assert.is_equal(expected, inst:_formatValueForQueryString({ 'test', 123, true, 1.2, 'NULL' }))

			assert.spy(formatValueForQueryStringSpy).is_called(6)
			assert.spy(formatValueForQueryStringSpy).is_called_with(match.is_ref(inst), 'test')
			assert.spy(formatValueForQueryStringSpy).is_called_with(match.is_ref(inst), 123)
			assert.spy(formatValueForQueryStringSpy).is_called_with(match.is_ref(inst), true)
			assert.spy(formatValueForQueryStringSpy).is_called_with(match.is_ref(inst), 1.2)
			assert.spy(formatValueForQueryStringSpy).is_called_with(match.is_ref(inst), 'NULL')
			inst._formatValueForQueryString:revert()
		end)

		it('BaseBuilder', function()
			local _applyNestingFormatting = inst._applyNestingFormatting
			local applyNestingFormattingSpy = spy.new(function(_, v)
				return '{{' .. v .. '}}'
			end)
			inst._applyNestingFormatting = applyNestingFormattingSpy

			local s = squel.select():from('table')
			assert.is_equal('{{SELECT * FROM table}}', inst:_formatValueForQueryString(s))
			inst._applyNestingFormatting = _applyNestingFormatting
		end)

		it('checks to see if it is custom value type first', function()
			local _formatCustomValue = inst._formatCustomValue
			local _applyNestingFormatting = inst._applyNestingFormatting
			local formatCustomValueSpy = spy.new(function(_, _, asParam)
				return {
					formatted = true,
					value = 12 + (asParam and 25 or 65)
				}
			end)
			local applyNestingFormattingSpy = spy.new(function(_, v)
				return '{' .. v .. '}'
			end)
			inst._formatCustomValue = formatCustomValueSpy
			inst._applyNestingFormatting = applyNestingFormattingSpy

			assert.is_equal('{77}', inst:_formatValueForQueryString(123))
			inst._formatCustomValue = _formatCustomValue
			inst._applyNestingFormatting = _applyNestingFormatting
		end)
	end)

	describe('_applyNestingFormatting', function()
		it('default', function()
			assert.is_same('(77)', inst:_applyNestingFormatting('77'))
			assert.is_same('((77)', inst:_applyNestingFormatting('(77'))
			assert.is_same('(77))', inst:_applyNestingFormatting('77)'))
			assert.is_same('(77)', inst:_applyNestingFormatting('(77)'))
		end)

		it('no nesting', function()
			assert.is_same('77', inst:_applyNestingFormatting('77', false))
		end)
	end)

	describe('_buildString', function()
		it('empty', function()
			assert.is_same({
				text = '',
				values = {},
			}, inst:_buildString('', {}))
		end)

		describe('no params', function()
			it('non-parameterized', function()
				assert.is_same({
					text = 'abc = 3',
					values = {}
				}, inst:_buildString('abc = 3', {}))
			end)

			it('parameterized', function()
				assert.is_same({
					text = 'abc = 3',
					values = {}
				}, inst:_buildString('abc = 3', {}, { buildParameterized = true }))
			end)
		end)

		describe('non-array', function()
			it('non-parameterized', function()
				assert.is_same({
					text = "a = 2 'abc' FALSE NULL",
					values = {}
				}, inst:_buildString('a = ? ? ? ?', { 2, 'abc', false, 'NULL' }))
			end)

			it('parameterized', function()
				assert.is_same({
					text = 'a = ? ? ? ?',
					values = { 2, 'abc', false, 'NULL' }
				}, inst:_buildString('a = ? ? ? ?', { 2, 'abc', false, 'NULL' }, { buildParameterized = true }))
			end)
		end)

		describe('array', function()
			it('non-parameterized', function()
				assert.is_same({
					text = 'a = (1, 2, 3)',
					values = {},
				}, inst:_buildString('a = ?', { { 1, 2, 3 } }))
			end)

			it('parameterized', function()
				assert.is_same({
					text = 'a = (?, ?, ?)',
					values = { 1, 2, 3 }
				}, inst:_buildString('a = ?', { { 1, 2, 3 } }, { buildParameterized = true }))
			end)
		end)

		describe('nested builder', function()
			local s

			before_each(function()
				s = squel.select():from('master'):where('b = ?', 5)
			end)

			it('non-parameterized', function()
				assert.is_same({
					text = 'a = (SELECT * FROM master WHERE (b = 5))',
					values = {}
				}, inst:_buildString('a = ?', { s }))
			end)

			it('parameterized', function()
				assert.is_same({
					text = 'a = (SELECT * FROM master WHERE (b = ?))',
					values = { 5 }
				}, inst:_buildString('a = ?', { s }, { buildParameterized = true }))
			end)
		end)

		describe('return nested output', function()
			it('non-parameterized', function()
				assert.is_same({
					text = '(a = 3)',
					values = {}
				}, inst:_buildString('a = ?', { 3 }, { nested = true }))
			end)

			it('parameterized', function()
				assert.is_same({
					text = '(a = ?)',
					values = { 3 }
				}, inst:_buildString('a = ?', { 3 }, { buildParameterized = true, nested = true }))
			end)
		end)

		it('string formatting options', function()
			local options = {
				formattingOptions = {
					dontQuote = true
				}
			}

			assert.is_same({
				text = 'a = NOW()',
				values = {}
			}, inst:_buildString('a = ?', { 'NOW()' }, options))
		end)

		it('passes formatting options even when doing parameterized query', function()
			local formatValueForParamArraySpy = spy.on(inst, '_formatValueForParamArray')

			local options = {
				buildParameterized = true,
				formattingOptions = {
					dontQuote = true
				}
			}

			inst:_buildString('a = ?', { 3 }, options)

			assert.spy(formatValueForParamArraySpy).is_called_with(match.is_ref(inst), match._, options.formattingOptions)
			inst._formatValueForParamArray:revert()
		end)

		describe('custom parameter character', function()
			before_each(function()
				inst.options.parameterCharacter = '@@'
			end)

			it('non-parameterized', function()
				assert.is_same({
					text = 'a = (1, 2, 3)',
					values = {},
				}, inst:_buildString('a = @@', { { 1, 2, 3 } }))
			end)

			it('parameterized', function()
				assert.is_same({
					text = 'a = (@@, @@, @@)',
					values = { 1, 2, 3 },
				}, inst:_buildString('a = @@', { { 1, 2, 3 } }, { buildParameterized = true }))
			end)
		end)
	end)

	describe('_buildManyStrings', function()
		it('empty', function()
			assert.is_same({
				text = '',
				values = {}
			}, inst:_buildManyStrings({}, {}))
		end)

		describe('simple', function()
			local strings
			local values

			before_each(function()
				strings = {
					'a = ?',
					'b IN ? AND c = ?'
				}

				values = {
					{ 'elephant' },
					{ { 1, 2, 3 }, 4 }
				}
			end)

			it('non-parameterized', function()
				assert.is_same({
					text = "a = 'elephant' b IN (1, 2, 3) AND c = 4",
					values = {},
				}, inst:_buildManyStrings(strings, values))
			end)

			it('parameterized', function()
				assert.is_same({
					text = 'a = ? b IN (?, ?, ?) AND c = ?',
					values = { 'elephant', 1, 2, 3, 4 }
				}, inst:_buildManyStrings(strings, values, { buildParameterized = true }))
			end)
		end)

		describe('return nested', function()
			it('non-parameterized', function()
				assert.is_same({
					text = '(a = 1 b = 2)',
					values = {},
				}, inst:_buildManyStrings({ 'a = ?', 'b = ?' }, { { 1 }, { 2 } }, { nested = true }))
			end)

			it('parameterized', function()
				assert.is_same({
					text = '(a = ? b = ?)',
					values = { 1, 2 },
				}, inst:_buildManyStrings({ 'a = ?', 'b = ?' }, { { 1 }, { 2 } }, { buildParameterized = true, nested = true }))
			end)
		end)

		describe('custom separator', function()
			before_each(function()
				inst.options.separator = '|'
			end)

			it('non-parameterized', function()
				assert.is_same({
					text = 'a = 1|b = 2',
					values = {},
				}, inst:_buildManyStrings({ 'a = ?', 'b = ?' }, { { 1 }, { 2 } }))
			end)

			it('parameterized', function()
				assert.is_same({
					text = 'a = ?|b = ?',
					values = { 1, 2 },
				}, inst:_buildManyStrings({ 'a = ?', 'b = ?' }, { { 1 }, { 2 } }, { buildParameterized = true }))
			end)
		end)
	end)

	it('toParam', function()
		local _toParamString = inst._toParamString
		local toParamStringSpy = spy.new(function()
			return {
				text = 'dummy',
				values = { 1 }
			}
		end)
		inst._toParamString = toParamStringSpy

		local options = { test = 2 }
		assert.is_same({
			text = 'dummy',
			values = { 1 }
		}, inst:toParam(options))
		options = {
			test = 2,
			buildParameterized = true
		}

		assert.spy(toParamStringSpy).is_called(1)
		assert.spy(toParamStringSpy).is_called_with(match.is_ref(inst), match.is_same(options))
		inst._toParamString = _toParamString
	end)

	it('toString', function()
		local _toParamString = inst._toParamString
		local toParamStringSpy = spy.new(function()
			return {
				text = 'dummy',
				values = { 1 }
			}
		end)
		inst._toParamString = toParamStringSpy

		local options = { test = 2 }
		assert.is_equal('dummy', inst:toString(options))

		assert.spy(toParamStringSpy).is_called(1)
		assert.spy(toParamStringSpy).is_called_with(match.is_ref(inst), options)
		inst._toParamString = _toParamString
	end)
end)

describe('QueryBuilder base class', function()
	local cls
	local inst

	before_each(function()
		cls = squel.cls.QueryBuilder
		inst = cls:new()
	end)

	it('instanceof base builder', function()
		assert.is_equal(true, Object.instanceof(inst, squel.cls.BaseBuilder))
	end)

	describe('constructor', function()
		it('default options', function()
			assert.is_same(squel.cls.DefaultQueryBuilderOptions, inst.options)
		end)

		it('overridden options', function()
			inst = cls:new({
				dummy1 = 'str',
				dummy2 = 12.3,
				usingValuePlaceholders = true,
				dummy3 = true
			})

			local expectedOptions = R.extend({}, squel.cls.DefaultQueryBuilderOptions, {
				dummy1 = 'str',
				dummy2 = 12.3,
				usingValuePlaceholders = true,
				dummy3 = true
			})

			assert.is_same(expectedOptions, inst.options)
		end)

		it('default blocks - none', function()
			assert.is_same({}, inst.blocks)
		end)

		describe('blocks passed in', function()
			it('exposes block methods', function()
				local limitExposedMethodsSpy = spy.on(squel.cls.LimitBlock, 'exposedMethods');
				local distinctExposedMethodsSpy = spy.on(squel.cls.DistinctBlock, 'exposedMethods');
				local limit = squel.cls.LimitBlock.limit
				local distinct = squel.cls.DistinctBlock.distinct
				local limitSpy = spy.new(function() end)
				local distinctSpy = spy.new(function() end)
				squel.cls.LimitBlock.limit = function(...) limitSpy(...) end
				squel.cls.DistinctBlock.distinct = function(...) distinctSpy(...) end

				local blocks = {
					squel.cls.LimitBlock:new(),
					squel.cls.DistinctBlock:new()
				}

				inst = cls:new({}, blocks)

				assert.spy(limitExposedMethodsSpy).is_called(1)
				squel.cls.LimitBlock.exposedMethods:revert()
				assert.spy(distinctExposedMethodsSpy).is_called(1)
				squel.cls.DistinctBlock.exposedMethods:revert()

				assert.is_function(inst.limit)
				assert.is_function(inst.distinct)

				assert.is_same(inst, inst:limit(2))
				assert.spy(limitSpy).is_called(1)
				assert.spy(limitSpy).is_called_with(match.is_ref(blocks[1]), 2)
				squel.cls.LimitBlock.limit = limit

				assert.is_same(inst, inst:distinct())
				assert.spy(distinctSpy).is_called(1)
				assert.spy(distinctSpy).is_called_with(match.is_ref(blocks[2]))
				squel.cls.DistinctBlock.distinct = distinct
			end)

			it('cannot expose the same method twice', function()
				local blocks = {
					squel.cls.DistinctBlock:new(),
					squel.cls.DistinctBlock:new()
				}

				assert.is_error(function()
					inst = cls:new({}, blocks)
				end, 'Builder already has a builder method called: distinct')
			end)
		end)
	end)

	describe('updateOptions()', function()
		it('updates query builder options', function()
			local oldOptions = R.extend({}, inst.options)

			inst:updateOptions({
				updated = false
			})

			local expected = R.extend(oldOptions, {
				updated = false
			})

			assert.is_same(expected, inst.options)
		end)

		it('updates building block options', function()
			inst.blocks = {
				squel.cls.Block:new()
			}
			local oldOptions = R.extend({}, inst.blocks[1].options)

			inst:updateOptions({
				updated = false
			})

			local expected = R.extend(oldOptions, {
				updated = false
			})

			assert.is_same(expected, inst.blocks[1].options)
		end)
	end)

	describe('toString()', function()
		it('returns empty if no blocks', function()
			assert.is_equal('', inst:toString())
		end)

		it('skips empty block strings', function()
			inst.blocks = {
				squel.cls.StringBlock:new({}, ''),
			}

			assert.is_equal('', inst:toString())
		end)

		it('returns final query string', function()
			local _toParamString = squel.cls.StringBlock._toParamString
			local i = 1
			local toParamStringSpy = spy.new(function()
				i = i + 1
				return {
					text = 'ret' .. i,
					values = {}
				}
			end)
			squel.cls.StringBlock._toParamString = toParamStringSpy

			inst.blocks = {
				squel.cls.StringBlock:new({}, 'STR1'),
				squel.cls.StringBlock:new({}, 'STR2'),
				squel.cls.StringBlock:new({}, 'STR3')
			}

			assert.is_equal('ret2 ret3 ret4', inst:toString())

			assert.spy(toParamStringSpy).is_called(3)
			assert.spy(toParamStringSpy).is_called_with(match.is_ref(inst.blocks[1]), match._)
			assert.spy(toParamStringSpy).is_called_with(match.is_ref(inst.blocks[2]), match._)
			assert.spy(toParamStringSpy).is_called_with(match.is_ref(inst.blocks[3]), match._)
			squel.cls.StringBlock._toParamString = _toParamString
		end)
	end)

	describe('toParam()', function()
		it('returns empty if no blocks', function()
			assert.is_same({ text = '', values = {} }, inst:toParam())
		end)

		it('skips empty block strings', function()
			inst.blocks = {
				squel.cls.StringBlock:new({}, ''),
			}

			assert.is_same({ text = '', values = {} }, inst:toParam())
		end)

		it('returns final query string', function()
			inst.blocks = {
				squel.cls.StringBlock:new({}, 'STR1'),
				squel.cls.StringBlock:new({}, 'STR2'),
				squel.cls.StringBlock:new({}, 'STR3')
			}

			local _toParamString = squel.cls.StringBlock._toParamString
			local i = 1
			local toParamStringSpy = spy.new(function()
				i = i + 1
				return {
					text = 'ret' .. i,
					values = {}
				}
			end)
			squel.cls.StringBlock._toParamString = toParamStringSpy

			assert.is_same({
				text = 'ret2 ret3 ret4',
				values = {}
			}, inst:toParam())

			assert.spy(toParamStringSpy).is_called(3)
			assert.spy(toParamStringSpy).is_called_with(match.is_ref(inst.blocks[1]), match._)
			assert.spy(toParamStringSpy).is_called_with(match.is_ref(inst.blocks[2]), match._)
			assert.spy(toParamStringSpy).is_called_with(match.is_ref(inst.blocks[3]), match._)
			squel.cls.StringBlock._toParamString = _toParamString
		end)

		it('returns query with unnumbered parameters', function()
			inst.blocks = {
				squel.cls.WhereBlock:new({})
			}

			inst.blocks[1]._toParamString = spy.new(function()
				return {
					text = 'a = ? AND b in (?, ?)',
					values = { 1, 2, 3 }
				}
			end)

			assert.is_same({ text = 'a = ? AND b in (?, ?)', values = { 1, 2, 3 } }, inst:toParam())
		end)

		it('returns query with numbered parameters', function()
			inst = cls:new({
				numberedParameters = true
			})

			inst.blocks = {
				squel.cls.WhereBlock:new({})
			}

			local _toParamString = squel.cls.WhereBlock._toParamString
			local toParamStringSpy = spy.new(function()
				return {
					text = 'a = ? AND b in (?, ?)',
					values = { 1, 2, 3 }
				}
			end)
			squel.cls.WhereBlock._toParamString = toParamStringSpy

			assert.is_same({
				text = 'a = $1 AND b in ($2, $3)',
				values = { 1, 2, 3 }
			}, inst:toParam())
			squel.cls.WhereBlock._toParamString = _toParamString
		end)

		it('returns query with numbered parameters and custom prefix', function()
			inst = cls:new({
				numberedParameters = true,
				numberedParametersPrefix = '&%'
			})

			inst.blocks = {
				squel.cls.WhereBlock:new({})
			}

			local _toParamString = squel.cls.WhereBlock._toParamString
			local toParamStringSpy = spy.new(function()
				return {
					text = 'a = ? AND b in (?, ?)',
					values = { 1, 2, 3 }
				}
			end)
			squel.cls.WhereBlock._toParamString = toParamStringSpy

			assert.is_same({
				text = 'a = &%1 AND b in (&%2, &%3)',
				values = { 1, 2, 3 }
			}, inst:toParam())
			squel.cls.WhereBlock._toParamString = _toParamString
		end)
	end)

	describe('cloning', function()
		it('blocks get cloned properly', function()
			inst.blocks = {
				squel.cls.StringBlock:new({}, 'TEST')
			}

			local newinst = inst:clone()
			inst.blocks[1].str = 'TEST2'

			assert.is_equal('TEST', newinst.blocks[1]:toString())
		end)
	end)

	describe('registerValueHandler', function()
		local originalHandlers

		before_each(function()
			originalHandlers = R.clone(squel.cls.globalValueHandlers, true)
		end)

		after_each(function()
			squel.cls.globalValueHandlers = originalHandlers
		end)

		it('calls through to base class method', function()
			local baseBuilderSpy = spy.on(squel.cls.BaseBuilder, 'registerValueHandler')

			local handler = function() return 'test' end
			inst:registerValueHandler(Object, handler)
			inst:registerValueHandler('number', handler)

			assert.spy(baseBuilderSpy).is_called(2)
			assert.spy(baseBuilderSpy).is_called_with(match.is_ref(inst), match._, match._)
			squel.cls.BaseBuilder.registerValueHandler:revert()
		end)

		it('returns instance for chainability', function()
			local handler = function() return 'test' end
			assert.is_same(inst, inst:registerValueHandler(Object, handler))
		end)

		it('calls through to blocks', function()
			inst.blocks = {
				squel.cls.StringBlock:new({}, ''),
			}

			local baseBuilderSpy = spy.on(inst.blocks[1], 'registerValueHandler')

			local handler = function() return 'test' end
			inst:registerValueHandler(Object, handler)

			assert.spy(baseBuilderSpy).is_called(1)
			assert.spy(baseBuilderSpy).is_called_with(match.is_ref(inst.blocks[1]), match._, match._)
			inst.blocks[1].registerValueHandler:revert()
		end)
	end)

	describe('get block', function()
		it('valid', function()
			local block = squel.cls.FunctionBlock:new()
			table.insert(inst.blocks, block)
			assert.is_same(block, inst:getBlock(squel.cls.FunctionBlock))
		end)

		it('invalid', function()
			assert.is_equal(nil, inst:getBlock(squel.cls.FunctionBlock))
		end)
	end)
end)
