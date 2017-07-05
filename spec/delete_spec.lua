describe('DELETE builder', function()
	local Object = require('object')
	local R = require('moses')
	local squel = require('squel')

	local func
	local inst

	before_each(function()
		func = squel.delete
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
		it('no need to call from()', function()
			inst:toString()
		end)

		describe('>> from(table)', function()
			before_each(function()
				inst:from('table')
			end)

			it('toString', function()
				assert.is_equal('DELETE FROM table', inst:toString())
			end)

			describe('>> table(table2, t2)', function()
				before_each(function()
					inst:from('table2', 't2')
				end)

				it('toString', function()
					assert.is_equal('DELETE FROM table2 `t2`', inst:toString())
				end)

				describe('>> where(a = 1)', function()
					before_each(function()
						inst:where('a = 1')
					end)

					it('toString', function()
						assert.is_equal('DELETE FROM table2 `t2` WHERE (a = 1)', inst:toString())
					end)

					describe('>> join(other_table)', function()
						before_each(function()
							inst:join('other_table', 'o', 'o.id = t2.id')
						end)

						it('toString', function()
							assert.is_equal('DELETE FROM table2 `t2` INNER JOIN other_table `o` '
								.. 'ON (o.id = t2.id) WHERE (a = 1)', inst:toString())
						end)

						describe('>> order(a, true)', function()
							before_each(function()
								inst:order('a', true)
							end)

							it('toString', function()
								assert.is_equal('DELETE FROM table2 `t2` INNER JOIN other_table `o` '
									.. 'ON (o.id = t2.id) WHERE (a = 1) ORDER BY a ASC', inst:toString())
							end)

							describe('>> limit(2)', function()
								before_each(function()
									inst:limit(2)
								end)

								it('toString', function()
									assert.is_equal('DELETE FROM table2 `t2` INNER JOIN other_table `o` '
										.. 'ON (o.id = t2.id) WHERE (a = 1) ORDER BY a ASC LIMIT 2', inst:toString())
								end)
							end)
						end)
					end)
				end)
			end)
		end)

		describe('>> target(table1):from(table1):left_join(table2, nil, "table1.a = table2.b")', function()
			before_each(function()
				inst:target('table1'):from('table1'):left_join('table2', nil, 'table1.a = table2.b'):where('c = ?', 3)
			end)

			it('toString', function()
				assert.is_equal('DELETE table1 FROM table1 LEFT JOIN table2 '
					.. 'ON (table1.a = table2.b) WHERE (c = 3)', inst:toString())
			end)

			it('toParam', function()
				assert.is_same({
					text = 'DELETE table1 FROM table1 LEFT JOIN table2 '
						.. 'ON (table1.a = table2.b) WHERE (c = ?)',
					values = { 3 }
				}, inst:toParam())
			end)

			describe('>> target(table2)', function()
				before_each(function()
					inst:target('table2')
				end)

				it('toString', function()
					assert.is_equal('DELETE table1, table2 FROM table1 LEFT JOIN table2 '
						.. 'ON (table1.a = table2.b) WHERE (c = 3)', inst:toString())
				end)

				it('toParam', function()
					assert.is_same({
						text = 'DELETE table1, table2 FROM table1 LEFT JOIN table2 '
							.. 'ON (table1.a = table2.b) WHERE (c = ?)',
						values = { 3 }
					}, inst:toParam())
				end)
			end)
		end)

		describe('>> from(table1):left_join(table2, nil, "table1.a = table2.b")', function()
			before_each(function()
				inst:from('table1'):left_join('table2', nil, 'table1.a = table2.b'):where('c = ?', 3)
			end)

			it('toString', function()
				assert.is_equal('DELETE FROM table1 LEFT JOIN table2 ON (table1.a = table2.b) WHERE (c = 3)', inst:toString())
			end)

			it('toParam', function()
				assert.is_same({
					text = 'DELETE FROM table1 LEFT JOIN table2 ON (table1.a = table2.b) WHERE (c = ?)',
					values = { 3 }
				}, inst:toParam())
			end)
		end)
	end)

	it('cloning', function()
		local newinst = inst:from('students'):limit(10):clone()
		newinst:limit(20)

		assert.is_equal('DELETE FROM students LIMIT 10', inst:toString())
		assert.is_equal('DELETE FROM students LIMIT 20', newinst:toString())
	end)
end)
