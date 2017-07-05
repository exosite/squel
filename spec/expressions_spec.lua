describe('Expression builder base class', function()
	local Object = require('object')
	local R = require('moses')
	local squel = require('squel')

	local inst

	before_each(function()
		inst = squel.expr()
	end)

	it('extends BaseBuilder', function()
		assert.is_equal(true, Object.instanceof(inst, squel.cls.BaseBuilder))
	end)

	it('toString() returns empty', function()
		assert.is_equal('', inst:toString())
	end)

	describe('options', function()
		it('default options', function()
			assert.is_same(squel.cls.DefaultQueryBuilderOptions, inst.options)
		end)

		it('custom options', function()
			local e = squel.expr({
				separator = ',asdf'
			})

			local expected = R.extend({}, squel.cls.DefaultQueryBuilderOptions, {
				separator = ',asdf'
			})

			assert.is_same(expected, e.options)
		end)
	end)

	describe('and()', function()
		it('without an argument throws an error', function()
			assert.is_error(function()
				inst:AND()
			end, 'expression must be a string or builder instance')
		end)

		it('with an array throws an error', function()
			assert.is_error(function()
				inst:AND({ 1 })
			end, 'expression must be a string or builder instance')
		end)

		it('with an object throws an error', function()
			assert.is_error(function()
				inst:AND({})
			end, 'expression must be a string or builder instance')
		end)

		it('with a function throws an error', function()
			assert.is_error(function()
				inst:AND(function() end)
			end, 'expression must be a string or builder instance')
		end)

		it('with an Expression returns object instance', function()
			assert.is_equal(inst, inst:AND(squel.expr()))
		end)

		it('with a builder returns object instance', function()
			assert.is_equal(inst, inst:AND(squel.str()))
		end)

		it('with a string returns object instance', function()
			assert.is_equal(inst, inst:AND('bla'))
		end)
	end)

	describe('or()', function()
		it('without an argument throws an error', function()
			assert.is_error(function()
				inst:OR()
			end, 'expression must be a string or builder instance')
		end)

		it('with an array throws an error', function()
			assert.is_error(function()
				inst:OR({ 1 })
			end, 'expression must be a string or builder instance')
		end)

		it('with an object throws an error', function()
			assert.is_error(function()
				inst:OR({})
			end, 'expression must be a string or builder instance')
		end)

		it('with a function throws an error', function()
			assert.is_error(function()
				inst:OR(function() end)
			end, 'expression must be a string or builder instance')
		end)

		it('with an Expression returns object instance', function()
			assert.is_equal(inst, inst:OR(squel.expr()))
		end)

		it('with a builder returns object instance', function()
			assert.is_equal(inst, inst:OR(squel.str()))
		end)

		it('with a string returns object instance', function()
			assert.is_equal(inst, inst:OR('bla'))
		end)
	end)

	describe("and('test = 3')", function()
		before_each(function()
			inst:AND('test = 3')
		end)

		it('>> toString()', function()
			assert.is_equal('test = 3', inst:toString())
		end)

		it('>> toParam()', function()
			assert.is_same({
				text = 'test = 3',
				values = {}
			}, inst:toParam())
		end)

		describe('>> and("flight = \'4\'")', function()
			before_each(function()
				inst:AND("flight = '4'")
			end)

			it('>> toString()', function()
				assert.is_equal("test = 3 AND flight = '4'", inst:toString())
			end)

			it('>> toParam()', function()
				assert.is_same({
					text = "test = 3 AND flight = '4'",
					values = {}
				}, inst:toParam())
			end)

			describe(">> or('dummy IN (1, 2, 3)')", function()
				before_each(function()
					inst:OR('dummy IN (1, 2, 3)')
				end)

				it('>> toString()', function()
					assert.is_equal("test = 3 AND flight = '4' OR dummy IN (1, 2, 3)", inst:toString())
				end)

				it('>> toParam()', function()
					assert.is_same({
						text = "test = 3 AND flight = '4' OR dummy IN (1, 2, 3)",
						values = {}
					}, inst:toParam())
				end)
			end)
		end)
	end)

	describe("and('test = ?', 'NULL')", function()
		before_each(function()
			inst:AND('test = ?', 'NULL')
		end)

		it('>> toString()', function()
			assert.is_equal('test = NULL', inst:toString())
		end)

		it('>> toParam()', function()
			assert.is_same({
				text = 'test = ?',
				values = { 'NULL' }
			}, inst:toParam())
		end)
	end)

	describe("and('test = ?', 3)", function()
		before_each(function()
			inst:AND('test = ?', 3)
		end)

		it('>> toString()', function()
			assert.is_equal('test = 3', inst:toString())
		end)

		it('>> toParam()', function()
			assert.is_same({
				text = 'test = ?',
				values = { 3 }
			}, inst:toParam())
		end)

		describe(">> and('flight = ?', '4')", function()
			before_each(function()
				inst:AND('flight = ?', '4')
			end)

			it('>> toString()', function()
				assert.is_equal("test = 3 AND flight = '4'", inst:toString())
			end)

			it('>> toParam()', function()
				assert.is_same({
					text = 'test = ? AND flight = ?',
					values = { 3, '4' }
				}, inst:toParam())
			end)

			describe(">> or('dummy IN ?', { false, 2, 'NULL', 'str' })", function()
				before_each(function()
					inst:OR('dummy IN ?', { false, 2, 'NULL', 'str' })
				end)

				it('>> toString()', function()
					assert.is_equal("test = 3 AND flight = '4' OR dummy IN (FALSE, 2, NULL, 'str')", inst:toString())
				end)

				it('>> toParam()', function()
					assert.is_same({
						text = "test = ? AND flight = ? OR dummy IN (?, ?, ?, ?)",
						values = { 3, '4', false, 2, 'NULL', 'str' }
					}, inst:toParam())
				end)
			end)
		end)
	end)

	describe('or("test = 3")', function()
		before_each(function()
			inst:OR("test = 3")
		end)

		it('>> toString()', function()
			assert.is_equal('test = 3', inst:toString())
		end)

		it('>> toParam()', function()
			assert.is_same({
				text = 'test = 3',
				values = {}
			}, inst:toParam())
		end)

		describe('>> or("flight = \'4\'")', function()
			before_each(function()
				inst:OR("flight = '4'")
			end)

			it('>> toString()', function()
				assert.is_equal("test = 3 OR flight = '4'", inst:toString())
			end)

			it('>> toString()', function()
				assert.is_same({
					text = "test = 3 OR flight = '4'",
					values = {}
				}, inst:toParam())
			end)

			describe(">> and('dummy IN (1, 2, 3)')", function()
				before_each(function()
					inst:AND('dummy IN (1, 2, 3)')
				end)

				it('>> toString()', function()
					assert.is_equal("test = 3 OR flight = '4' AND dummy IN (1, 2, 3)", inst:toString())
				end)

				it('>> toParam()', function()
					assert.is_same({
						text = "test = 3 OR flight = '4' AND dummy IN (1, 2, 3)",
						values = {}
					}, inst:toParam())
				end)
			end)
		end)
	end)

	describe("or('test = ?', 3)", function()
		before_each(function()
			inst:OR('test = ?', 3)
		end)

		it('>> toString()', function()
			assert.is_equal('test = 3', inst:toString())
		end)

		it('>> toParam()', function()
			assert.is_same({
				text = 'test = ?',
				values = { 3 }
			}, inst:toParam())
		end)

		describe(">> or('flight = ?', '4')", function()
			before_each(function()
				inst:OR('flight = ?', '4')
			end)

			it('>> toString()', function()
				assert.is_equal("test = 3 OR flight = '4'", inst:toString())
			end)

			it('>> toParam()', function()
				assert.is_same({
					text = "test = ? OR flight = ?",
					values = { 3, '4' }
				}, inst:toParam())
			end)

			describe(">> and('dummy IN ?', { false, 2, 'NULL', 'str' })", function()
				before_each(function()
					inst:AND('dummy IN ?', { false, 2, 'NULL', 'str' })
				end)

				it('>> toString()', function()
					assert.is_equal("test = 3 OR flight = '4' AND dummy IN (FALSE, 2, NULL, 'str')", inst:toString())
				end)

				it('>> toParam()', function()
					assert.is_same({
						text = "test = ? OR flight = ? AND dummy IN (?, ?, ?, ?)",
						values = { 3, '4', false, 2, 'NULL', 'str' }
					}, inst:toParam())
				end)
			end)
		end)
	end)

	describe("or('test = ?', 4)", function()
		before_each(function()
			inst:OR('test = ?', 4)
		end)

		describe(">> and(expr():OR('inner = ?', 1))", function()
			before_each(function()
				inst:AND(squel.expr():OR('inner = ?', 1))
			end)

			it('>> toString()', function()
				assert.is_equal('test = 4 AND (inner = 1)', inst:toString())
			end)

			it('>> toParam()', function()
				assert.is_same({
					text = 'test = ? AND (inner = ?)',
					values = { 4, 1 }
				}, inst:toParam())
			end)
		end)

		describe(">> and(expr():OR('inner = ?', 1):OR(expr():AND('another = ?', 34)))", function()
			before_each(function()
				inst:AND(squel.expr():OR('inner = ?', 1):OR(squel.expr():AND('another = ?', 34)))
			end)

			it('>> toString()', function()
				assert.is_equal('test = 4 AND (inner = 1 OR (another = 34))', inst:toString())
			end)

			it('>> toParam()', function()
				assert.is_same({
					text = 'test = ? AND (inner = ? OR (another = ?))',
					values = { 4, 1, 34 }
				}, inst:toParam())
			end)
		end)
	end)

	describe('custom parameter character: @@', function()
		before_each(function()
			inst.options.parameterCharacter = '@@'
		end)

		describe("and('test = @@', 3):AND('flight = @@', '4'):OR('dummy IN @@', { false, 2, 'NULL', 'str' })", function()
			before_each(function()
				inst
					:AND('test = @@', 3)
					:AND('flight = @@', '4')
					:OR('dummy IN @@', { false, 2, 'NULL', 'str' })
			end)

			it('>> toString()', function()
				assert.is_equal("test = 3 AND flight = '4' OR dummy IN (FALSE, 2, NULL, 'str')", inst:toString())
			end)

			it('>> toParam()', function()
				assert.is_same({
					text = 'test = @@ AND flight = @@ OR dummy IN (@@, @@, @@, @@)',
					values = { 3, '4', false, 2, 'NULL', 'str' }
				}, inst:toParam())
			end)
		end)
	end)

	it('cloning', function()
		local newinst = inst:OR('test = 4'):OR('inner = 1'):OR('inner = 2'):clone()
		newinst:OR('inner = 3')

		assert.is_equal('test = 4 OR inner = 1 OR inner = 2', inst:toString())
		assert.is_equal('test = 4 OR inner = 1 OR inner = 2 OR inner = 3', newinst:toString())
	end)

	describe('any type of builder', function()
		before_each(function()
			inst:OR('b = ?', 5):OR(squel.select():from('blah'):where('a = ?', 9))
		end)

		it('toString', function()
			assert.is_equal('b = 5 OR (SELECT * FROM blah WHERE (a = 9))', inst:toString())
		end)

		it('toParam', function()
			assert.is_same({
				text = 'b = ? OR (SELECT * FROM blah WHERE (a = ?))',
				values = { 5, 9 }
			}, inst:toParam())
		end)
	end)

	describe('#286 - nesting', function()
		before_each(function()
			inst = squel.expr()
				:AND(squel.expr()
					:AND(squel.expr()
						:AND('A')
						:AND('B')
					)
					:OR(squel.expr()
						:AND('C')
						:AND('D')
					)
				)
				:AND('E')
		end)

		it('toString', function()
			assert.is_equal('((A AND B) OR (C AND D)) AND E', inst:toString())
		end)

		it('toParam', function()
			assert.is_same({
				text = '((A AND B) OR (C AND D)) AND E',
				values = {}
			}, inst:toParam())
		end)
	end)
end)
