describe('INSERT builder', function()
	local Object = require('object')
	local R = require('moses')
	local squel = require('squel')

	local func
	local inst

	before_each(function()
		func = squel.insert
		inst = func()
	end)

	it('instanceof QueryBuilder', function()
		assert.is_equal(true, Object.instanceof(inst, squel.cls.QueryBuilder))
	end)

	describe('constructor', function()
		it('override options', function()
			inst = squel.update({
				usingValuePlaceholders = true,
				dummy = true
			})

			local expectedOptions = R.extend({}, squel.cls.DefaultQueryBuilderOptions, {
				usingValuePlaceholders = true,
				dummy = true
			})

			for _, block in ipairs(inst.blocks) do
				assert.is_same(expectedOptions, R.pick(block.options, R.keys(expectedOptions)))
			end
		end)

		it('override blocks', function()
			local block = squel.cls.StringBlock:new('SELECT')
			inst = func({}, { block })
			assert.is_same({ block }, inst.blocks)
		end)
	end)

	describe('build query', function()
		it('need to call into() first', function()
			assert.is_error(function()
				inst:toString()
			end, 'into() needs to be called')
		end)

		it('when set() not called', function()
			assert.is_same('INSERT INTO table', inst:into('table'):toString())
		end)

		describe(">> into(table):set(field, 'NULL')", function()
			before_each(function()
				inst:into('table'):set('field', 'NULL')
			end)

			it('toString', function()
				assert.is_equal('INSERT INTO table (field) VALUES (NULL)', inst:toString())
			end)

			it('toParam', function()
				assert.is_same({
					text = 'INSERT INTO table (field) VALUES (?)',
					values = { 'NULL' }
				}, inst:toParam())
			end)
		end)

		describe('>> into(table)', function()
			before_each(function()
				inst:into('table')
			end)

			describe('>> set(field, 1)', function()
				before_each(function()
					inst:set('field', 1)
				end)

				it('toString', function()
					assert.is_equal('INSERT INTO table (field) VALUES (1)', inst:toString())
				end)

				describe('>> set(field2, 1.2)', function()
					before_each(function()
						inst:set('field2', 1.2)
					end)

					it('toString', function()
						assert.is_equal('INSERT INTO table (field, field2) VALUES (1, 1.2)', inst:toString())
					end)
				end)

				describe('>> set(field2, "str")', function()
					before_each(function()
						inst:set('field2', 'str')
					end)

					it('toString', function()
						assert.is_equal("INSERT INTO table (field, field2) VALUES (1, 'str')", inst:toString())
					end)

					it('toParam', function()
						assert.is_same({
							text = 'INSERT INTO table (field, field2) VALUES (?, ?)',
							values = {  1, 'str'  }
						}, inst:toParam())
					end)
				end)

				describe('>> set(field2, "str", { dontQuote = true } )', function()
					before_each(function()
						inst:set('field2', 'str', { dontQuote = true })
					end)

					it('toString', function()
						assert.is_equal('INSERT INTO table (field, field2) VALUES (1, str)', inst:toString())
					end)

					it('toParam', function()
						assert.is_same({
							text = 'INSERT INTO table (field, field2) VALUES (?, ?)',
							values = {  1, 'str'  }
						}, inst:toParam())
					end)
				end)

				describe('>> set(field2, true)', function()
					before_each(function()
						inst:set('field2', true)
					end)

					it('toString', function()
						assert.is_equal('INSERT INTO table (field, field2) VALUES (1, TRUE)', inst:toString())
					end)
				end)

				describe(">> set(field2, 'NULL')", function()
					before_each(function()
						inst:set('field2', 'NULL')
					end)

					it('toString', function()
						assert.is_equal('INSERT INTO table (field, field2) VALUES (1, NULL)', inst:toString())
					end)
				end)

				describe('>> set(field, query builder)', function()
					before_each(function()
						local subQuery = squel.select():field('MAX(score)'):from('scores')
						inst:set( 'field',  subQuery )
					end)

					it('toString', function()
						assert.is_equal('INSERT INTO table (field) VALUES ((SELECT MAX(score) FROM scores))', inst:toString())
					end)

					it('toParam', function()
						local parameterized = inst:toParam()
						assert.is_equal('INSERT INTO table (field) VALUES ((SELECT MAX(score) FROM scores))', parameterized.text)
						assert.is_same({}, parameterized.values)
					end)
				end)

				describe(">> setFields({ field2 = 'value2', field3 = true })", function()
					before_each(function()
						inst:setFields({ field3 = true, field2 = 'value2' })
					end)

					it('toString', function()
						assert.is_equal("INSERT INTO table (field, field2, field3) VALUES (1, 'value2', TRUE)", inst:toString())
					end)

					it('toParam', function()
						local parameterized = inst:toParam()
						assert.is_equal('INSERT INTO table (field, field2, field3) VALUES (?, ?, ?)', parameterized.text)
						assert.is_same({ 1, 'value2', true }, parameterized.values)
					end)
				end)

				describe(">> setFields({ field2 = 'value2', field = true })", function()
					before_each(function()
						inst:setFields({ field2 = 'value2', field = true })
					end)

					it('toString', function()
						assert.is_equal("INSERT INTO table (field, field2) VALUES (TRUE, 'value2')", inst:toString())
					end)

					it('toParam', function()
						local parameterized = inst:toParam()
						assert.is_equal('INSERT INTO table (field, field2) VALUES (?, ?)', parameterized.text)
						assert.is_same({ true, 'value2' }, parameterized.values)
					end)
				end)

				describe('>> setFields(custom value type)', function()
					before_each(function()
						local MyClass = Object:extend()
						inst:registerValueHandler(MyClass, function()
							return 'abcd'
						end)
						inst:setFields({ field = MyClass:new() })
					end)

					it('toString', function()
						assert.is_equal('INSERT INTO table (field) VALUES ((abcd))', inst:toString())
					end)

					it('toParam', function()
						local parameterized = inst:toParam()
						assert.is_equal('INSERT INTO table (field) VALUES (?)', parameterized.text)
						assert.is_same({ 'abcd' }, parameterized.values)
					end)
				end)

				describe(">> setFieldsRows({ { field = 'value2', field2 = true }, { field = 'value3', field2 = 13 } })", function()
					before_each(function()
						inst:setFieldsRows({ { field2 = true, field = 'value2' }, { field2 = 13, field = 'value3' } })
					end)

					it('toString', function()
						assert.is_equal("INSERT INTO table (field, field2) VALUES ('value2', TRUE), ('value3', 13)", inst:toString())
					end)

					it('toParam', function()
						local parameterized = inst:toParam()
						assert.is_equal('INSERT INTO table (field, field2) VALUES (?, ?), (?, ?)', parameterized.text)
						assert.is_same({ 'value2', true, 'value3', 13 }, parameterized.values)
					end)
				end)
			end)

			describe('Function values', function()
				before_each(function()
					inst:set('field', squel.str('GETDATE(?, ?)', 2014, 'feb'))
				end)

				it('toString', function()
					assert.is_equal("INSERT INTO table (field) VALUES ((GETDATE(2014, 'feb')))", inst:toString())
				end)

				it('toParam', function()
					assert.is_same({
						text = 'INSERT INTO table (field) VALUES ((GETDATE(?, ?)))',
						values = { 2014, 'feb' }
					}, inst:toParam())
				end)
			end)

			describe('>> fromQuery({ field1, field2 }, select query)', function()
				before_each(function()
					inst:fromQuery(
						{ 'field1', 'field2' },
						squel.select():from('students'):where('a = ?', 2)
					)
				end)

				it('toString', function()
					assert.is_equal('INSERT INTO table (field1, field2) (SELECT * FROM students WHERE (a = 2))', inst:toString())
				end)

				it('toParam', function()
					local parameterized = inst:toParam()
					assert.is_equal('INSERT INTO table (field1, field2) (SELECT * FROM students WHERE (a = ?))', parameterized.text)
					assert.is_same({  2  }, parameterized.values)
				end)
			end)

			it(">> setFieldsRows({ { field1 = 13, field2 = 'value2' }, { field1 = true, field3 = 'value4' } })", function()
				assert.is_error(function()
					inst:setFieldsRows({ { field1 = 13, field2 = 'value2' }, { field1 = true, field3 = 'value4' } }):toString()
				end, 'All fields in subsequent rows must match the fields in the first row')
			end)
		end)
	end)

	describe('dontQuote and replaceSingleQuotes set(field2, "ISNULL(\'str\', str)", { dontQuote = true })', function()
		before_each(function()
			inst = squel.insert({ replaceSingleQuotes = true })
			inst:into('table'):set('field', 1)
			inst:set('field2', "ISNULL('str', str)", { dontQuote = true })
		end)

		it('toString', function()
			assert.is_equal("INSERT INTO table (field, field2) VALUES (1, ISNULL('str', str))", inst:toString())
		end)

		it('toParam', function()
			assert.is_same({
				text = 'INSERT INTO table (field, field2) VALUES (?, ?)',
				values = { 1, "ISNULL('str', str)" }
			}, inst:toParam())
		end)
	end)

	it('fix for #225 - autoquoting field names', function()
		inst = squel.insert({ autoQuoteFieldNames = true })
			:into('users')
			:set('active', 1)
			:set('regular', 0)
			:set('moderator', 1)

			assert.is_same({
				text = 'INSERT INTO users (`active`, `regular`, `moderator`) VALUES (?, ?, ?)',
				values = { 1, 0, 1 },
			}, inst:toParam())
	end)

	it('cloning', function()
		local newinst = inst:into('students'):set('field', 1):clone()
		newinst:set('field', 2):set('field2', true)

		assert.is_same('INSERT INTO students (field) VALUES (1)', inst:toString())
		assert.is_same('INSERT INTO students (field, field2) VALUES (2, TRUE)', newinst:toString())
	end)
end)
