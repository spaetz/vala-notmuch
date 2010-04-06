using Notmuch;

class AddressMatcher {
	/* contains the Database */
	private Notmuch.Database db;
	/* Full path of the notmuch database */
	private string user_db_path = null;
	/* User's primary email */
	private string user_primary_email = null;

	private struct MailAddress_freq {
		public string address;
		public uint occurances;
	}

	/* Constructor */
	public AddressMatcher() {
		/* Set the user's database location */
		//TODO: catch errors
		var config = new KeyFile ();
		/* honor NOTMUCH_CONFIG, the use homedir to read config file */
		var home = Environment.get_variable("NOTMUCH_CONFIG");
		if (home == null) {
			home = Environment.get_home_dir ();
		}
		try {
			config.load_from_file (home+"/.notmuch-config", KeyFileFlags.NONE);
			this.user_db_path = config.get_string ("database", "path");
		} catch (Error ex) {}
		try {
			this.user_primary_email = config.get_string ("user", "primary_email");
		} catch (Error ex) {}
	}

	/* Used to sort the email addresses from most to least used */
	/*private static int revsort_by_freq(MailAddress_freq* mail1, 
									   MailAddress_freq* mail2){
		if (mail1->occurances == mail2->occurances) return 0;
		else if (mail1->occurances > mail2->occurances) return -1;
		else return 1;

		}*/

	/* Used to sort the email addresses from least to most used */
	private static int sort_by_freq(MailAddress_freq* mail1, 
									MailAddress_freq* mail2){
		if (mail1->occurances == mail2->occurances) return 0;
		else if (mail1->occurances > mail2->occurances) return 1;
		else return -1;
	}

	public void run(string? name) {
		/* Open the database */
		this.db = new Notmuch.Database.open(this.user_db_path);
		var querystr = new StringBuilder ();
		if (name != null)
			querystr.append("to:"+name+"*");
		if (this.user_primary_email != null)
			querystr.append(" from:" + this.user_primary_email);
		var q = new Query.create(db, querystr.str);
		var msgs = q.search_messages();

		/* hashtable with mail address (hash) and number of occurances */
		var ht = new HashTable<string,uint>.full(GLib.str_hash, str_equal, 
												 g_free, null);
		Regex re = null;
		//regex from http://regexlib.com/DisplayPatterns.aspx
		
		try {
			re = new Regex("\\b\\w+([-+.]\\w+)*\\@\\w+[-\\.\\w]*\\.([-\\.\\w]+)*\\w\\b",RegexCompileFlags.UNGREEDY);
		} catch (GLib.RegexError ex) { }

		/* fill the hashtable */
		while (msgs.valid()) {
			MatchInfo matches;
			var msg = msgs.get();
			var froms = (string)msg.get_header("to");
			var found = re.match(froms, 0, out matches);
			while (found) {
				var from = matches.fetch(0);
				from.strip();
				from = from.down();
				/* not all fetched addresses fit our search criteria,
				*  so only use those that do, ie
				*  'name' is contained in real name <email@address> */
				try { found = matches.next(); }
				catch (RegexError ex) {}
				var is_match =  Regex.match_simple (name, 
													from,
													RegexCompileFlags.CASELESS);
				if (!is_match) continue;

				uint occurs = ht.lookup(from) +1 ;
				ht.replace(from, occurs);
			}
			msg.destroy(); //get 'too many files open' if we don't destroy
			msgs.move_to_next();
		}

		/* SList with unique addresses which will be sorted after occurences*/
		var addrs = new SList<MailAddress_freq?>();
		foreach (var addr in ht.get_keys()) {
			MailAddress_freq mail = { addr, ht.lookup(addr) };
			addrs.prepend(mail);
		}

		/* Sort addresses by frequency (least-to-most */
		addrs.sort((GLib.CompareFunc)sort_by_freq);

		/* output mail addresses according to popularity*/
		foreach (var a in addrs) {
			var from = a.address;
			stdout.printf("%s\n",from);
		}
	}
} /*End of class AddressMatcher*/

public static int main(string[] args) {
	var app = new AddressMatcher();
	app.run(args[1]);
	return 0;
}


//DEBUG SNIPPETS START HERE
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
