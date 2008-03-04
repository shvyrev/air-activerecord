package flight.db
{
	import flash.data.SQLConnection;
	import flash.data.SQLSchemaResult;
	import flash.filesystem.File;
	import flash.utils.Dictionary;
	
	public class DB
	{
		protected static var schemas:Dictionary = new Dictionary();
		protected static var aliases:Object = {};
		protected static var cache:Object = {};
		
		/**
		 * Returns a connection by the registered alias and with the appropriate synchronisation. This provides
		 * a cache for the connection objects to be used. The main.db database is preregistered under the alias
		 * "main", so a call to getConnection with no parameters will return the default application database.
		 */
		public static function getConnection(alias:String = "main", isSync:Boolean = false):SQLConnection
		{
			var key:String = alias + " - " + (isSync ? "sync" : "async");
			
			if (key in cache)
				return cache[key];
			
			if ( !(alias in aliases))
				return null;
			
			var file:File = aliases[alias] is File ? aliases[alias] as File : File.applicationStorageDirectory.resolvePath(aliases[alias]);
			var conn:SQLConnection = new SQLConnection();
			if (isSync)
				conn.open(file);
			else
				conn.openAsync(file);
			
			cache[key] = conn;
			
			return conn;
		}
		
		/**
		 * Registers a database file with an alias for the database. This allows connection objects
		 * to be created, retrieved, and cached by the getConnection method.
		 */
		public static function registerConnectionAlias(fileNameOrObject:Object, alias:String):void
		{
			aliases[alias] = fileNameOrObject is File ? fileNameOrObject.nativePath : fileNameOrObject;
		}
		
		// this private method pre-registers the main database to the system
		private static var init:* = function():void {
			registerConnectionAlias("main.db", "main");
		}();
		
		/**
		 * Returns and caches the schema for a connection to a database
		 */
		public static function getSchema(conn:SQLConnection):SQLSchemaResult
		{
			if ( !(conn in schemas))
			{
				conn.loadSchema();
				schemas[conn] = conn.getSchemaResult();
			}
			
			return schemas[conn];
		}
		
		/**
		 * Forces a refresh of a schema, used when a table update has been made or tables have been added
		 */
		public static function refreshSchema(conn:SQLConnection):SQLSchemaResult
		{
			delete schemas[conn];
			return getSchema(conn);
		}
	}
}