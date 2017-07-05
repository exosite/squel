describe('Case expression builder base class', function()
	local Object = require('object')
	local R = require('moses')
	local squel = require('squel')

	local func
	local inst

	before_each(function()
		func = squel.case
		inst = func()
	end)

	it('extends BaseBuilder', function()
		assert.is_equal(true, Object.instanceof(inst, squel.cls.BaseBuilder))
	end)

	it('toString() returns NULL', function()
		assert.is_equal('NULL', inst:toString())
	end)

	describe('options', function()
		it('default options', function()
			assert.is_same(squel.cls.DefaultQueryBuilderOptions, inst.options)
		end)

		it('custom options', function()
			local e = func({
				separator = ',asdf'
			})

			local expected = R.extend({}, squel.cls.DefaultQueryBuilderOptions, {
				separator = ',asdf'
			})

			assert.is_same(expected, e.options)
		end)
	end)

	describe('build expression', function()
		describe('>> WHEN():THEN()', function()
			before_each(function()
				inst:WHEN('?', 'foo'):THEN('bar')
			end)

			it('toString', function()
				assert.is_equal("CASE WHEN ('foo') THEN 'bar' ELSE NULL END", inst:toString())
			end)

			it('toParam', function()
				assert.is_same({
					text = "CASE WHEN (?) THEN 'bar' ELSE NULL END",
					values = { 'foo' }
				}, inst:toParam())
			end)
		end)

		describe('>> WHEN():THEN():ELSE()', function()
			before_each(function()
				inst:WHEN('?', 'foo'):THEN('bar'):ELSE('foobar')
			end)

			it('toString', function()
				assert.is_equal("CASE WHEN ('foo') THEN 'bar' ELSE 'foobar' END", inst:toString())
			end)

			it('toParam', function()
				assert.is_same({
					text = "CASE WHEN (?) THEN 'bar' ELSE 'foobar' END",
					values = { 'foo' }
				}, inst:toParam())
			end)
		end)
	end)

	describe('field case', function()
		before_each(function()
			inst = func('name'):WHEN('?', 'foo'):THEN('bar')
		end)

		it('toString', function()
			assert.is_equal("CASE name WHEN ('foo') THEN 'bar' ELSE NULL END", inst:toString())
		end)

		it('toParam', function()
			assert.is_same({
				text = "CASE name WHEN (?) THEN 'bar' ELSE NULL END",
				values = { 'foo' }
			}, inst:toParam())
		end)
	end)
end)
