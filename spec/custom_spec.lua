describe('Custom queries', function()
	local squel = require('squel')

	it('custom query', function()
		local CommandBlock = squel.cls.Block:extend()
			function CommandBlock:command(command, arg)
				self._command = command
				self._arg = arg
			end

			function CommandBlock:compress(level)
				self:command('compress', level)
			end

			function CommandBlock:_toParamString(options)
				local totalStr = self._command:upper()
				local totalValues = {}

				if (not options.buildParameterized) then
					totalStr = totalStr .. (' %s'):format(self._arg)
				else
					totalStr = totalStr .. ' ?'
					table.insert(totalValues, self._arg)
				end

				return {
					text = totalStr,
					values = totalValues,
				}
			end

		local PragmaQuery = squel.cls.QueryBuilder:extend()
			function PragmaQuery:initialize(options)
				local blocks = {
					squel.cls.StringBlock:new(options, 'PRAGMA'),
					CommandBlock:new(options),
				 }

				squel.cls.QueryBuilder.initialize(self, options, blocks)
			end

		-- squel method
		squel.pragma = function(options)
			return PragmaQuery:new(options)
		end

		local qry = squel.pragma():compress(9)

		assert.is_equal('PRAGMA COMPRESS 9', qry:toString())
		assert.is_same({
			text = 'PRAGMA COMPRESS ?',
			values = { 9 },
		}, qry:toParam())
	end)
end)
