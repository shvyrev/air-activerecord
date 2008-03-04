package flight.utils
{
	import flash.utils.Dictionary;
	import flash.utils.describeType;
	import flash.utils.getDefinitionByName;
	
	public class Reflection
	{
		protected static var cache:Dictionary = new Dictionary();
		
		public function Reflection()
		{
		}
		
		public static function describe(obj:Object):XML
		{
			if (obj is String || obj is XML || obj is XMLList)
				obj = getDefinitionByName(obj.toString());
			else if ( !(obj is Class) )
				obj = obj.constructor;
			
			if (obj in cache)
				return cache[obj];
			
			var info:XML = describeType(obj).factory[0];
			cache[obj] = info;
			return info;
		}
		
		public static function getMetadata(obj:Object, metadataType:String, includeSuperClasses:Boolean = false):XMLList
		{
			var info:XML = describe(obj);
			var metadata:XMLList = info..metadata.(@name == metadataType);
			
			if (includeSuperClasses && info.extendsClass.length())
				metadata += getMetadata(info.extendsClass[0].@type, metadataType, true);
			
			return metadata;
		}
	}
}