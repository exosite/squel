describe('UPDATE builder', function()
	local Object = require('object')
	local R = require('moses')
	local squel = require('squel')

	local func
	local inst

	before_each(function()
		func = squel.update
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
		it('need to call set() first', function()
			inst:table('table')
			assert.is_error(function()
				inst:toString()
			end, 'set() needs to be called')
		end)

		describe('>> table(table, t1):set(field, 1)', function()
			before_each(function()
				inst:table('table', 't1'):set('field', 1)
			end)

			it('toString', function()
				assert.is_equal('UPDATE table `t1` SET field = 1', inst:toString())
			end)

			describe('>> set(field2, 1.2)', function()
				before_each(function()
					inst:set('field2', 1.2)
				end)

				it('toString', function()
					assert.is_equal('UPDATE table `t1` SET field = 1, field2 = 1.2', inst:toString())
				end)
			end)

			describe('>> set(field2, true)', function()
				before_each(function()
					inst:set('field2', true)
				end)

				it('toString', function()
					assert.is_equal('UPDATE table `t1` SET field = 1, field2 = TRUE', inst:toString())
				end)
			end)

			describe(">> set(field2, 'NULL')", function()
				before_each(function()
					inst:set('field2', 'NULL')
				end)

				it('toString', function()
					assert.is_equal('UPDATE table `t1` SET field = 1, field2 = NULL', inst:toString())
				end)

				it('toParam', function()
					assert.is_same({
						text = 'UPDATE table `t1` SET field = ?, field2 = ?',
						values = { 1, 'NULL' }
					}, inst:toParam())
				end)
			end)

			describe('>> set(field2, "str")', function()
				before_each(function()
					inst:set('field2', 'str')
				end)

				it('toString', function()
					assert.is_equal("UPDATE table `t1` SET field = 1, field2 = 'str'", inst:toString())
				end)

				it('toParam', function()
					assert.is_same({
						text = 'UPDATE table `t1` SET field = ?, field2 = ?',
						values = { 1, 'str' }
					}, inst:toParam())
				end)
			end)

			describe('>> set(field2, "str", { dontQuote = true })', function()
				before_each(function()
					inst:set('field2', 'str', { dontQuote = true })
				end)

				it('toString', function()
					assert.is_equal('UPDATE table `t1` SET field = 1, field2 = str', inst:toString())
				end)

				it('toParam', function()
					assert.is_same({
						text = 'UPDATE table `t1` SET field = ?, field2 = ?',
						values = { 1, 'str' }
					}, inst:toParam())
				end)
			end)

			describe('>> set(field, query builder)', function()
				before_each(function()
					local subQuery = squel.select():field('MAX(score)'):from('scores')
					inst:set('field',  subQuery)
				end)

				it('toString', function()
					assert.is_equal('UPDATE table `t1` SET field = (SELECT MAX(score) FROM scores)', inst:toString())
				end)

				it('toParam', function()
					local parameterized = inst:toParam()
					assert.is_equal('UPDATE table `t1` SET field = (SELECT MAX(score) FROM scores)', parameterized.text)
					assert.is_same({}, parameterized.values)
				end)
			end)

			describe('>> set(custom value type)', function()
				before_each(function()
					local MyClass = Object:extend()
					inst:registerValueHandler(MyClass, function()
						return 'abcd'
					end)
					inst:setFields({ field = MyClass:new() })
				end)

				it('toString', function()
					assert.is_equal('UPDATE table `t1` SET field = (abcd)', inst:toString())
				end)

				it('toParam', function()
					local parameterized = inst:toParam()
					assert.is_equal('UPDATE table `t1` SET field = ?', parameterized.text)
					assert.is_same({ 'abcd' }, parameterized.values)
				end)
			end)

			describe(">> setFields({ field2 = 'value2', field3 = true })", function()
				before_each(function()
					inst:setFields({ field3 = true, field2 = 'value2' })
				end)

				it('toString', function()
					assert.is_equal("UPDATE table `t1` SET field = 1, field2 = 'value2', field3 = TRUE", inst:toString())
				end)

				it('toParam', function()
					local parameterized = inst:toParam()
					assert.is_equal('UPDATE table `t1` SET field = ?, field2 = ?, field3 = ?', parameterized.text)
					assert.is_same({ 1, 'value2', true }, parameterized.values)
				end)
			end)

			describe(">> setFields({ field2 = 'value2', field = true })", function()
				before_each(function()
					inst:setFields({ field2 = 'value2', field = true })
				end)

				it('toString', function()
					assert.is_equal("UPDATE table `t1` SET field = TRUE, field2 = 'value2'", inst:toString())
				end)
			end)

			describe(">> set(field2, 'NULL')", function()
				before_each(function()
					inst:set('field2', 'NULL')
				end)

				it('toString', function()
					assert.is_equal('UPDATE table `t1` SET field = 1, field2 = NULL', inst:toString())
				end)

				describe('>> table(table2)', function()
					before_each(function()
						inst:table('table2')
					end)

					it('toString', function()
						assert.is_equal('UPDATE table `t1`, table2 SET field = 1, field2 = NULL', inst:toString())
					end)

					describe('>> where(a = 1)', function()
						before_each(function()
							inst:where('a = 1')
						end)

						it('toString', function()
							assert.is_equal('UPDATE table `t1`, table2 SET field = 1, field2 = NULL WHERE (a = 1)', inst:toString())
						end)

						describe('>> order(a, true)', function()
							before_each(function()
								inst:order('a', true)
							end)

							it('toString', function()
								assert.is_equal('UPDATE table `t1`, table2 SET field = 1, field2 = NULL WHERE (a = 1) ORDER BY a ASC',
									inst:toString())
							end)

							describe('>> limit(2)', function()
								before_each(function()
									inst:limit(2)
								end)

								it('toString', function()
									assert.is_equal('UPDATE table `t1`, table2 SET field = 1, field2 = NULL WHERE (a = 1) ORDER BY a ASC LIMIT 2',
										inst:toString())
								end)
							end)
						end)
					end)
				end)
			end)
		end)

		describe(">> table(table, t1):setFields({ field1 = 1, field2 = 'value2' })", function()
			before_each(function()
				inst:table('table', 't1'):setFields({ field1 = 1, field2 = 'value2' })
			end)

			it('toString', function()
				assert.is_equal("UPDATE table `t1` SET field1 = 1, field2 = 'value2'", inst:toString())
			end)

			describe('>> set(field1, 1.2)', function()
				before_each(function()
					inst:set('field1', 1.2)
				end)

				it('toString', function()
					assert.is_equal("UPDATE table `t1` SET field1 = 1.2, field2 = 'value2'", inst:toString())
				end)
			end)

			describe(">> setFields({ field3 = true, field4 = 'value4' })", function()
				before_each(function()
					inst:setFields({ field4 = 'value4', field3 = true })
				end)

				it('toString', function()
					assert.is_equal("UPDATE table `t1` SET field1 = 1, field2 = 'value2', field3 = TRUE, field4 = 'value4'",
						inst:toString())
				end)
			end)

			describe(">> setFields({ field1 = true, field3 = 'value3' })", function()
				before_each(function()
					inst:setFields({ field1 = true, field3 = 'value3' })
				end)

				it('toString', function()
					assert.is_equal("UPDATE table `t1` SET field1 = TRUE, field2 = 'value2', field3 = 'value3'", inst:toString())
				end)
			end)
		end)

		describe('>> table(table, t1):set("count = count + 1")', function()
			before_each(function()
				inst:table('table', 't1'):set('count = count + 1')
			end)

			it('toString', function()
				assert.is_equal('UPDATE table `t1` SET count = count + 1', inst:toString())
			end)
		end)
	end)

	describe('str()', function()
		before_each(function()
			inst:table('students'):set('field', squel.str('GETDATE(?, ?)', 2014, '"feb"'))
		end)

		it('toString', function()
			assert.is_equal('UPDATE students SET field = (GETDATE(2014, \'"feb"\'))', inst:toString())
		end)

		it('toParam', function()
			assert.is_same({
				text = 'UPDATE students SET field = (GETDATE(?, ?))',
				values = { 2014, '"feb"' }
			}, inst:toParam())
		end)
	end)

	describe('string formatting', function()
		before_each(function()
			inst:updateOptions({
				stringFormatter = function(str)
					return "N'" .. str .. "'"
				end
			})
			inst:table('students'):set('field', 'jack')
		end)

		it('toString', function()
			assert.is_equal("UPDATE students SET field = N'jack'", inst:toString())
		end)

		it('toParam', function()
			assert.is_same({
				text = 'UPDATE students SET field = ?',
				values = { 'jack' }
			}, inst:toParam())
		end)
	end)

	it('fix for hiddentao/squel#63', function()
		local newinst = inst:table('students'):set('field = field + 1')
		newinst:set('field2', 2):set('field3', true)
		assert.is_same({
			text = 'UPDATE students SET field = field + 1, field2 = ?, field3 = ?',
			values = { 2, true }
		}, inst:toParam())
	end)

	describe('dontQuote and replaceSingleQuotes set(field2, "ISNULL(\'str\', str)", { dontQuote = true })', function()
		before_each(function()
			inst = squel.update({ replaceSingleQuotes = true })
			inst:table('table', 't1'):set('field', 1)
			inst:set('field2', "ISNULL('str', str)", { dontQuote = true })
		end)

		it('toString', function()
			assert.is_equal("UPDATE table `t1` SET field = 1, field2 = ISNULL('str', str)", inst:toString())
		end)

		it('toParam', function()
			assert.is_same({
				text = 'UPDATE table `t1` SET field = ?, field2 = ?',
				values = { 1, "ISNULL('str', str)" }
			}, inst:toParam())
		end)
	end)

	it('fix for #225 - autoquoting field names', function()
		inst = squel.update({ autoQuoteFieldNames = true })
			:table('users')
			:where('id = ?', 123)
			:set('active', 1)
			:set('regular', 0)
			:set('moderator',1)

			assert.is_same({
				text = 'UPDATE users SET `active` = ?, `regular` = ?, `moderator` = ? WHERE (id = ?)',
				values = { 1, 0, 1, 123 },
			}, inst:toParam())
	end)

	describe('fix for #243 - ampersand in conditions', function()
		before_each(function()
			inst = squel.update():table('a'):set('a = a & ?', 2)
		end)

		it('toString', function()
			assert.is_equal('UPDATE a SET a = a & 2', inst:toString())
		end)

		it('toParam', function()
			assert.is_same({
				text = 'UPDATE a SET a = a & ?',
				values = { 2 },
			}, inst:toParam())
		end)
	end)

	it('cloning', function()
		local newinst = inst:table('students'):set('field', 1):clone()
		newinst:set('field', 2):set('field2', true)

		assert.is_equal('UPDATE students SET field = 1', inst:toString())
		assert.is_equal('UPDATE students SET field = 2, field2 = TRUE', newinst:toString())
	end)
end)
