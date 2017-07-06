local SQL = require('squel').useFlavour('postgres')
local inspect = require('inspect')

SQL.cls.DefaultQueryBuilderOptions.replaceSingleQuotes = true

local asset_id = 3
local file_name = 'abc'

local sql = SQL.insert()
        :into('files')
        :set('asset_id', asset_id)
        :set('file_name', file_name)
        :onConflictOnConstraint('file_per_asset', {
                file_name = SQL.str('EXCLUDED.file_name'),
        })
        :returning('file_id')
        -- :toParam()
        :toString()

print(inspect(sql))
