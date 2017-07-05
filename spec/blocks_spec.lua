describe('Blocks', function()
	local match = require('luassert.match')
	local Object = require('object')
	local R = require('moses')
	local squel = require('squel')

	local cls
	local inst

	describe('Block base class', function()
		before_each(function()
			inst = squel.cls.Block:new()
		end)

		it('instanceof BaseBuilder', function()
			assert.is_equal(true, Object.instanceof(inst, squel.cls.BaseBuilder))
		end)

		it('options', function()
			local expectedOptions = R.extend({}, squel.cls.DefaultQueryBuilderOptions, {
				usingValuePlaceholders = true,
				dummy = true
			})

			inst = squel.cls.Block:new({
				usingValuePlaceholders = true,
				dummy = true
			})

			assert.is_same(expectedOptions, inst.options)
		end)

		it('_toParamString()', function()
			assert.is_error(function()
				inst:toString()
			end, 'Not yet implemented')
		end)

		describe('exposedMethods()', function()
			it('returns methods', function()
				inst.method1 = function() return false end
				inst.method2 = function() return false end

				assert.is_equal(inst.method1, inst:exposedMethods().method1)
				assert.is_equal(inst.method2, inst:exposedMethods().method2)
			end)

			it('ignores methods prefixed with _', function()
				inst._method = function() return false end

				assert.is_equal(nil, inst:exposedMethods()._method)
			end)

			it('ignores toString()', function()
				assert.is_equal(nil, inst:exposedMethods().toString)
			end)
		end)

		it('cloning copies the options over', function()
			inst.options.dummy = true

			local newinst = inst:clone()

			inst.options.dummy = false

			assert.is_equal(true, newinst.options.dummy)
		end)
	end)

	describe('StringBlock', function()
		before_each(function()
			cls = squel.cls.StringBlock
			inst = cls:new()
		end)

		it('instanceof of Block', function()
			assert.is_equal(true, Object.instanceof(inst, squel.cls.Block))
		end)

		describe('_toParamString()', function()
			it('non-parameterized', function()
				inst = cls:new({}, 'TAG')

				assert.is_same({
					text = 'TAG',
					values = {}
				}, inst:_toParamString())
			end)

			it('parameterized', function()
				inst = cls:new({}, 'TAG')

				assert.is_same({
					text = 'TAG',
					values = {}
				}, inst:_toParamString({ buildParameterized = true }))
			end)
		end)
	end)

	describe('FunctionBlock', function()
		before_each(function()
			cls = squel.cls.FunctionBlock
			inst = cls:new()
		end)

		it('instanceof of Block', function()
			assert.is_equal(true, Object.instanceof(inst, squel.cls.Block))
		end)

		it('initial member values', function()
			assert.is_same({}, inst._values)
			assert.is_same({}, inst._strings)
		end)

		describe('_toParamString()', function()
			it('when not set', function()
				assert.is_same({
					text = '',
					values = {}
				}, inst:_toParamString())
			end)

			it('non-parameterized', function()
				inst:FUNCTION('bla')
				inst:FUNCTION('bla2')

				assert.is_same({
					text = 'bla bla2',
					values = {}
				}, inst:_toParamString())
			end)

			it('parameterized', function()
				inst:FUNCTION('bla ?', 2)
				inst:FUNCTION('bla2 ?', 3)

				assert.is_same({
					text = 'bla ? bla2 ?',
					values = { 2, 3 }
				}, inst:_toParamString({ buildParameterized = true }))
			end)
		end)
	end)

	describe('AbstractTableBlock', function()
		before_each(function()
			cls = squel.cls.AbstractTableBlock
			inst = cls:new()
		end)

		it('instanceof of Block', function()
			assert.is_equal(true, Object.instanceof(inst, squel.cls.Block))
		end)

		it('initial field values', function()
			assert.is_same({}, inst._tables)
		end)

		describe('has table', function()
			it('no', function()
				assert.is_equal(false, inst:_hasTable())
			end)

			it('yes', function()
				inst:_table('blah')
				assert.is_equal(true, inst:_hasTable())
			end)
		end)

		describe('_table()', function()
			it('saves inputs', function()
				inst:_table('table1')
				inst:_table('table2', 'alias2')
				inst:_table('table3')

				local expectedFroms = {
					{
						table = 'table1',
						alias = nil
					},
					{
						table = 'table2',
						alias = 'alias2'
					},
					{
						table = 'table3',
						alias = nil
					}
				}

				assert.is_same(expectedFroms, inst._tables)
			end)

			it('sanitizes inputs', function()
				local sanitizeTableSpy = spy.on(cls, '_sanitizeTable')
				local sanitizeAliasSpy = spy.on(cls, '_sanitizeTableAlias')

				inst:_table('table', 'alias')

				assert.spy(sanitizeTableSpy).is_called_with(match.is_ref(inst), 'table')
				cls._sanitizeTable:revert()
				assert.spy(sanitizeAliasSpy).is_called_with(match.is_ref(inst), 'alias')
				cls._sanitizeTableAlias:revert()

				assert.is_same({{
					table = 'table',
					alias = 'alias'
				}}, inst._tables)
			end)

			it('handles single-table mode', function()
				inst.options.singleTable = true

				inst:_table('table1')
				inst:_table('table2')
				inst:_table('table3')

				local expected = {
					{
						table = 'table3',
						alias = nil
					}
				}

				assert.is_same(expected, inst._tables)
			end)

			it('builder as table', function()
				local sanitizeTableSpy = spy.on(cls, '_sanitizeTable')

				local innerTable1 = squel.select()
				local innerTable2 = squel.select()

				inst:_table(innerTable1)
				inst:_table(innerTable2, 'Inner2')

				assert.spy(sanitizeTableSpy).is_called_with(match.is_ref(inst), innerTable1)
				assert.spy(sanitizeTableSpy).is_called_with(match.is_ref(inst), innerTable2)
				cls._sanitizeTable:revert()

				assert.is_same({{
					alias = nil,
					table = innerTable1
				}, {
					alias = 'Inner2',
					table = innerTable2
				}}, inst._tables)
			end)
		end)

		describe('_toParamString()', function()
			local innerTable1

			before_each(function()
				innerTable1 = squel.select():from('inner1'):where('a = ?', 3)
			end)

			it('no table', function()
				assert.is_same({
					text = '',
					values = {}
				}, inst:_toParamString())
			end)

			it('prefix', function()
				inst.options.prefix = 'TEST'

				inst:_table('table2', 'alias2')

				assert.is_same({
					text = 'TEST table2 `alias2`',
					values = {}
				}, inst:_toParamString())
			end)

			it('non-parameterized', function()
				inst:_table(innerTable1)
				inst:_table('table2', 'alias2')
				inst:_table('table3')

				assert.is_same({
					text = '(SELECT * FROM inner1 WHERE (a = 3)), table2 `alias2`, table3',
					values = {}
				}, inst:_toParamString())
			end)

			it('parameterized', function()
				inst:_table(innerTable1)
				inst:_table('table2', 'alias2')
				inst:_table('table3')

				assert.is_same({
					text = '(SELECT * FROM inner1 WHERE (a = ?)), table2 `alias2`, table3',
					values = { 3 }
				}, inst:_toParamString({ buildParameterized = true }))
			end)
		end)
	end)

	describe('FromTableBlock', function()
		before_each(function()
			cls = squel.cls.FromTableBlock
			inst = cls:new()
		end)

		it('check prefix', function()
			assert.is_equal(inst.options.prefix, 'FROM')
		end)

		it('instanceof of AbstractTableBlock', function()
			assert.is_equal(true, Object.instanceof(inst, squel.cls.AbstractTableBlock))
		end)

		describe('from()', function()
			it('calls base class handler', function()
				local baseMethodSpy = spy.on(squel.cls.AbstractTableBlock, '_table')

				inst:from('table1')
				inst:from('table2', 'alias2')

				assert.spy(baseMethodSpy).is_called(2)
				assert.spy(baseMethodSpy).is_called_with(match.is_ref(inst), 'table1', nil)
				assert.spy(baseMethodSpy).is_called_with(match.is_ref(inst), 'table2', 'alias2')
				squel.cls.AbstractTableBlock._table:revert()
			end)
		end)
	end)

	describe('UpdateTableBlock', function()
		before_each(function()
			cls = squel.cls.UpdateTableBlock
			inst = cls:new()
		end)

		it('instanceof of AbstractTableBlock', function()
			assert.is_equal(true, Object.instanceof(inst, squel.cls.AbstractTableBlock))
		end)

		it('check prefix', function()
			assert.is_equal(nil, inst.options.prefix)
		end)

		describe('table()', function()
			it('calls base class handler', function()
				local baseMethodSpy = spy.on(squel.cls.AbstractTableBlock, '_table')

				inst:table('table1')
				inst:table('table2', 'alias2')

				assert.spy(baseMethodSpy).is_called(2)
				assert.spy(baseMethodSpy).is_called_with(match.is_ref(inst), 'table1', nil)
				assert.spy(baseMethodSpy).is_called_with(match.is_ref(inst), 'table2', 'alias2')
				squel.cls.AbstractTableBlock._table:revert()
			end)
		end)
	end)

	describe('TargetTableBlock', function()
		before_each(function()
			cls = squel.cls.TargetTableBlock
			inst = cls:new()
		end)

		it('instanceof of AbstractTableBlock', function()
			assert.is_equal(true, Object.instanceof(inst, squel.cls.AbstractTableBlock))
		end)

		it('check prefix', function()
			assert.is_equal(nil, inst.options.prefix)
		end)

		describe('table()', function()
			it('calls base class handler', function()
				local baseMethodSpy = spy.on(squel.cls.AbstractTableBlock, '_table')

				inst:target('table1')
				inst:target('table2')

				assert.spy(baseMethodSpy).is_called(2)
				assert.spy(baseMethodSpy).is_called_with(match.is_ref(inst), 'table1')
				assert.spy(baseMethodSpy).is_called_with(match.is_ref(inst), 'table2')
				squel.cls.AbstractTableBlock._table:revert()
			end)
		end)
	end)

	describe('IntoTableBlock', function()
		before_each(function()
			cls = squel.cls.IntoTableBlock
			inst = cls:new()
		end)

		it('instanceof of AbstractTableBlock', function()
			assert.is_equal(true, Object.instanceof(inst, squel.cls.AbstractTableBlock))
		end)

		it('check prefix', function()
			assert.is_equal('INTO', inst.options.prefix)
		end)

		it('single table', function()
			assert.is_equal(true, inst.options.singleTable)
		end)

		describe('into()', function()
			it('calls base class handler', function()
				local baseMethodSpy = spy.on(squel.cls.AbstractTableBlock, '_table')

				inst:into('table1')
				inst:into('table2')

				assert.spy(baseMethodSpy).is_called(2)
				assert.spy(baseMethodSpy).is_called_with(match.is_ref(inst), 'table1')
				assert.spy(baseMethodSpy).is_called_with(match.is_ref(inst), 'table2')
				squel.cls.AbstractTableBlock._table:revert()
			end)
		end)

		describe('_toParamString()', function()
			it('requires table to have been provided', function()
				assert.is_error(function()
					inst:_toParamString()
				end, 'into() needs to be called')
			end)
		end)
	end)

	describe('GetFieldBlock', function()
		before_each(function()
			cls = squel.cls.GetFieldBlock
			inst = cls:new()
		end)

		it('instanceof of Block', function()
			assert.is_equal(true, Object.instanceof(inst, squel.cls.Block))
		end)

		describe('fields() - object', function()
			it('saves inputs', function()
				local fieldSpy = spy.on(inst, 'field')

				inst:fields({
					field1 = 'NULL',
					field2 = 'alias2',
					field3 = 'NULL',
				}, { dummy = true })

				assert.spy(fieldSpy).is_called(3)
				assert.spy(fieldSpy).is_called_with(match.is_ref(inst), 'field1', nil, { dummy = true })
				assert.spy(fieldSpy).is_called_with(match.is_ref(inst), 'field2', 'alias2', { dummy = true })
				assert.spy(fieldSpy).is_called_with(match.is_ref(inst), 'field3', nil, { dummy = true })
				inst.field:revert()

				assert.is_same({{
					name = 'field1',
					alias = nil,
					options = {
						dummy = true
					}
				}, {
					name = 'field3',
					alias = nil,
					options = {
						dummy = true
					}
				}, {
					name = 'field2',
					alias = 'alias2',
					options = {
						dummy = true
					}
				}}, inst._fields)
			end)
		end)

		describe('fields() - array', function()
			it('saves inputs', function()
				local fieldSpy = spy.on(inst, 'field')

				inst:fields({ 'field1', 'field2', 'field3' }, { dummy = true })

				assert.spy(fieldSpy).is_called(3)
				assert.spy(fieldSpy).is_called_with(match.is_ref(inst), 'field1', nil, { dummy = true })
				assert.spy(fieldSpy).is_called_with(match.is_ref(inst), 'field2', nil, { dummy = true })
				assert.spy(fieldSpy).is_called_with(match.is_ref(inst), 'field3', nil, { dummy = true })
				inst.field:revert()

				assert.is_same({{
					name = 'field1',
					alias = nil,
					options = {
						dummy = true
					}
				}, {
					name = 'field2',
					alias = nil,
					options = {
						dummy = true
					}
				}, {
					name = 'field3',
					alias = nil,
					options = {
						dummy = true
					}
				}}, inst._fields)
			end)
		end)

		describe('field()', function()
			it('saves inputs', function()
				inst:field('field1')
				inst:field('field2', 'alias2')
				inst:field('field3')

				local expected = {
					{
						name = 'field1',
						alias = nil,
						options = {}
					},
					{
						name = 'field2',
						alias = 'alias2',
						options = {}
					},
					{
						name = 'field3',
						alias = nil,
						options = {}
					}
				}

				assert.is_same(expected, inst._fields)
			end)
		end)

		describe('field() - discard duplicates', function()
			it('saves inputs', function()
				inst:field('field1')
				inst:field('field2', 'alias2')
				inst:field('field2', 'alias2')
				inst:field('field1', 'alias1')

				local expected = {
					{
						name = 'field1',
						alias = nil,
						options = {}
					},
					{
						name = 'field2',
						alias = 'alias2',
						options = {}
					},
					{
						name = 'field1',
						alias = 'alias1',
						options = {}
					}
				}

				assert.is_same(expected, inst._fields)
			end)

			it('sanitizes inputs', function()
				local sanitizeFieldSpy = spy.on(cls, '_sanitizeField')
				local sanitizeAliasSpy = spy.on(cls, '_sanitizeFieldAlias')

				inst:field('field1', 'alias1', { dummy = true })

				assert.spy(sanitizeFieldSpy).is_called_with(match.is_ref(inst), 'field1')
				cls._sanitizeField:revert()
				assert.spy(sanitizeAliasSpy).is_called_with(match.is_ref(inst), 'alias1')
				cls._sanitizeFieldAlias:revert()

				assert.is_same({{
					name = 'field1',
					alias = 'alias1',
					options = {
						dummy = true
					}
				}}, inst._fields)
			end)
		end)

		describe('_toParamString()', function()
			local queryBuilder
			local fromTableBlock

			before_each(function()
				queryBuilder = squel.select()
				fromTableBlock = queryBuilder:getBlock(squel.cls.FromTableBlock)
			end)

			it('returns all fields when none provided and table is set', function()
				fromTableBlock._hasTable = function() return true end

				assert.is_same({
					text = '*',
					values = {}
				}, inst:_toParamString({ queryBuilder = queryBuilder }))
			end)

			it('but returns nothing if no table set', function()
				fromTableBlock._hasTable = function() return false end

				assert.is_same({
					text = '',
					values = {}
				}, inst:_toParamString({ queryBuilder = queryBuilder }))
			end)

			describe('returns formatted query phrase', function()
				before_each(function()
					fromTableBlock._hasTable = function() return true end
					inst:field(squel.str('GETDATE(?)', 3), 'alias1')
					inst:field('field2', 'alias2', { dummy = true })
					inst:field('field3')
				end)

				it('non-parameterized', function()
					assert.is_same({
						text = '(GETDATE(3)) AS "alias1", field2 AS "alias2", field3',
						values = {}
					}, inst:_toParamString({ queryBuilder = queryBuilder }))
				end)

				it('parameterized', function()
					assert.is_same({
						text = '(GETDATE(?)) AS "alias1", field2 AS "alias2", field3',
						values = { 3 }
					}, inst:_toParamString({ queryBuilder = queryBuilder, buildParameterized = true }))
				end)
			end)
		end)
	end)

	describe('AbstractSetFieldBlock', function()
		before_each(function()
			cls = squel.cls.AbstractSetFieldBlock
			inst = cls:new()
		end)

		it('instanceof of Block', function()
			assert.is_equal(true, Object.instanceof(inst, squel.cls.Block))
		end)

		describe('_set()', function()
			it('saves inputs', function()
				inst:_set('field1', 'value1', { dummy = 1 })
				inst:_set('field2', 'value2', { dummy = 2 })
				inst:_set('field3', 'value3', { dummy = 3 })
				inst:_set('field4', 'NULL')

				local expectedFields = { 'field1', 'field2', 'field3', 'field4' }
				local expectedValues = { { 'value1', 'value2', 'value3', 'NULL' } }
				local expectedFieldOptions = { { { dummy = 1 }, { dummy = 2 }, { dummy = 3 }, {} } }

				assert.is_same(expectedFields, inst._fields)
				assert.is_same(expectedValues, inst._values)
				assert.is_same(expectedFieldOptions, inst._valueOptions)
			end)

			it('sanitizes inputs', function()
				local sanitizeFieldSpy = spy.on(cls, '_sanitizeField')
				local sanitizeValueSpy = spy.on(cls, '_sanitizeValue')

				inst:_set('field1', 'value1', { dummy = true })

				assert.spy(sanitizeFieldSpy).is_called_with(match.is_ref(inst), 'field1')
				cls._sanitizeField:revert()
				assert.spy(sanitizeValueSpy).is_called_with(match.is_ref(inst), 'value1')
				cls._sanitizeValue:revert()

				assert.is_same({ 'field1' }, inst._fields)
				assert.is_same({ { 'value1' } }, inst._values)
			end)
		end)

		describe('_setFields()', function()
			it('saves inputs', function()
				inst:_setFields({
					field1 = 'value1',
					field2 = 'value2',
					field3 = 'value3'
				})

				local expectedFields = { 'field1', 'field3', 'field2' }
				local expectedValues = { { 'value1', 'value3', 'value2' } }
				local expectedFieldOptions = { { {}, {}, {} } }

				assert.is_same(expectedFields, inst._fields)
				assert.is_same(expectedValues, inst._values)
				assert.is_same(expectedFieldOptions, inst._valueOptions)
			end)

			it('sanitizes inputs', function()
				local sanitizeFieldSpy = spy.on(cls, '_sanitizeField')
				local sanitizeValueSpy = spy.on(cls, '_sanitizeValue')

				inst:_setFields({ field1 = 'value1' }, { dummy = true })

				assert.spy(sanitizeFieldSpy).is_called_with(match.is_ref(inst), 'field1')
				cls._sanitizeField:revert()
				assert.spy(sanitizeValueSpy).is_called_with(match.is_ref(inst), 'value1')
				cls._sanitizeValue:revert()

				assert.is_same({ 'field1' }, inst._fields)
				assert.is_same({ { 'value1' } }, inst._values)
			end)
		end)

		describe('_setFieldsRows()', function()
			it('saves inputs', function()
				inst:_setFieldsRows({
					{
						field1 = 'value1',
						field2 = 'value2',
						field3 = 'value3'
					},
					{
						field1 = 'value21',
						field2 = 'value22',
						field3 = 'value23'
					}
				})

				local expectedFields = { 'field1', 'field3', 'field2' }
				local expectedValues = { { 'value1', 'value3', 'value2' }, { 'value21', 'value23', 'value22' } }
				local expectedFieldOptions = { { {}, {}, {} }, { {}, {}, {} } }

				assert.is_same(expectedFields, inst._fields)
				assert.is_same(expectedValues, inst._values)
				assert.is_same(expectedFieldOptions, inst._valueOptions)
			end)

			it('sanitizes inputs', function()
				local sanitizeFieldSpy = spy.on(cls, '_sanitizeField')
				local sanitizeValueSpy = spy.on(cls, '_sanitizeValue')

				inst:_setFieldsRows({{
					field1 = 'value1'
				}, {
					field1 = 'value21'
				}}, { dummy = true })

				assert.spy(sanitizeFieldSpy).is_called_with(match.is_ref(inst), 'field1')
				cls._sanitizeField:revert()
				assert.spy(sanitizeValueSpy).is_called_with(match.is_ref(inst), 'value1')
				assert.spy(sanitizeValueSpy).is_called_with(match.is_ref(inst), 'value21')
				cls._sanitizeValue:revert()

				assert.is_same({ 'field1' }, inst._fields)
				assert.is_same({ { 'value1' }, { 'value21' } }, inst._values)
			end)
		end)

		it('_toParamString()', function()
			assert.is_error(function()
				inst:_toParamString()
			end, 'Not yet implemented')
		end)
	end)

	describe('SetFieldBlock', function()
		before_each(function()
			cls = squel.cls.SetFieldBlock
			inst = cls:new()
		end)

		it('instanceof of AbstractSetFieldBlock', function()
			assert.is_equal(true, Object.instanceof(inst, squel.cls.AbstractSetFieldBlock))
		end)

		describe('set()', function()
			it('calls to _set()', function()
				local setSpy = spy.on(inst, '_set')

				inst:set('f', 'v', { dummy = true })

				assert.spy(setSpy).is_called_with(match.is_ref(inst), 'f', 'v', { dummy = true })
				inst._set:revert()
			end)
		end)

		describe('setFields()', function()
			it('calls to _setFields()', function()
				local setFieldsSpy = stub(inst, '_setFields')

				inst:setFields('f', { dummy = true })

				assert.stub(setFieldsSpy).is_called_with(match.is_ref(inst), 'f', { dummy = true })
				inst._setFields:revert()
			end)
		end)

		describe('_toParamString()', function()
			it('needs at least one field to have been provided', function()
				assert.is_error(function()
					inst:toString()
				end, 'set() needs to be called')
			end)

			describe('fields set', function()
				before_each(function()
					inst:set('field0 = field0 + 1')
					inst:set('field1', 'value1', { dummy = true })
					inst:set('field2', 'value2')
					inst:set('field3', squel.str('GETDATE(?)', 4))
				end)

				it('non-parameterized', function()
					assert.is_same({
						text = "SET field0 = field0 + 1, field1 = 'value1', field2 = 'value2', field3 = (GETDATE(4))",
						values = {},
					}, inst:_toParamString())
				end)

				it('parameterized', function()
					assert.is_same({
						text = 'SET field0 = field0 + 1, field1 = ?, field2 = ?, field3 = (GETDATE(?))',
						values = { 'value1', 'value2', 4 },
					}, inst:_toParamString({ buildParameterized = true }))
				end)
			end)
		end)
	end)

	describe('InsertFieldValueBlock', function()
		before_each(function()
			cls = squel.cls.InsertFieldValueBlock
			inst = cls:new()
		end)

		it('instanceof of AbstractSetFieldBlock', function()
			assert.is_equal(true, Object.instanceof(inst, squel.cls.AbstractSetFieldBlock))
		end)

		describe('set()', function()
			it('calls to _set()', function()
				local setSpy = spy.on(inst, '_set')

				inst:set('f', 'v', { dummy = true })

				assert.spy(setSpy).is_called_with(match.is_ref(inst), 'f', 'v', { dummy = true })
				inst._set:revert()
			end)
		end)

		describe('setFields()', function()
			it('calls to _setFields()', function()
				local setFieldsSpy = stub(inst, '_setFields')

				inst:setFields('f', { dummy = true })

				assert.stub(setFieldsSpy).is_called_with(match.is_ref(inst), 'f', { dummy = true })
				inst._setFields:revert()
			end)
		end)

		describe('setFieldsRows()', function()
			it('calls to _setFieldsRows()', function()
				local setFieldsRowsSpy = stub(inst, '_setFieldsRows')

				inst:setFieldsRows('f', { dummy = true })

				assert.stub(setFieldsRowsSpy).is_called_with(match.is_ref(inst), 'f', { dummy = true })
				inst._setFieldsRows:revert()
			end)
		end)

		describe('_toParamString()', function()
			it('needs at least one field to have been provided', function()
				assert.is_equal('', inst:toString())
			end)

			describe('got fields', function()
				before_each(function()
					inst:setFieldsRows({
						{ field1 = 9, field2 = 'value2', field3 = squel.str('GETDATE(?)', 5) },
						{ field1 = 8, field2 = true, field3 = 'NULL' }
					})
				end)

				it('non-parameterized', function()
					assert.is_same({
						text = "(field1, field3, field2) VALUES (9, (GETDATE(5)), 'value2'), (8, NULL, TRUE)",
						values = {},
					}, inst:_toParamString())
				end)

				it('parameterized', function()
					assert.is_same({
						text = '(field1, field3, field2) VALUES (?, (GETDATE(?)), ?), (?, ?, ?)',
						values = { 9, 5, 'value2', 8, 'NULL', true },
					}, inst:_toParamString({ buildParameterized = true }))
				end)
			end)
		end)
	end)

	describe('InsertFieldsFromQueryBlock', function()
		before_each(function()
			cls = squel.cls.InsertFieldsFromQueryBlock
			inst = cls:new()
		end)

		it('instanceof of Block', function()
			assert.is_equal(true, Object.instanceof(inst, squel.cls.Block))
		end)

		describe('fromQuery()', function()
			it('sanitizes field names', function()
				local sanitizeFieldSpy = spy.on(inst, '_sanitizeField')

				local qry = squel.select()

				inst:fromQuery({ 'test', 'one', 'two' }, qry)

				assert.spy(sanitizeFieldSpy).is_called(3)
				assert.spy(sanitizeFieldSpy).is_called_with(match.is_ref(inst), 'test')
				assert.spy(sanitizeFieldSpy).is_called_with(match.is_ref(inst), 'one')
				assert.spy(sanitizeFieldSpy).is_called_with(match.is_ref(inst), 'two')
				inst._sanitizeField:revert()
			end)

			it('sanitizes query', function()
				local sanitizeBaseBuilderSpy = stub(inst, '_sanitizeBaseBuilder')

				local qry = 123

				inst:fromQuery({ 'test', 'one', 'two' }, qry)

				assert.stub(sanitizeBaseBuilderSpy).is_called(1)
				assert.stub(sanitizeBaseBuilderSpy).is_called_with(match.is_ref(inst), qry)
				inst._sanitizeBaseBuilder:revert()
			end)

			it('overwrites existing values', function()
				inst._fields = 1
				inst._query = 2

				local qry = squel.select()
				inst:fromQuery({ 'test', 'one', 'two' }, qry)

				assert.is_same(qry, inst._query)
				assert.is_same({ 'test', 'one', 'two' }, inst._fields)
			end)
		end)

		describe('_toParamString()', function()
			it('needs fromQuery() to have been called', function()
				assert.is_same({
					text = '',
					values = {}
				}, inst:_toParamString())
			end)

			describe('default', function()
				before_each(function()
					local qry = squel.select():from('mega'):where('a = ?', 5)
					inst:fromQuery({ 'test', 'one', 'two' }, qry)
				end)

				it('non-parameterized', function()
					assert.is_same({
						text = '(test, one, two) (SELECT * FROM mega WHERE (a = 5))',
						values = {}
					}, inst:_toParamString())
				end)

				it('parameterized', function()
					assert.is_same({
						text = '(test, one, two) (SELECT * FROM mega WHERE (a = ?))',
						values = { 5 }
					}, inst:_toParamString({ buildParameterized = true }))
				end)
			end)
		end)
	end)

	describe('DistinctBlock', function()
		before_each(function()
			cls = squel.cls.DistinctBlock
			inst = cls:new()
		end)

		it('instanceof of Block', function()
			assert.is_equal(true, Object.instanceof(inst, squel.cls.Block))
		end)

		describe('_toParamString()', function()
			it('output nothing if not set', function()
				assert.is_same({
					text = '',
					values = {}
				}, inst:_toParamString())
			end)

			it('output DISTINCT if set', function()
				inst:distinct()
				assert.is_same({
					text = 'DISTINCT',
					values = {}
				}, inst:_toParamString())
			end)
		end)
	end)

	describe('GroupByBlock', function()
		before_each(function()
			cls = squel.cls.GroupByBlock
			inst = cls:new()
		end)

		it('instanceof of Block', function()
			assert.is_equal(true, Object.instanceof(inst, squel.cls.Block))
		end)

		describe('group()', function()
			it('adds to list', function()
				inst:group('field1')
				inst:group('field2')

				assert.is_same({ 'field1', 'field2' }, inst._groups)
			end)

			it('sanitizes inputs', function()
				local sanitizeFieldSpy = spy.on(cls, '_sanitizeField')

				inst:group('field1')

				assert.spy(sanitizeFieldSpy).is_called_with(match.is_ref(inst), 'field1')
				cls._sanitizeField:revert()

				assert.is_same({ 'field1' }, inst._groups)
			end)
		end)

		describe('toString()', function()
			it('output nothing if no fields set', function()
				inst._groups = {}
				assert.is_equal('', inst:toString())
			end)

			it('output GROUP BY', function()
				inst:group('field1')
				inst:group('field2')

				assert.is_equal('GROUP BY field1, field2', inst:toString())
			end)
		end)
	end)

	describe('AbstractVerbSingleValueBlock', function()
		before_each(function()
			cls = squel.cls.AbstractVerbSingleValueBlock
			inst = cls:new({
				verb = 'TEST'
			})
		end)

		it('instanceof of Block', function()
			assert.is_equal(true, Object.instanceof(inst, squel.cls.Block))
		end)

		describe('offset()', function()
			it('set value', function()
				inst:_setValue(1)

				assert.is_equal(1, inst._value)

				inst:_setValue(22)

				assert.is_equal(22, inst._value)
			end)

			it('sanitizes inputs', function()
				local sanitizeSpy = spy.on(cls, '_sanitizeLimitOffset')

				inst:_setValue(23)

				assert.spy(sanitizeSpy).is_called_with(match.is_ref(inst), 23)
				cls._sanitizeLimitOffset:revert()

				assert.is_equal(23, inst._value)
			end)
		end)

		describe('toString()', function()
			it('output nothing if not set', function()
				assert.is_equal('', inst:toString())
			end)

			it('output nothing if 0', function()
				inst:_setValue(0)

				assert.is_equal('', inst:toString())
			end)

			it('output verb', function()
				inst:_setValue(12)

				assert.is_equal('TEST 12', inst:toString())
			end)
		end)

		describe('toParam()', function()
			it('output nothing if not set', function()
				assert.is_same({ text = '', values = {} }, inst:toParam())
			end)

			it('output nothing if 0', function()
				inst:_setValue(0)

				assert.is_same({ text = '', values = {} }, inst:toParam())
			end)

			it('output verb', function()
				inst:_setValue(12)

				assert.is_same({ text = 'TEST ?', values = { 12 } }, inst:toParam())
			end)
		end)
	end)

	describe('OffsetBlock', function()
		before_each(function()
			cls = squel.cls.OffsetBlock
			inst = cls:new()
		end)

		it('instanceof of AbstractVerbSingleValueBlock', function()
			assert.is_equal(true, Object.instanceof(inst, squel.cls.AbstractVerbSingleValueBlock))
		end)

		describe('offset()', function()
			it('calls base method', function()
				local callSpy = spy.on(cls, '_setValue')

				inst:offset(1)

				assert.spy(callSpy).is_called_with(match.is_ref(inst), 1)
				cls._setValue:revert()
			end)
		end)

		describe('toString()', function()
			it('output nothing if not set', function()
				assert.is_equal('', inst:toString())
			end)

			it('output verb', function()
				inst:offset(12)

				assert.is_equal('OFFSET 12', inst:toString())
			end)
		end)

		describe('toParam()', function()
			it('output nothing if not set', function()
				assert.is_same({ text = '', values = {} }, inst:toParam())
			end)

			it('output verb', function()
				inst:offset(12)

				assert.is_same({ text = 'OFFSET ?', values = { 12 } }, inst:toParam())
			end)
		end)
	end)

	describe('LimitBlock', function()
		before_each(function()
			cls = squel.cls.LimitBlock
			inst = cls:new()
		end)

		it('instanceof of AbstractVerbSingleValueBlock', function()
			assert.is_equal(true, Object.instanceof(inst, squel.cls.AbstractVerbSingleValueBlock))
		end)

		describe('limit()', function()
			it('calls base method', function()
				local callSpy = spy.on(cls, '_setValue')

				inst:limit(1)

				assert.spy(callSpy).is_called_with(match.is_ref(inst), 1)
				cls._setValue:revert()
			end)
		end)

		describe('toString()', function()
			it('output nothing if not set', function()
				assert.is_equal('', inst:toString())
			end)

			it('output verb', function()
				inst:limit(12)

				assert.is_equal('LIMIT 12', inst:toString())
			end)
		end)

		describe('toParam()', function()
			it('output nothing if not set', function()
				assert.is_same({ text = '', values = {} }, inst:toParam())
			end)

			it('output verb', function()
				inst:limit(12)

				assert.is_same({ text = 'LIMIT ?', values = { 12 } }, inst:toParam())
			end)
		end)
	end)

	describe('AbstractConditionBlock', function()
		before_each(function()
			cls = squel.cls.AbstractConditionBlock
			inst = cls:new({
				verb = 'ACB'
			})

			squel.cls.MockConditionBlock = squel.cls.AbstractConditionBlock:extend()
				function squel.cls.MockConditionBlock:initialize(options)
					squel.cls.AbstractConditionBlock.initialize(self, R.extend({}, options, { verb = 'MOCKVERB' }))
				end

				function squel.cls.MockConditionBlock:mockCondition(condition, ...)
					self:_condition(condition, ...)
				end

			squel.cls.MockSelectWithCondition = squel.cls.Select:extend()
				function squel.cls.MockSelectWithCondition:initialize(options, blocks)
					blocks = blocks or {
						squel.cls.StringBlock:new(options, 'SELECT'),
						squel.cls.GetFieldBlock:new(options),
						squel.cls.FromTableBlock:new(options),
						squel.cls.MockConditionBlock:new(options)
					}

					squel.cls.Select.initialize(self, options, blocks)
				end
		end)

		it('instanceof of Block', function()
			assert.is_equal(true, Object.instanceof(inst, squel.cls.Block))
		end)

		describe('_condition()', function()
			it('adds to list', function()
				inst:_condition('a = 1')
				inst:_condition('b = 2 OR c = 3')

				assert.is_same({
					{
						expr = 'a = 1',
						values = {}
					},
					{
						expr = 'b = 2 OR c = 3',
						values = {}
					}
				}, inst._conditions)
			end)

			it('sanitizes inputs', function()
				local sanitizeFieldSpy = spy.on(cls, '_sanitizeExpression')

				inst:_condition('a = 1')

				assert.spy(sanitizeFieldSpy).is_called_with(match.is_ref(inst), 'a = 1')
				cls._sanitizeExpression:revert()

				assert.is_same({{
					expr = 'a = 1',
					values = {}
				}}, inst._conditions)
			end)
		end)

		describe('_toParamString()', function()
			it('output nothing if no conditions set', function()
				assert.is_same({
					text = '',
					values = {}
				}, inst:_toParamString())
			end)

			describe('output QueryBuilder ', function()
				before_each(function()
					local subquery = squel.cls.MockSelectWithCondition:new()
					subquery:field('col1'):from('table1'):mockCondition('field1 = ?', 10)
					inst:_condition('a in ?', subquery)
					inst:_condition('b = ? OR c = ?', 2, 3)
					inst:_condition('d in ?', { 4, 5, 6 })
				end)

				it('non-parameterized', function()
					assert.is_same({
						text = 'ACB (a in (SELECT col1 FROM table1 MOCKVERB (field1 = 10))) AND (b = 2 OR c = 3) AND (d in (4, 5, 6))',
						values = {}
					}, inst:_toParamString())
				end)

				it('parameterized', function()
					assert.is_same({
						text = 'ACB (a in (SELECT col1 FROM table1 MOCKVERB (field1 = ?))) AND (b = ? OR c = ?) AND (d in (?, ?, ?))',
						values = { 10, 2, 3, 4, 5, 6 }
					}, inst:_toParamString({ buildParameterized = true }))
				end)
			end)

			describe('Fix for #64 - toString() does not change object', function()
				before_each(function()
					inst:_condition('a = ?', 1)
					inst:_condition('b = ? OR c = ?', 2, 3)
					inst:_condition('d in ?', { 4, 5, 6 })
					inst:_toParamString()
					inst:_toParamString()
				end)

				it('non-parameterized', function()
					assert.is_same({
						text = 'ACB (a = 1) AND (b = 2 OR c = 3) AND (d in (4, 5, 6))',
						values = {}
					}, inst:_toParamString())
				end)

				it('parameterized', function()
					assert.is_same({
						text = 'ACB (a = ?) AND (b = ? OR c = ?) AND (d in (?, ?, ?))',
						values = { 1, 2, 3, 4, 5, 6 }
					}, inst:_toParamString({ buildParameterized = true }))
				end)
			end)

			describe('Fix for #226 - empty expressions', function()
				before_each(function()
					inst:_condition('a = ?', 1)
					inst:_condition(squel.expr())
				end)

				it('non-parameterized', function()
					assert.is_same({
						text = 'ACB (a = 1)',
						values = {}
					}, inst:_toParamString())
				end)

				it('parameterized', function()
					assert.is_same({
						text = 'ACB (a = ?)',
						values = { 1 }
					}, inst:_toParamString({ buildParameterized = true }))
				end)
			end)
		end)
	end)

	describe('WhereBlock', function()
		before_each(function()
			cls = squel.cls.WhereBlock
			inst = cls:new()
		end)

		it('instanceof of AbstractConditionBlock', function()
			assert.is_equal(true, Object.instanceof(inst, squel.cls.AbstractConditionBlock))
		end)

		it('sets verb to WHERE', function()
			inst = cls:new()

			assert.is_equal('WHERE', inst.options.verb)
		end)

		describe('_toParamString()', function()
			it('output nothing if no conditions set', function()
				assert.is_same({
					text = '',
					values = {}
				}, inst:_toParamString())
			end)

			describe('output', function()
				before_each(function()
					local subquery = squel.cls.Select:new()
					subquery:field('col1'):from('table1'):where('field1 = ?', 10)
					inst:where('a in ?', subquery)
					inst:where('b = ? OR c = ?', 2, 3)
					inst:where('d in ?', { 4, 5, 6 })
				end)

				it('non-parameterized', function()
					assert.is_same({
						text = 'WHERE (a in (SELECT col1 FROM table1 WHERE (field1 = 10))) AND (b = 2 OR c = 3) AND (d in (4, 5, 6))',
						values = {}
					}, inst:_toParamString())
				end)

				it('parameterized', function()
					assert.is_same({
						text = 'WHERE (a in (SELECT col1 FROM table1 WHERE (field1 = ?))) AND (b = ? OR c = ?) AND (d in (?, ?, ?))',
						values = { 10, 2, 3, 4, 5, 6 }
					}, inst:_toParamString({ buildParameterized = true }))
				end)
			end)
		end)
	end)

	describe('HavingBlock', function()
		before_each(function()
			cls = squel.cls.HavingBlock
			inst = cls:new()
		end)

		it('instanceof of AbstractConditionBlock', function()
			assert.is_equal(true, Object.instanceof(inst, squel.cls.AbstractConditionBlock))
		end)

		it('sets verb', function()
			inst = cls:new()

			assert.is_equal('HAVING', inst.options.verb)
		end)

		describe('_toParamString()', function()
			it('output nothing if no conditions set', function()
				assert.is_same({
					text = '',
					values = {}
				}, inst:_toParamString())
			end)

			describe('output', function()
				before_each(function()
					local subquery = squel.cls.Select:new()
					subquery:field('col1'):from('table1'):where('field1 = ?', 10)
					inst:having('a in ?', subquery)
					inst:having('b = ? OR c = ?', 2, 3)
					inst:having('d in ?', { 4, 5, 6 })
				end)

				it('non-parameterized', function()
					assert.is_same({
						text = 'HAVING (a in (SELECT col1 FROM table1 WHERE (field1 = 10))) AND (b = 2 OR c = 3) AND (d in (4, 5, 6))',
						values = {}
					}, inst:_toParamString())
				end)

				it('parameterized', function()
					assert.is_same({
						text = 'HAVING (a in (SELECT col1 FROM table1 WHERE (field1 = ?))) AND (b = ? OR c = ?) AND (d in (?, ?, ?))',
						values = { 10, 2, 3, 4, 5, 6 }
					}, inst:_toParamString({ buildParameterized = true }))
				end)
			end)
		end)
	end)

	describe('OrderByBlock', function()
		before_each(function()
			cls = squel.cls.OrderByBlock
			inst = cls:new()
		end)

		it('instanceof of Block', function()
			assert.is_equal(true, Object.instanceof(inst, squel.cls.Block))
		end)

		describe('order()', function()
			it('adds to list', function()
				inst:order('field1')
				inst:order('field2', false)
				inst:order('field3', true)

				local expected = {
					{
						field = 'field1',
						dir = 'ASC',
						values = {}
					},
					{
						field = 'field2',
						dir = 'DESC',
						values = {}
					},
					{
						field = 'field3',
						dir = 'ASC',
						values = {}
					}
				}

				assert.is_same(expected, inst._orders)
			end)

			it('sanitizes inputs', function()
				local sanitizeFieldSpy = spy.on(cls, '_sanitizeField')

				inst:order('field1')

				assert.spy(sanitizeFieldSpy).is_called_with(match.is_ref(inst), 'field1')
				cls._sanitizeField:revert()

				assert.is_same({{
					field = 'field1',
					dir = 'ASC',
					values = {}
				}}, inst._orders)
			end)

			it('saves additional values', function()
				inst:order('field1', false, 1.2, 4)

				assert.is_same({ { field = 'field1', dir = 'DESC', values = { 1.2, 4 } } }, inst._orders)
			end)
		end)

		describe('_toParamString()', function()
			it('empty', function()
				assert.is_same({
					text = '',
					values = {}
				}, inst:_toParamString())
			end)

			describe('default', function()
				before_each(function()
					inst:order('field1')
					inst:order('field2', false)
					inst:order('GET(?, ?)', true, 2.5 , 5)
				end)

				it('non-parameterized', function()
					assert.is_same({
						text = 'ORDER BY field1 ASC, field2 DESC, GET(2.5, 5) ASC',
						values = {}
					}, inst:_toParamString())
				end)

				it('parameterized', function()
					assert.is_same({
						text = 'ORDER BY field1 ASC, field2 DESC, GET(?, ?) ASC',
						values = { 2.5, 5 }
					}, inst:_toParamString({ buildParameterized = true }))
				end)
			end)
		end)
	end)

	describe('JoinBlock', function()
		before_each(function()
			cls = squel.cls.JoinBlock
			inst = cls:new()
		end)

		it('instanceof of Block', function()
			assert.is_equal(true, Object.instanceof(inst, squel.cls.Block))
		end)

		describe('join()', function()
			it('adds to list', function()
				inst:join('table1')
				inst:join('table2', nil, 'b = 1', 'LEFT')
				inst:join('table3', 'alias3', 'c = 1', 'RIGHT')
				inst:join('table4', 'alias4', 'd = 1', 'OUTER')
				inst:join('table5', 'alias5', nil, 'CROSS')

				local expected = {
					{
						type = 'INNER',
						table = 'table1',
						alias = nil,
						condition = nil
					},
					{
						type = 'LEFT',
						table = 'table2',
						alias = nil,
						condition = 'b = 1'
					},
					{
						type = 'RIGHT',
						table = 'table3',
						alias = 'alias3',
						condition = 'c = 1'
					},
					{
						type = 'OUTER',
						table = 'table4',
						alias = 'alias4',
						condition = 'd = 1'
					},
					{
						type = 'CROSS',
						table = 'table5',
						alias = 'alias5',
						condition = nil
					}
				}

				assert.is_same(expected, inst._joins)
			end)

			it('sanitizes inputs', function()
				local sanitizeTableSpy = spy.on(cls, '_sanitizeTable')
				local sanitizeAliasSpy = spy.on(cls, '_sanitizeTableAlias')
				local sanitizeConditionSpy = spy.on(cls, '_sanitizeExpression')

				inst:join('table1', 'alias1', 'a = 1')

				assert.spy(sanitizeTableSpy).is_called_with(match.is_ref(inst), 'table1', true)
				cls._sanitizeTable:revert()
				assert.spy(sanitizeAliasSpy).is_called_with(match.is_ref(inst), 'alias1')
				cls._sanitizeTableAlias:revert()
				assert.spy(sanitizeConditionSpy).is_called_with(match.is_ref(inst), 'a = 1')
				cls._sanitizeExpression:revert()

				assert.is_same({{
					type = 'INNER',
					table = 'table1',
					alias = 'alias1',
					condition = 'a = 1'
				}}, inst._joins)
			end)

			it('nested queries', function()
				local inner1 = squel.select()
				local inner2 = squel.select()
				local inner3 = squel.select()
				local inner4 = squel.select()
				local inner5 = squel.select()
				local inner6 = squel.select()
				inst:join(inner1)
				inst:join(inner2, nil, 'b = 1', 'LEFT')
				inst:join(inner3, 'alias3', 'c = 1', 'RIGHT')
				inst:join(inner4, 'alias4', 'd = 1', 'OUTER')
				inst:join(inner5, 'alias5', 'e = 1', 'FULL')
				inst:join(inner6, 'alias6', nil, 'CROSS')

				local expected = {
					{
						type = 'INNER',
						table = inner1,
						alias = nil,
						condition = nil
					},
					{
						type = 'LEFT',
						table = inner2,
						alias = nil,
						condition = 'b = 1'
					},
					{
						type = 'RIGHT',
						table = inner3,
						alias = 'alias3',
						condition = 'c = 1'
					},
					{
						type = 'OUTER',
						table = inner4,
						alias = 'alias4',
						condition = 'd = 1'
					},
					{
						type = 'FULL',
						table = inner5,
						alias = 'alias5',
						condition = 'e = 1'
					},
					{
						type = 'CROSS',
						table = inner6,
						alias = 'alias6',
						condition = nil
					}
				}

				assert.is_same(expected, inst._joins)
			end)
		end)

		describe('left_join()', function()
			it('calls join()', function()
				local joinSpy = spy.on(inst, 'join')

				inst:left_join('t', 'a', 'c')

				assert.spy(joinSpy).is_called(1)
				assert.spy(joinSpy).is_called_with(match.is_ref(inst), 't', 'a', 'c', 'LEFT')
				inst.join:revert()
			end)
		end)

		describe('_toParamString()', function()
			it('output nothing if nothing set', function()
				assert.is_same({
					text = '',
					values = {}
				}, inst:_toParamString())
			end)

			describe('output JOINs with nested queries', function()
				before_each(function()
					local inner2 = squel.select():FUNCTION('GETDATE(?)', 2)
					local inner3 = squel.select():from('3')
					local inner4 = squel.select():from('4')
					local inner5 = squel.select():from('5')
					local expr = squel.expr():AND('field1 = ?', 99)

					inst:join('table')
					inst:join(inner2, nil, 'b = 1', 'LEFT')
					inst:join(inner3, 'alias3', 'c = 1', 'RIGHT')
					inst:join(inner4, 'alias4', 'e = 1', 'FULL')
					inst:join(inner5, 'alias5', expr, 'CROSS')
				end)

				it('non-parameterized', function()
					assert.is_same({
						text = 'INNER JOIN table LEFT JOIN (SELECT GETDATE(2)) ON (b = 1) '
							.. 'RIGHT JOIN (SELECT * FROM 3) `alias3` ON (c = 1) '
							.. 'FULL JOIN (SELECT * FROM 4) `alias4` ON (e = 1) '
							.. 'CROSS JOIN (SELECT * FROM 5) `alias5` ON (field1 = 99)',
						values = {}
					}, inst:_toParamString())
				end)

				it('parameterized', function()
					assert.is_same({
						text = 'INNER JOIN table LEFT JOIN (SELECT GETDATE(?)) ON (b = 1) '
							.. 'RIGHT JOIN (SELECT * FROM 3) `alias3` ON (c = 1) '
							.. 'FULL JOIN (SELECT * FROM 4) `alias4` ON (e = 1) '
							.. 'CROSS JOIN (SELECT * FROM 5) `alias5` ON (field1 = ?)',
						values = { 2, 99 }
					}, inst:_toParamString({ buildParameterized = true }))
				end)
			end)
		end)
	end)
end)
