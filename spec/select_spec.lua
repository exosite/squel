describe('SELECT builder', function()
	local Object = require('object')
	local R = require('moses')
	local squel = require('squel')

	local func
	local inst

	before_each(function()
		func = squel.select
		inst = func()
	end)

	it('instanceof QueryBuilder', function()
		assert.is_equal(true, Object.instanceof(inst, squel.cls.QueryBuilder))
	end)

	describe('constructor', function()
		it('override options', function()
			inst = squel.select({
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
		it('no need to call from() first', function()
			inst:toString()
		end)

		describe('>> function(1)', function()
			before_each(function()
				inst:FUNCTION('1')
			end)

			it('toString', function()
				assert.is_equal('SELECT 1', inst:toString())
			end)

			it('toParam', function()
				assert.is_same({
					text = 'SELECT 1',
					values = {}
				}, inst:toParam())
			end)
		end)

		describe('>> function(MAX(?, ?), 3, 5)', function()
			before_each(function()
				inst:FUNCTION('MAX(?, ?)', 3, 5)
			end)

			it('toString', function()
				assert.is_equal('SELECT MAX(3, 5)', inst:toString())
			end)

			it('toParam', function()
				assert.is_same({
					text = 'SELECT MAX(?, ?)',
					values = { 3, 5 }
				}, inst:toParam())
			end)
		end)

		describe('>> from(table):from(table2, alias2)', function()
			before_each(function()
				inst:from('table'):from('table2', 'alias2')
			end)

			it('toString', function()
				assert.is_equal('SELECT * FROM table, table2 `alias2`', inst:toString())
			end)

			describe('>> field(squel.select():field("MAX(score)"):FROM("scores"), fa1)', function()
				before_each(function()
					inst:field(squel.select():field('MAX(score)'):from('scores'), 'fa1')
				end)

				it('toString', function()
					assert.is_equal('SELECT (SELECT MAX(score) FROM scores) AS "fa1" FROM table, table2 `alias2`', inst:toString())
				end)
			end)

			describe('>> field(squel.case():WHEN(score > ?, 1):THEN(1), fa1)', function()
				before_each(function()
					inst:field(squel.case():WHEN('score > ?', 1):THEN(1), 'fa1')
				end)

				it('toString', function()
					assert.is_equal('SELECT CASE WHEN (score > 1) THEN 1 ELSE NULL END AS "fa1" FROM table, table2 `alias2`',
						inst:toString())
				end)

				it('toParam', function()
					assert.is_same({
						text = 'SELECT CASE WHEN (score > ?) THEN 1 ELSE NULL END AS "fa1" FROM table, table2 `alias2`',
						values = { 1 }
					}, inst:toParam())
				end)
			end)

			describe('>> field( squel.str(SUM(?), squel.case():WHEN(score > ?, 1):THEN(1) ), fa1)', function()
				before_each(function()
					inst:field( squel.str('SUM(?)', squel.case():WHEN('score > ?', 1):THEN(1)), 'fa1')
				end)

				it('toString', function()
					assert.is_equal('SELECT (SUM((CASE WHEN (score > 1) THEN 1 ELSE NULL END))) AS "fa1" FROM table, table2 `alias2`',
						inst:toString())
				end)

				it('toParam', function()
					assert.is_same({
						text = 'SELECT (SUM(CASE WHEN (score > ?) THEN 1 ELSE NULL END)) AS "fa1" FROM table, table2 `alias2`',
						values = { 1 }
					}, inst:toParam())
				end)
			end)

			describe('>> field(field1, fa1) >> field(field2)', function()
				before_each(function()
					inst:field('field1', 'fa1'):field('field2')
				end)

				it('toString', function()
					assert.is_equal('SELECT field1 AS "fa1", field2 FROM table, table2 `alias2`', inst:toString())
				end)

				describe('>> distinct()', function()
					before_each(function()
						inst:distinct()
					end)

					it('toString', function()
						assert.is_equal('SELECT DISTINCT field1 AS "fa1", field2 FROM table, table2 `alias2`', inst:toString())
					end)

					describe('>> group(field) >> group(field2)', function()
						before_each(function()
							inst:group('field'):group('field2')
						end)

						it('toString', function()
							assert.is_equal('SELECT DISTINCT field1 AS "fa1", field2 FROM table, table2 `alias2` GROUP BY field, field2',
								inst:toString())
						end)

						describe('>> where(a = ?, squel.select():field("MAX(score)"):from("scores"))', function()
							before_each(function()
								local subQuery = squel.select():field('MAX(score)'):from('scores')
								inst:where('a = ?', subQuery)
							end)

							it('toString', function()
								assert.is_equal('SELECT DISTINCT field1 AS "fa1", field2 FROM table, table2 `alias2` '
									.. 'WHERE (a = (SELECT MAX(score) FROM scores)) GROUP BY field, field2', inst:toString())
							end)

							it('toParam', function()
								assert.is_same({
									text = 'SELECT DISTINCT field1 AS "fa1", field2 FROM table, table2 `alias2` '
										.. 'WHERE (a = (SELECT MAX(score) FROM scores)) GROUP BY field, field2',
									values = {}
								}, inst:toParam())
							end)
						end)

						describe('>> where(squel.expr():AND(a = ?, 1):AND( expr():OR(b = ?, 2):OR(c = ?, 3) ))', function()
							before_each(function()
								inst:where(squel.expr():AND('a = ?', 1):AND(squel.expr():OR('b = ?', 2):OR('c = ?', 3)))
							end)

							it('toString', function()
								assert.is_equal('SELECT DISTINCT field1 AS "fa1", field2 FROM table, table2 `alias2` '
									.. 'WHERE (a = 1 AND (b = 2 OR c = 3)) GROUP BY field, field2', inst:toString())
							end)

							it('toParam', function()
								assert.is_same({
									text = 'SELECT DISTINCT field1 AS "fa1", field2 FROM table, table2 `alias2` '
										.. 'WHERE (a = ? AND (b = ? OR c = ?)) GROUP BY field, field2',
									values = { 1, 2, 3 }
								}, inst:toParam())
							end)
						end)

						describe('>> where(squel.expr():AND(a = ?, QueryBuilder):AND( expr():OR(b = ?, 2):OR(c = ?, 3) ))', function()
							before_each(function()
								local subQuery = squel.select():field('field1'):from('table1'):where('field2 = ?', 10)
								inst:where(squel.expr():AND('a = ?', subQuery):AND(squel.expr():OR('b = ?', 2):OR('c = ?', 3)))
							end)

							it('toString', function()
								assert.is_equal('SELECT DISTINCT field1 AS "fa1", field2 FROM table, table2 `alias2` '
									.. 'WHERE (a = (SELECT field1 FROM table1 WHERE (field2 = 10)) AND (b = 2 OR c = 3)) '
									.. 'GROUP BY field, field2', inst:toString())
							end)

							it('toParam', function()
								assert.is_same({
									text = 'SELECT DISTINCT field1 AS "fa1", field2 FROM table, table2 `alias2` '
									.. 'WHERE (a = (SELECT field1 FROM table1 WHERE (field2 = ?)) AND (b = ? OR c = ?)) '
									.. 'GROUP BY field, field2',
									values = { 10, 2, 3 }
								}, inst:toParam())
							end)
						end)

						describe('>> having(squel.expr():AND(a = ?, QueryBuilder):AND( expr():OR(b = ?, 2):OR(c = ?, 3) ))', function()
							before_each(function()
								local subQuery = squel.select():field('field1'):from('table1'):having('field2 = ?', 10)
								inst:having(squel.expr():AND('a = ?', subQuery):AND(squel.expr():OR('b = ?', 2):OR('c = ?', 3)))
							end)

							it('toString', function()
								assert.is_equal('SELECT DISTINCT field1 AS "fa1", field2 FROM table, table2 `alias2` GROUP BY field, field2 '
									.. 'HAVING (a = (SELECT field1 FROM table1 HAVING (field2 = 10)) AND (b = 2 OR c = 3))', inst:toString())
							end)

							it('toParam', function()
								assert.is_same({
									text = 'SELECT DISTINCT field1 AS "fa1", field2 FROM table, table2 `alias2` GROUP BY field, field2 '
									.. 'HAVING (a = (SELECT field1 FROM table1 HAVING (field2 = ?)) AND (b = ? OR c = ?))',
									values = { 10, 2, 3 }
								}, inst:toParam())
							end)
						end)

						describe(">> where(a = ?, 'NULL')", function()
							before_each(function()
								inst:where('a = ?', 'NULL')
							end)

							it('toString', function()
								assert.is_equal('SELECT DISTINCT field1 AS "fa1", field2 FROM table, table2 `alias2` '
									.. 'WHERE (a = NULL) GROUP BY field, field2', inst:toString())
							end)

							it('toParam', function()
								assert.is_same({
									text = 'SELECT DISTINCT field1 AS "fa1", field2 FROM table, table2 `alias2` '
										.. 'WHERE (a = ?) GROUP BY field, field2',
									values = { 'NULL' }
								}, inst:toParam())
							end)
						end)

						describe('>> where(a = ?, 1)', function()
							before_each(function()
								inst:where('a = ?', 1)
							end)

							it('toString', function()
								assert.is_equal('SELECT DISTINCT field1 AS "fa1", field2 FROM table, table2 `alias2` '
									.. 'WHERE (a = 1) GROUP BY field, field2', inst:toString())
							end)

							it('toParam', function()
								assert.is_same({
									text = 'SELECT DISTINCT field1 AS "fa1", field2 FROM table, table2 `alias2` '
										.. 'WHERE (a = ?) GROUP BY field, field2',
									values = { 1 }
								}, inst:toParam())
							end)

							describe('>> join(other_table)', function()
								before_each(function()
									inst:join('other_table')
								end)

								it('toString', function()
									assert.is_equal('SELECT DISTINCT field1 AS "fa1", field2 FROM table, table2 `alias2` '
										.. 'INNER JOIN other_table WHERE (a = 1) GROUP BY field, field2', inst:toString())
								end)

								describe('>> order(a)', function()
									before_each(function()
										inst:order('a')
									end)

									it('toString', function()
										assert.is_equal('SELECT DISTINCT field1 AS "fa1", field2 FROM table, table2 `alias2` '
											.. 'INNER JOIN other_table WHERE (a = 1) GROUP BY field, field2 ORDER BY a ASC', inst:toString())
									end)
								end)

								describe(">> order(a, 'asc nulls last')", function()
									before_each(function()
										inst:order('a', 'asc nulls last')
									end)

									it('toString', function()
										assert.is_equal('SELECT DISTINCT field1 AS "fa1", field2 FROM table, table2 `alias2` '
											.. 'INNER JOIN other_table WHERE (a = 1) GROUP BY field, field2 ORDER BY a asc nulls last', inst:toString())
									end)
								end)

								describe('>> order(a, true)', function()
									before_each(function()
										inst:order('a', true)
									end)

									it('toString', function()
										assert.is_equal('SELECT DISTINCT field1 AS "fa1", field2 FROM table, table2 `alias2` '
											.. 'INNER JOIN other_table WHERE (a = 1) GROUP BY field, field2 ORDER BY a ASC', inst:toString())
									end)

									describe('>> limit(2)', function()
										before_each(function()
											inst:limit(2)
										end)

										it('toString', function()
											assert.is_equal('SELECT DISTINCT field1 AS "fa1", field2 FROM table, table2 `alias2` '
												.. 'INNER JOIN other_table WHERE (a = 1) GROUP BY field, field2 ORDER BY a ASC LIMIT 2', inst:toString())
										end)

										it('toParam', function()
											assert.is_same({
												text = 'SELECT DISTINCT field1 AS "fa1", field2 FROM table, table2 `alias2` '
													.. 'INNER JOIN other_table WHERE (a = ?) GROUP BY field, field2 ORDER BY a ASC LIMIT ?',
												values = { 1, 2 }
											}, inst:toParam())
										end)

										describe('>> limit(0)', function()
											before_each(function()
												inst:limit(0)
											end)

											it('toString', function()
												assert.is_equal('SELECT DISTINCT field1 AS "fa1", field2 FROM table, table2 `alias2` '
													.. 'INNER JOIN other_table WHERE (a = 1) GROUP BY field, field2 ORDER BY a ASC', inst:toString())
											end)

											it('toParam', function()
												assert.is_same({
													text = 'SELECT DISTINCT field1 AS "fa1", field2 FROM table, table2 `alias2` '
														.. 'INNER JOIN other_table WHERE (a = ?) GROUP BY field, field2 ORDER BY a ASC',
													values = { 1 }
												}, inst:toParam())
											end)
										end)

										describe('>> offset(3)', function()
											before_each(function()
												inst:offset(3)
											end)

											it('toString', function()
												assert.is_equal('SELECT DISTINCT field1 AS "fa1", field2 FROM table, table2 `alias2` '
													.. 'INNER JOIN other_table WHERE (a = 1) GROUP BY field, field2 '
													.. 'ORDER BY a ASC LIMIT 2 OFFSET 3', inst:toString())
											end)

											it('toParam', function()
												assert.is_same({
													text = 'SELECT DISTINCT field1 AS "fa1", field2 FROM table, table2 `alias2` '
														.. 'INNER JOIN other_table WHERE (a = ?) GROUP BY field, field2 '
														.. 'ORDER BY a ASC LIMIT ? OFFSET ?',
													values = { 1, 2, 3 }
												}, inst:toParam())
											end)

											describe('>> offset(0)', function()
												before_each(function()
													inst:offset(0)
												end)

												it('toString', function()
													assert.is_equal('SELECT DISTINCT field1 AS "fa1", field2 FROM table, table2 `alias2` '
														.. 'INNER JOIN other_table WHERE (a = 1) GROUP BY field, field2 '
														.. 'ORDER BY a ASC LIMIT 2', inst:toString())
												end)

												it('toParam', function()
													assert.is_same({
														text = 'SELECT DISTINCT field1 AS "fa1", field2 FROM table, table2 `alias2` '
															.. 'INNER JOIN other_table WHERE (a = ?) GROUP BY field, field2 '
															.. 'ORDER BY a ASC LIMIT ?',
														values = { 1, 2 }
													}, inst:toParam())
												end)
											end)
										end)
									end)
								end)

								describe('>> order(DIST(?, ?), true, 2, 3)', function()
									before_each(function()
										inst:order('DIST(?, ?)', true, 2, false)
									end)

									it('toString', function()
										assert.is_equal('SELECT DISTINCT field1 AS "fa1", field2 FROM table, table2 `alias2` '
											.. 'INNER JOIN other_table WHERE (a = 1) GROUP BY field, field2 '
											.. 'ORDER BY DIST(2, FALSE) ASC', inst:toString())
									end)

									it('toParam', function()
										assert.is_same({
											text = 'SELECT DISTINCT field1 AS "fa1", field2 FROM table, table2 `alias2` '
												.. 'INNER JOIN other_table WHERE (a = ?) GROUP BY field, field2 '
												.. 'ORDER BY DIST(?, ?) ASC',
											values = { 1, 2, false }
										}, inst:toParam())
									end)
								end)

								describe('>> order(a)', function()
									before_each(function()
										inst:order('a')
									end)

									it('toString', function()
										assert.is_equal('SELECT DISTINCT field1 AS "fa1", field2 FROM table, table2 `alias2` '
											.. 'INNER JOIN other_table WHERE (a = 1) GROUP BY field, field2 '
											.. 'ORDER BY a ASC', inst:toString())
									end)
								end)
							end)

							describe('>> join(other_table, condition = expr())', function()
								before_each(function()
									local subQuery = squel.select():field('abc'):from('table1'):where('adf = ?', 'today1')
									local subQuery2 = squel.select():field('xyz'):from('table2'):where('adf = ?', 'today2')
									local expr = squel.expr():AND('field1 = ?', subQuery)
									inst:join('other_table', nil, expr)
									inst:where('def IN ?', subQuery2)
								end)

								it('toString', function()
									assert.is_equal('SELECT DISTINCT field1 AS "fa1", field2 FROM table, table2 `alias2` '
										.. "INNER JOIN other_table ON (field1 = (SELECT abc FROM table1 WHERE (adf = 'today1'))) "
										.. "WHERE (a = 1) AND (def IN (SELECT xyz FROM table2 WHERE (adf = 'today2'))) "
										.. 'GROUP BY field, field2', inst:toString())
								end)

								it('toParam', function()
									assert.is_same({
										text = 'SELECT DISTINCT field1 AS "fa1", field2 FROM table, table2 `alias2` '
											.. 'INNER JOIN other_table ON (field1 = (SELECT abc FROM table1 WHERE (adf = ?))) '
											.. 'WHERE (a = ?) AND (def IN (SELECT xyz FROM table2 WHERE (adf = ?))) '
											.. 'GROUP BY field, field2',
										values = { 'today1', 1, 'today2' }
									}, inst:toParam())
								end)
							end)
						end)
					end)
				end)
			end)
		end)

		describe('nested queries', function()
			it('basic', function()
				local inner1 = squel.select():from('students')
				local inner2 = squel.select():from('scores')

				inst:from(inner1):from(inner2, 'scores')

				assert.is_equal('SELECT * FROM (SELECT * FROM students), (SELECT * FROM scores) `scores`', inst:toString())
			end)

			it('deep nesting', function()
				local inner1 = squel.select():from('students')
				local inner2 = squel.select():from(inner1)

				inst:from(inner2)

				assert.is_equal('SELECT * FROM (SELECT * FROM (SELECT * FROM students))', inst:toString())
			end)

			it('nesting in JOINs', function()
				local inner1 = squel.select():from('students')
				local inner2 = squel.select():from(inner1)

				inst:from('schools'):join(inner2, 'meh', 'meh.ID = ID')

				assert.is_equal('SELECT * FROM schools '
					.. 'INNER JOIN (SELECT * FROM (SELECT * FROM students)) `meh` ON (meh.ID = ID)', inst:toString())
			end)

			it('nesting in JOINs with params', function()
				local inner1 = squel.select():from('students'):where('age = ?', 6)
				local inner2 = squel.select():from(inner1)

				inst:from('schools'):where('school_type = ?', 'junior'):join(inner2, 'meh', 'meh.ID = ID')

				assert.is_equal('SELECT * FROM schools '
					.. 'INNER JOIN (SELECT * FROM (SELECT * FROM students WHERE (age = 6))) `meh` ON (meh.ID = ID) '
					.. "WHERE (school_type = 'junior')", inst:toString())
				assert.is_same({
					text = 'SELECT * FROM schools '
						.. 'INNER JOIN (SELECT * FROM (SELECT * FROM students WHERE (age = ?))) `meh` ON (meh.ID = ID) '
						.. 'WHERE (school_type = ?)',
					values = { 6, 'junior' }
				}, inst:toParam())
				assert.is_same({
					text = 'SELECT * FROM schools '
						.. 'INNER JOIN (SELECT * FROM (SELECT * FROM students WHERE (age = $1))) `meh` ON (meh.ID = ID) '
						.. 'WHERE (school_type = $2)',
					values = { 6, 'junior' }
				}, inst:toParam({ numberedParameters = true }))
			end)
		end)
	end)

	describe('Complex table name, e.g. LATERAL (#230)', function()
		before_each(function()
			local subQuery = squel.select():from('bar'):where('bar.id = ?', 2)
			inst = squel.select():from('foo'):from(squel.str('LATERAL(?)', subQuery), 'ss')
		end)

		it('toString', function()
			assert.is_equal('SELECT * FROM foo, (LATERAL((SELECT * FROM bar WHERE (bar.id = 2)))) `ss`', inst:toString())
		end)

		it('toParam', function()
			assert.is_same({
				text = 'SELECT * FROM foo, (LATERAL((SELECT * FROM bar WHERE (bar.id = ?)))) `ss`',
				values = { 2 }
			}, inst:toParam())
		end)
	end)

	describe('cloning', function()
		it('basic', function()
			local newinst = inst:from('students'):limit(10):clone()
			newinst:limit(20)

			assert.is_same('SELECT * FROM students LIMIT 10', inst:toString())
			assert.is_same('SELECT * FROM students LIMIT 20', newinst:toString())
		end)

		it('with expressions (ticket #120)', function()
			local expr = squel.expr():AND('a = 1')
			local newinst = inst:from('table'):left_join('table_2', 't', expr)
				:clone()
				:where('c = 1')

			expr:AND('b = 2')

			assert.is_same('SELECT * FROM table LEFT JOIN table_2 `t` ON (a = 1 AND b = 2)', inst:toString())
			assert.is_same('SELECT * FROM table LEFT JOIN table_2 `t` ON (a = 1) WHERE (c = 1)', newinst:toString())
		end)

		it('with sub-queries (ticket #120)', function()
			local newinst = inst:from(squel.select():from('students')):limit(30)
				:clone()
				:where('c = 1')
				:limit(35)

			assert.is_same('SELECT * FROM (SELECT * FROM students) LIMIT 30', inst:toString())
			assert.is_same('SELECT * FROM (SELECT * FROM students) WHERE (c = 1) LIMIT 35', newinst:toString())
		end)

		it('with complex expressions', function()
			local expr = squel.expr():AND(
				squel.expr():OR('b = 2'):OR(
					squel.expr():AND('c = 3'):AND('d = 4')
				)
			):AND('a = 1')

			local newinst = inst:from('table'):left_join('table_2', 't', expr)
				:clone()
				:where('c = 1')

			expr:AND('e = 5')

			assert.is_equal('SELECT * FROM table LEFT JOIN table_2 `t` '
				.. 'ON ((b = 2 OR (c = 3 AND d = 4)) AND a = 1 AND e = 5)', inst:toString())
			assert.is_equal('SELECT * FROM table LEFT JOIN table_2 `t` '
				.. 'ON ((b = 2 OR (c = 3 AND d = 4)) AND a = 1) WHERE (c = 1)', newinst:toString())
		end)
	end)

	it('can specify block separator', function()
		assert.is_same( squel.select({ separator = '\n' })
			:field('thing')
			:from('table')
			:toString(), 'SELECT\nthing\nFROM table'
		)
	end)

	describe('#242 - auto-quote table names', function()
		before_each(function()
			inst = squel
				.select({ autoQuoteTableNames = true })
				:field('name')
				:where('age > ?', 15)
		end)

		describe('using string', function()
			before_each(function()
				inst:from('students', 's')
			end)

			it('toString', function()
				assert.is_equal('SELECT name FROM `students` `s` WHERE (age > 15)', inst:toString())
			end)

			it('toParam', function()
				assert.is_same({
					text = 'SELECT name FROM `students` `s` WHERE (age > ?)',
					values = { 15 }
				}, inst:toParam())
			end)
		end)

		describe('using query builder', function()
			before_each(function()
				inst:from(squel.select():from('students'), 's')
			end)

			it('toString', function()
				assert.is_equal('SELECT name FROM (SELECT * FROM students) `s` WHERE (age > 15)', inst:toString())
			end)

			it('toParam', function()
				assert.is_same({
					text = 'SELECT name FROM (SELECT * FROM students) `s` WHERE (age > ?)',
					values = { 15 }
				}, inst:toParam())
			end)
		end)
	end)

	describe('UNION JOINs', function()
		describe('Two Queries NO Params', function()
			local qry1

			before_each(function()
				qry1 = squel.select():field('name'):from('students'):where('age > 15')
				local qry2 = squel.select():field('name'):from('students'):where('age < 6')
				qry1:union(qry2)
			end)

			it('toString', function()
				assert.is_equal('SELECT name FROM students WHERE (age > 15) UNION (SELECT name FROM students WHERE (age < 6))',
					qry1:toString())
			end)

			it('toParam', function()
				assert.is_same({
					text = 'SELECT name FROM students WHERE (age > 15) UNION (SELECT name FROM students WHERE (age < 6))',
					values = {}
				}, qry1:toParam())
			end)
		end)

		describe('Two Queries with Params', function()
			local qry1

			before_each(function()
				qry1 = squel.select():field('name'):from('students'):where('age > ?', 15)
				local qry2 = squel.select():field('name'):from('students'):where('age < ?', 6)
				qry1:union(qry2)
			end)

			it('toString', function()
				assert.is_equal('SELECT name FROM students WHERE (age > 15) UNION (SELECT name FROM students WHERE (age < 6))',
					qry1:toString())
			end)

			it('toParam', function()
				assert.is_same({
					text = 'SELECT name FROM students WHERE (age > ?) UNION (SELECT name FROM students WHERE (age < ?))',
					values = { 15, 6 }
				}, qry1:toParam())
			end)
		end)

		describe('Three Queries', function()
			local qry1

			before_each(function()
				qry1 = squel.select():field('name'):from('students'):where('age > ?', 15)
				local qry2 = squel.select():field('name'):from('students'):where('age < 6')
				local qry3 = squel.select():field('name'):from('students'):where('age = ?', 8)
				qry1:union(qry2)
				qry1:union(qry3)
			end)

			it('toParam', function()
				assert.is_same({
					text = 'SELECT name FROM students WHERE (age > ?) '
						.. 'UNION (SELECT name FROM students WHERE (age < 6)) '
						.. 'UNION (SELECT name FROM students WHERE (age = ?))',
					values = { 15, 8 }
				}, qry1:toParam())
			end)

			it('toParam(2)', function()
				assert.is_same({
					text = 'SELECT name FROM students WHERE (age > $2) '
						.. 'UNION (SELECT name FROM students WHERE (age < 6)) '
						.. 'UNION (SELECT name FROM students WHERE (age = $3))',
					values = { 15, 8 }
				}, qry1:toParam({ numberedParameters = true, numberedParametersStartAt = 2 }))
			end)
		end)

		describe('Multi-Parameter Query', function()
			local qry4

			before_each(function()
				local qry1 = squel.select():field('name'):from('students'):where('age > ?', 15)
				local qry2 = squel.select():field('name'):from('students'):where('age < ?', 6)
				local qry3 = squel.select():field('name'):from('students'):where('age = ?', 8)
				qry4 = squel.select():field('name'):from('students'):where('age IN { ?, ? }', 2, 10)
				qry1:union(qry2)
				qry1:union(qry3)
				qry4:union_all(qry1)
			end)

			it('toString', function()
				assert.is_equal('SELECT name FROM students WHERE (age IN { 2, 10 }) '
					.. 'UNION ALL (SELECT name FROM students WHERE (age > 15) '
					.. 'UNION (SELECT name FROM students WHERE (age < 6)) '
					.. 'UNION (SELECT name FROM students WHERE (age = 8)))', qry4:toString())
			end)

			it('toParam', function()
				assert.is_same({
					text = 'SELECT name FROM students WHERE (age IN { $1, $2 }) '
					.. 'UNION ALL (SELECT name FROM students WHERE (age > $3) '
					.. 'UNION (SELECT name FROM students WHERE (age < $4)) '
					.. 'UNION (SELECT name FROM students WHERE (age = $5)))',
					values = { 2, 10, 15, 6, 8 }
				}, qry4:toParam({ numberedParameters = true }))
			end)
		end)

		describe('Where builder expression', function()
			before_each(function()
				inst = squel.select():from('table'):where('a = ?', 5)
					:where(squel.str('EXISTS(?)', squel.select():from('blah'):where('b > ?', 6)))
			end)

			it('toString', function()
				assert.is_equal('SELECT * FROM table WHERE (a = 5) AND (EXISTS((SELECT * FROM blah WHERE (b > 6))))',
					inst:toString())
			end)

			it('toParam', function()
				assert.is_same({
					text = 'SELECT * FROM table WHERE (a = ?) AND (EXISTS((SELECT * FROM blah WHERE (b > ?))))',
					values = { 5, 6 }
				}, inst:toParam())
			end)
		end)

		describe('Join on builder expression', function()
			before_each(function()
				inst = squel.select():from('table'):join('table2', 't2',
					squel.str('EXISTS(?)', squel.select():from('blah'):where('b > ?', 6))
				)
			end)

			it('toString', function()
				assert.is_equal('SELECT * FROM table INNER JOIN table2 `t2` ON (EXISTS((SELECT * FROM blah WHERE (b > 6))))',
					inst:toString())
			end)

			it('toParam', function()
				assert.is_same({
					text = 'SELECT * FROM table INNER JOIN table2 `t2` ON (EXISTS((SELECT * FROM blah WHERE (b > ?))))',
					values = { 6 }
				}, inst:toParam())
			end)
		end)
	end)
end)
