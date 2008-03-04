package flight.db.activeRecord
{
	import flash.data.SQLColumnSchema;
	import flash.data.SQLSchemaResult;
	import flash.data.SQLStatement;
	import flash.data.SQLTableSchema;
	import flash.utils.describeType;
	
	import flight.db.DB;
	import flight.db.sql_db;
	
	use namespace sql_db;
	
	
	public class TableCreator
	{
		private static var tablesUpdated:Object = {};
		
		
		/**
		 * Creates a new table for this object if one does not already exist. In addition, will
		 * add new fields to existing tables if an object has changed
		 */
		public static function updateTable(obj:ActiveRecord, schema:SQLTableSchema = null):void
		{
			obj.connection.begin();
			
			var tableName:String = ActiveRecord.schemaTranslation.getTable(obj.className);
			var primaryKey:String = ActiveRecord.schemaTranslation.getPrimaryKey(obj.className);
			
			var stmt:SQLStatement = new SQLStatement();
			stmt.sqlConnection = obj.connection;
			var sql:String;
			
			// get all this object's properties we want to store in the database
			var def:XML = describeType(obj);
			var publicVars:XMLList = def.*.(
					(
						localName() == "variable" ||
						(localName() == "accessor" && @access == "readwrite")
					)
					&&
					(
						@type == "String" ||
						@type == "Number" ||
						@type == "Boolean" ||
						@type == "uint" ||
						@type == "int" ||
						@type == "Date" ||
						@type == "flash.utils.ByteArray"
					)
				);
			
			var field:XML;
			var fieldDef:Array
			
			if (!schema)
			{
				var dbschema:SQLSchemaResult = DB.getSchema(obj.connection);
				
				var schema:SQLTableSchema;
				
				// first, find the table this object represents
				if (dbschema)
				{
					for each (var tmpTable:SQLTableSchema in dbschema.tables)
					{
						if (tmpTable.name == tableName)
						{
							schema = tmpTable;
							break;
						}
					}
				}
			}
			
			// if no table was found, create it, otherwise, update any missing fields
			if (!schema)
			{
				var fields:Array = [];
				
				for each (field in publicVars)
				{
					fieldDef = [field.@name, dbTypes[field.@type]];
					
					if (field.@name == primaryKey)
						fieldDef.push("PRIMARY KEY AUTOINCREMENT");
					
					fields.push(fieldDef.join(" "));
				}
					
				sql = "CREATE TABLE " + tableName + " (" + fields.join(", ") + ")";
				stmt.text = sql;
				stmt.execute();
			}
			else
			// check if any fields differ or have been added
			{
				for each (field in publicVars)
				{
					var found:Boolean = false;
					for each (var column:SQLColumnSchema in schema.columns)
					{
						if (column.name == field.@name)
						{
							found = true;
							break;
						}
					}
					
					if (found)
						continue;
					
					// add the field to be created
					fieldDef = ["ADD", field.@name, dbTypes[field.@type]];
					
					sql = "ALTER TABLE " + tableName + " " + fieldDef.join(" ");
					stmt.text = sql;
					stmt.execute();
				}
			}
			
			obj.connection.commit();
		}
		
		sql_db static var dbTypes:Object = {
			"String": "VARCHAR",
			"Number": "DOUBLE",
			"Boolean": "BOOLEAN",
			"uint": "INTEGER",
			"int": "INTEGER",
			"Date": "DATETIME",
			"flash.utils.ByteArray": "BLOB"
		};
	}
}