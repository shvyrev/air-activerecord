package
{
	import flight.db.activeRecord.ActiveRecord;
	
	[RelatedTo(name="employees", className="Employee", multiple)]
	
	public dynamic class Employer extends ActiveRecord
	{
		public var name:String;
		public var created:Date;
		public var modified:Date;
	}
}