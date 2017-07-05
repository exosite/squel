describe('Postgres flavour', function()
	local squel

	before_each(function()
		package.loaded['squel'] = nil
		squel = require('squel').useFlavour('postgres')
	end)

	describe('INSERT builder', function()
		local inst

		before_each(function()
			inst = squel.insert()
		end)

		describe('>> into(table):set(field, 1):set(field,2):onConflict("field", { field2 = 2 })', function()
			before_each(function()
				inst:into('table'):set('field', 1):set('field2', 2):onConflict('field', { field2 = 2 })
			end)

			it('toString', function()
				assert.is_equal('INSERT INTO table (field, field2) VALUES (1, 2) '
					.. 'ON CONFLICT (field) DO UPDATE SET field2 = 2', inst:toString())
			end)
		end)

		describe('>> into(table):set(field, 1):set(field,2):onConflict("field")', function()
			before_each(function()
				inst:into('table'):set('field', 1):set('field2', 2):onConflict('field')
			end)

			it('toString', function()
				assert.is_equal('INSERT INTO table (field, field2) VALUES (1, 2) ON CONFLICT (field) DO NOTHING', inst:toString())
			end)
		end)

		describe('>> into(table):set(field, 1):returning("*")', function()
			before_each(function()
				inst:into('table'):set('field', 1):returning('*')
			end)

			it('toString', function()
				assert.is_equal('INSERT INTO table (field) VALUES (1) RETURNING *', inst:toString())
			end)
		end)

		describe('>> into(table):set(field, 1):returning("id")', function()
			before_each(function()
				inst:into('table'):set('field', 1):returning('id')
			end)

			it('toString', function()
				assert.is_equal('INSERT INTO table (field) VALUES (1) RETURNING id', inst:toString())
			end)
		end)

		describe('>> into(table):set(field, 1):returning("id"):returning("id")', function()
			before_each(function()
				inst:into('table'):set('field', 1):returning('id'):returning('id')
			end)

			it('toString', function()
				assert.is_equal('INSERT INTO table (field) VALUES (1) RETURNING id', inst:toString())
			end)
		end)

		describe('>> into(table):set(field, 1):returning("id"):returning("name", "alias")', function()
			before_each(function()
				inst:into('table'):set('field', 1):returning('id'):returning('name', 'alias')
			end)

			it('toString', function()
				assert.is_equal('INSERT INTO table (field) VALUES (1) RETURNING id, name AS alias', inst:toString())
			end)
		end)

		describe('>> into(table):set(field, 1):returning(squel.str("id < ?", 100), "under100")', function()
			before_each(function()
				inst:into('table'):set('field', 1):returning(squel.str('id < ?', 100), 'under100')
			end)

			it('toString', function()
				assert.is_equal('INSERT INTO table (field) VALUES (1) RETURNING (id < 100) AS under100', inst:toString())
			end)

			it('toParam', function()
				assert.is_same({
					text = 'INSERT INTO table (field) VALUES ($1) RETURNING (id < $2) AS under100',
					values = { 1, 100 }
				}, inst:toParam())
			end)
		end)

		describe('>> into(table):set(field, 1):with(alias, table)', function()
			before_each(function()
				inst:into('table'):set('field', 1):with('alias', squel.select():from('table'):where('field = ?', 2))
			end)

			it('toString', function()
				assert.is_equal('WITH alias AS (SELECT * FROM table WHERE (field = 2)) '
					.. 'INSERT INTO table (field) VALUES (1)', inst:toString())
			end)

			it('toParam', function()
				assert.is_same({
					text = 'WITH alias AS (SELECT * FROM table WHERE (field = $1)) '
						.. 'INSERT INTO table (field) VALUES ($2)',
					values = { 2, 1 }
				}, inst:toParam())
			end)
		end)
	end)

	describe('UPDATE builder', function()
		local upd

		before_each(function()
			upd = squel.update()
		end)

		describe('>> table(table):set(field, 1):returning("*")', function()
			before_each(function()
				upd:table('table'):set('field', 1):returning('*')
			end)

			it('toString', function()
				assert.is_equal('UPDATE table SET field = 1 RETURNING *', upd:toString())
			end)
		end)

		describe('>> table(table):set(field, 1):returning("field")', function()
			before_each(function()
				upd:table('table'):set('field', 1):returning('field')
			end)

			it('toString', function()
				assert.is_equal('UPDATE table SET field = 1 RETURNING field', upd:toString())
			end)
		end)

		describe('>> table(table):set(field, 1):returning("name", "alias")', function()
			before_each(function()
				upd:table('table'):set('field', 1):returning('name', 'alias')
			end)

			it('toString', function()
				assert.is_equal('UPDATE table SET field = 1 RETURNING name AS alias', upd:toString())
			end)
		end)

		describe('>> table(table):set(field, 1):from(table2)', function()
			before_each(function()
				upd:table('table'):set('field', 1):from('table2')
			end)

			it('toString', function()
				assert.is_equal('UPDATE table SET field = 1 FROM table2', upd:toString())
			end)
		end)

		describe('>> table(table):set(field, 1):with(alias, table)', function()
			before_each(function()
				upd:table('table'):set('field', 1):with('alias', squel.select():from('table'):where('field = ?', 2))
			end)

			it('toString', function()
				assert.is_equal('WITH alias AS (SELECT * FROM table WHERE (field = 2)) UPDATE table SET field = 1', upd:toString())
			end)

			it('toParam', function()
				assert.is_same({
					text = 'WITH alias AS (SELECT * FROM table WHERE (field = $1)) UPDATE table SET field = $2',
					values = { 2, 1 }
				}, upd:toParam())
			end)
		end)
	end)

	describe('DELETE builder', function()
		local del

		before_each(function()
			del = squel.delete()
		end)

		describe('>> from(table):where(field = 1):returning("*")', function()
			before_each(function()
				del:from('table'):where('field = 1'):returning('*')
			end)

			it('toString', function()
				assert.is_equal('DELETE FROM table WHERE (field = 1) RETURNING *', del:toString())
			end)
		end)

		describe('>> from(table):where(field = 1):returning("field")', function()
			before_each(function()
				del:from('table'):where('field = 1'):returning('field')
			end)

			it('toString', function()
				assert.is_equal('DELETE FROM table WHERE (field = 1) RETURNING field', del:toString())
			end)
		end)

		describe('>> from(table):where(field = 1):returning("field", "f")', function()
			before_each(function()
				del:from('table'):where('field = 1'):returning('field', 'f')
			end)

			it('toString', function()
				assert.is_equal('DELETE FROM table WHERE (field = 1) RETURNING field AS f', del:toString())
			end)
		end)

		describe('>> from(table):where(field = 1):with(alias, table)', function()
			before_each(function()
				del:from('table'):where('field = ?', 1):with('alias', squel.select():from('table'):where('field = ?', 2))
			end)

			it('toString', function()
				assert.is_equal('WITH alias AS (SELECT * FROM table WHERE (field = 2)) '
					.. 'DELETE FROM table WHERE (field = 1)', del:toString())
			end)

			it('toParam', function()
				assert.is_same({
					text = 'WITH alias AS (SELECT * FROM table WHERE (field = $1)) '
						.. 'DELETE FROM table WHERE (field = $2)',
					values = { 2, 1 }
				}, del:toParam())
			end)
		end)
	end)

	describe('SELECT builder', function()
		local sel

		before_each(function()
			sel = squel.select()
		end)

		describe('select', function()
			describe('>> from(table):where(field = 1)', function()
				before_each(function()
					sel:field('field1'):from('table1'):where('field1 = 1')
				end)

				it('toString', function()
					assert.is_equal('SELECT field1 FROM table1 WHERE (field1 = 1)', sel:toString())
				end)

				it('toParam', function()
					assert.is_same({
						text = 'SELECT field1 FROM table1 WHERE (field1 = 1)',
						values = {}
					}, sel:toParam())
				end)
			end)

			describe('>> from(table):where(field = ?, 2)', function()
				before_each(function()
					sel:field('field1'):from('table1'):where('field1 = ?', 2)
				end)

				it('toString', function()
					assert.is_equal('SELECT field1 FROM table1 WHERE (field1 = 2)', sel:toString())
				end)

				it('toParam', function()
					assert.is_same({
						text = 'SELECT field1 FROM table1 WHERE (field1 = $1)',
						values = { 2 }
					}, sel:toParam())
				end)
			end)
		end)

		describe('distinct queries', function()
			before_each(function()
				sel:fields({ 'field1', 'field2' }):from('table1')
			end)

			describe('>> from(table):distinct()', function()
				before_each(function()
					sel:distinct()
				end)

				it('toString', function()
					assert.is_equal('SELECT DISTINCT field1, field2 FROM table1', sel:toString())
				end)

				it('toParam', function()
					assert.is_same({
						text = 'SELECT DISTINCT field1, field2 FROM table1',
						values = {}
					}, sel:toParam())
				end)
			end)

			describe('>> from(table):distinct(field1)', function()
				before_each(function()
					sel:distinct('field1')
				end)

				it('toString', function()
					assert.is_equal('SELECT DISTINCT ON (field1) field1, field2 FROM table1', sel:toString())
				end)

				it('toParam', function()
					assert.is_same({
						text = 'SELECT DISTINCT ON (field1) field1, field2 FROM table1',
						values = {}
					}, sel:toParam())
				end)
			end)

			describe('>> from(table):distinct(field1, field2)', function()
				before_each(function()
					sel:distinct('field1', 'field2')
				end)

				it('toString', function()
					assert.is_equal('SELECT DISTINCT ON (field1, field2) field1, field2 FROM table1', sel:toString())
				end)

				it('toParam', function()
					assert.is_same({
						text = 'SELECT DISTINCT ON (field1, field2) field1, field2 FROM table1',
						values = {}
					}, sel:toParam())
				end)
			end)
		end)

		describe('cte queries', function()
			local sel2
			local sel3

			before_each(function()
				sel = squel.select()
				sel2 = squel.select()
				sel3 = squel.select()
			end)

			describe('>> query1:with(alias, query2)', function()
				before_each(function()
					sel:from('table1'):where('field1 = ?', 1)
					sel2:from('table2'):where('field2 = ?', 2)
					sel:with('someAlias', sel2)
				end)

				it('toString', function()
					assert.is_equal('WITH someAlias AS (SELECT * FROM table2 WHERE (field2 = 2)) '
						.. 'SELECT * FROM table1 WHERE (field1 = 1)', sel:toString())
				end)

				it('toParam', function()
					assert.is_same({
						text = 'WITH someAlias AS (SELECT * FROM table2 WHERE (field2 = $1)) '
							.. 'SELECT * FROM table1 WHERE (field1 = $2)',
						values = { 2, 1 }
					}, sel:toParam())
				end)
			end)

			describe('>> query1:with(alias1, query2):with(alias2, query2)', function()
				before_each(function()
					sel:from('table1'):where('field1 = ?', 1)
					sel2:from('table2'):where('field2 = ?', 2)
					sel3:from('table3'):where('field3 = ?', 3)
					sel:with('someAlias', sel2):with('anotherAlias', sel3)
				end)

				it('toString', function()
					assert.is_equal('WITH someAlias AS (SELECT * FROM table2 WHERE (field2 = 2)), '
						.. 'anotherAlias AS (SELECT * FROM table3 WHERE (field3 = 3)) '
						.. 'SELECT * FROM table1 WHERE (field1 = 1)', sel:toString())
				end)

				it('toParam', function()
					assert.is_same({
						text = 'WITH someAlias AS (SELECT * FROM table2 WHERE (field2 = $1)), '
							.. 'anotherAlias AS (SELECT * FROM table3 WHERE (field3 = $2)) '
							.. 'SELECT * FROM table1 WHERE (field1 = $3)',
						values = { 2, 3, 1 }
					}, sel:toParam())
				end)
			end)
		end)

		describe('union queries', function()
			local sel2

			before_each(function()
				sel = squel.select()
				sel2 = squel.select()
			end)

			describe('>> query1:union(query2)', function()
				before_each(function()
					sel:field('field1'):from('table1'):where('field1 = ?', 3)
					sel2:field('field1'):from('table1'):where('field1 < ?', 10)
					sel:union(sel2)
				end)

				it('toString', function()
					assert.is_equal('SELECT field1 FROM table1 WHERE (field1 = 3) '
						.. 'UNION (SELECT field1 FROM table1 WHERE (field1 < 10))', sel:toString())
				end)

				it('toParam', function()
					assert.is_same({
						text = 'SELECT field1 FROM table1 WHERE (field1 = $1) '
							.. 'UNION (SELECT field1 FROM table1 WHERE (field1 < $2))',
						values = { 3, 10 }
					}, sel:toParam())
				end)
			end)

			describe('>> query1:union_all(query2)', function()
				before_each(function()
					sel:field('field1'):from('table1'):where('field1 = ?', 3)
					sel2:field('field1'):from('table1'):where('field1 < ?', 10)
					sel:union_all(sel2)
				end)

				it('toString', function()
					assert.is_equal('SELECT field1 FROM table1 WHERE (field1 = 3) UNION ALL '
						.. '(SELECT field1 FROM table1 WHERE (field1 < 10))', sel:toString())
				end)

				it('toParam', function()
					assert.is_same({
						text = 'SELECT field1 FROM table1 WHERE (field1 = $1) UNION ALL '
							.. '(SELECT field1 FROM table1 WHERE (field1 < $2))',
						values = { 3, 10 }
					}, sel:toParam())
				end)
			end)
		end)
	end)

	it('Default query builder options', function()
		assert.is_same({
			replaceSingleQuotes = false,
			singleQuoteReplacement = "''",
			autoQuoteTableNames = false,
			autoQuoteFieldNames = false,
			autoQuoteAliasNames = false,
			useAsForTableAliasNames = true,
			nameQuoteCharacter = '`',
			tableAliasQuoteCharacter = '`',
			fieldAliasQuoteCharacter = '"',
			valueHandlers = {},
			parameterCharacter = '?',
			numberedParameters = true,
			numberedParametersPrefix = '$',
			numberedParametersStartAt = 1,
			separator = ' ',
			stringFormatter = nil
		}, squel.cls.DefaultQueryBuilderOptions)
	end)
end)
