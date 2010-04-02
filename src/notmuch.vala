using Notmuch;

public static int main(string[] args) {
	Notmuch.Database db;

	db = new Notmuch.Database.open("/home/spaetz/mail", Database.Mode.READ_ONLY);
	/*
	var m =  db.find_message("test@test33");
	if (m == null)
		message("No such message");
	else
		message("path %s",m.get_thread_id());
	*/
	/*
	var tags = db.get_all_tags();
	while (tags.valid()) {
		var tag = tags.get();
		message("tag %s",tag);
		tags.move_to_next();
		}*/

	var q = new Query.create(db,args[1]);
	var msgs = q.search_messages();

	while (msgs.valid()) {
		var msg = msgs.get();
		string from = msg.get_header("from");
		message("%s",from);
		msgs.move_to_next();
	}

	return 0;
}