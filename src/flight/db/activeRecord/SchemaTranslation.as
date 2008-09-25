package flight.db.activeRecord
{
	import flight.utils.Inflector;
	
	public class SchemaTranslation
	{
		
		public function getTable(className:String):String
		{
			return Inflector.lowerFirst(Inflector.pluralize(className));
		}
		
		public function getPrimaryKey(className:String):String
		{
			return "id";
		}
		
		public function getForeignKey(className:String, foreignClassName:String):String
		{
			return Inflector.lowerFirst(foreignClassName) + "_id";
		}
		
		public function getJoinTable(className1:String, className2:String):String
		{
			return getTable(className1) + "_" + getTable(className2);
		}
		
		public function getField(propertyName:String):String
		{
			return propertyName;
		}
		
		public function getCreatedField():String
		{
			return "created";
		}
		
		public function getModifiedField():String
		{
			return "modified";
		}
	}
}