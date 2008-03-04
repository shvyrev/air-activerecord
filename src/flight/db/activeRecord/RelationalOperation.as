package flight.db.activeRecord
{
	import flight.db.sql_db;
	
	import flash.data.SQLStatement;
	
	use namespace sql_db;
	
	public class RelationalOperation
	{
		public static const BELONGS_TO:String = "belongsTo";
		public static const HAS_ONE:String = "hasOne";
		public static const HAS_MANY:String = "hasMany";
		public static const MANY_TO_MANY:String = "manyToMany";
		public static const UNKNOWN:String = "";
		
		public var relationship:String = "";
		protected var thisObj:ActiveRecord;
		protected var thatObj:ActiveRecord;
		protected var thisClass:String;
		protected var thatClass:String;
		protected var thisTable:String;
		protected var thatTable:String;
		protected var thisPrimaryKey:String;
		protected var thatPrimaryKey:String;
		protected var thisForeignKey:String;
		protected var thatForeignKey:String;
		protected var thisFields:Object;
		protected var thatFields:Object;
		protected var cond:Object;
		protected var joinTable:String;
		protected var joins:String;
		
		public var error:String;
		
		public function RelationalOperation(thisObj:ActiveRecord, clazz:Class, multiple:Boolean = false)
		{
			this.thisObj = thisObj;
			try {
				thatObj = new clazz();
			} catch (e:Error) {
				throw new Error("Related Class must be of type ActiveRecord");
			}
			
			// get all information needed to find and load the relationship
			thisClass = thisObj.className;
			thatClass = thatObj.className;
			
			var schTran:SchemaTranslation = ActiveRecord.schemaTranslation;
			
			thisTable = schTran.getTable(thisClass);
			thatTable = schTran.getTable(thatClass);
			
			thisPrimaryKey = schTran.getPrimaryKey(thisClass);
			thatPrimaryKey = schTran.getPrimaryKey(thatClass);
			
			thisForeignKey = schTran.getForeignKey(thatClass, thisClass);
			thatForeignKey = schTran.getForeignKey(thisClass, thatClass);
			
			thisFields = thisObj.getFields();
			thatFields = thatObj.getFields();
			
			if (!thisFields)
				throw new Error("Cannot find table or columns in '" + thisTable + "' for ActiveRecord class '" + thisClass + "'");
			
			if (!thatFields)
				throw new Error("Cannot find table or columns in '" + thatTable + "' for ActiveRecord class '" + thatClass + "'");
			
			if (!multiple)
			{
				if (thisFields[thatForeignKey])			// BELONGS TO relationship
				{
					relationship = BELONGS_TO;
				}
				else if (thatFields[thisForeignKey])	// HAS ONE relationship
				{
					relationship = HAS_ONE;
				}
														// Cannot find the relationship
			}
			else
			{
				if (thatFields[thisForeignKey])			// HAS MANY relationship
				{
					relationship = HAS_MANY;
				}
				else									// MANY TO MANY relationship
				{
					relationship = MANY_TO_MANY;
					joinTable = schTran.getJoinTable(thisClass, thatClass);
					var joinFields:Object = thisObj.getFields(joinTable);
					if (!joinFields)
					{
						joinTable = schTran.getJoinTable(thatClass, thisClass);
						joinFields = thisObj.getFields(joinTable);
						if (!joinFields)
							throw new Error("Join not found");	// Cannot find the relationship
					}
					
					joins = " JOIN " + joinTable + " ON " + thatTable + "." + thatPrimaryKey + " = " + joinTable + "." + thatForeignKey;
				}
			}
		}
		
		public function loadRelated(conditions:String = null, conditionParams:Array = null, order:String = null, limit:uint = 0, offset:uint = 0):Object
		{
			switch (relationship)
			{
				case BELONGS_TO:
					return thatObj.findFirst(thatPrimaryKey + " = ?", [thisObj[thatForeignKey]]);
				case HAS_ONE:
					cond = mergeConditions(conditions, conditionParams, thisForeignKey + " = ?", [thisObj.id]);
					return thatObj.findFirst(cond.conditions, cond.params, order);
				case HAS_MANY:
					cond = mergeConditions(conditions, conditionParams, thisForeignKey + " = ?", [thisObj.id]);
					return thatObj.findAll(cond.conditions, cond.params, order, limit, offset);
				case MANY_TO_MANY:
					cond = mergeConditions(conditions, conditionParams, joinTable + "." + thisForeignKey + " = ?", [thisObj.id]);
					return thatObj.findAll(cond.conditions, cond.params, order, limit, offset, joins);
				default:
					return null;
			}
		}
		
		public function countRelated(conditions:String = null, conditionParams:Array = null):uint
		{
			switch (relationship)
			{
				case BELONGS_TO:
					return thatObj.count(thatPrimaryKey + " = ?", [thisObj[thatForeignKey]]);
				case HAS_ONE:
					cond = mergeConditions(conditions, conditionParams, thisForeignKey + " = ?", [thisObj.id]);
					return thatObj.count(cond.conditions, cond.params);
				case HAS_MANY:
					cond = mergeConditions(conditions, conditionParams, thisForeignKey + " = ?", [thisObj.id]);
					return thatObj.count(cond.conditions, cond.params);
				case MANY_TO_MANY:
					cond = mergeConditions(conditions, conditionParams, joinTable + "." + thisForeignKey + " = ?", [thisObj.id]);
					return thatObj.count(cond.conditions, cond.params, joins);
				default:
					return 0;
			}
		}
		
		public function saveRelated(property:Object = null):Boolean
		{
			if (!property) return false;
			
			if (property is ActiveRecord)
				thatObj = property as ActiveRecord;
			
			var obj:ActiveRecord;
			var result:Boolean;
			thisObj.connection.begin();
			
			if (relationship != BELONGS_TO && !thisObj.id)
				thisObj.save();
			
			try
			{
				switch (relationship)
				{
					case BELONGS_TO && property is ActiveRecord:
						thatObj.save();
						thisObj[thatForeignKey] = thatObj.id;
						result = thisObj.save();
						break;
					case HAS_ONE:
						thatObj[thisForeignKey] = thisObj.id;
						result = thatObj.save();
						break;
					case HAS_MANY:
						for each (obj in property)
						{
							obj[thisForeignKey] = thisObj.id;
							obj.save();
						}
						result = true;
						break;
					case MANY_TO_MANY:
						var insStmt:SQLStatement = new SQLStatement();
						insStmt.text = "INSERT OR REPLACE INTO " + joinTable + " (" + thisForeignKey + ", " + thatForeignKey + ") VALUES (?, ?)";
						insStmt.parameters[1] = thisObj.id;
						
						for each (obj in property)
						{
							obj.save();
							insStmt.parameters[2] = obj.id;
							insStmt.execute();
						}
						result = true;
						break;
					default:
						result = false;
				}
				
				thisObj.connection.commit();
			}
			catch(e:Error)
			{
				thisObj.connection.rollback();
			}
			
			return result;
		}
		
		public function deleteRelated(conditions:String = null, conditionParams:Array = null, joinOnly:Boolean = true):uint
		{
			switch (relationship)
			{
				case BELONGS_TO:
					return thatObj.deleteAll(thatPrimaryKey + " = ?", [thisObj[thatForeignKey]]);
				case HAS_ONE:
					cond = mergeConditions(conditions, conditionParams, thisForeignKey + " = ?", [thisObj.id]);
					return thatObj.deleteAll(cond.conditions, cond.params);
				case HAS_MANY:
					cond = mergeConditions(conditions, conditionParams, thisForeignKey + " = ?", [thisObj.id]);
					return thatObj.deleteAll(cond.conditions, cond.params);
				case MANY_TO_MANY:
					cond = mergeConditions(conditions, conditionParams, joinTable + "." + thisForeignKey + " = ?", [thisObj.id]);
					
					var all:Array = thatObj.findAll(cond.conditions, cond.params, joins);
					for (var i:int = 0; i < all.length; i++)
						all[i] = all[i].id;
					
					var allIds:String = "(" + all.join(",") + ")";
					thisObj.query("DELETE FROM " + joinTable + " WHERE " + thatForeignKey + " IN " + allIds);
					
					if (!joinOnly)
						thisObj.query("DELETE FROM " + thatTable + " WHERE " + thatPrimaryKey + " IN " + allIds);
					
					return all.length;
				default:
					return 0;
			}
		}
		
		
		sql_db function mergeConditions(conditions1:String, conditions1Params:Array, conditions2:String, conditions2Params:Array):Object
		{
			var result:Object = {
				conditions: "",
				params: []
			};
			
			// merge text
			if (conditions1 && conditions2)
				result.conditions = conditions1 + " AND " + conditions2;
			else if (conditions1)
				result.conditions = conditions1;
			else if (conditions2)
				result.conditions = conditions2;
			
			// merge parameters
			if (conditions1Params && conditions1Params.length && conditions2Params && conditions2Params.length)
				result.params = conditions1Params.concat(conditions2Params);
			else if (conditions1Params && conditions1Params.length)
				result.params = conditions1Params;
			else if (conditions2Params && conditions2Params.length)
				result.params = conditions2Params;
			
			return result;
		}
	}
}