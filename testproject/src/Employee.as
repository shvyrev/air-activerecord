package
{
	import flight.db.activeRecord.ActiveRecord;
	
	public dynamic class Employee extends ActiveRecord
	{
		public var employerId:uint;
		public var name:String;
		public var position:String;
		public var hireDate:Date;
		public var salary:Number;
		public var created:Date;
		public var modified:Date;
	}
}