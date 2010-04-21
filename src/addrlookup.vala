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
	private static int sort_by_freq(MailAddress_freq* mail1, 
									MailAddress_freq* mail2){
		if (mail1->occurances == mail2->occurances) return 0;
		else if (mail1->occurances > mail2->occurances) return -1;
		else return 1;
	}


	/* find most frequent real name for each mail address */
	public string frequent_fullname(HashTable<string,uint> frequencies) {
		uint maxfreq = 0;
		string fullname = null;

		foreach (var mail in frequencies.get_keys()) {
			uint freq = frequencies.lookup(mail);
			if ((freq > maxfreq && " " in mail) || (frequencies.size() == 1)) {
				/* only use the entry if it has a real name */
				/* or if this is the only entry */
				maxfreq = freq;
				fullname = mail;
			}
		}
		return fullname;
	}

	/* Retrieves 'to' header, and sorts findings by frequency.
	 * Returns: a string[] of email addresses (with fullnames)
	 */
	public string[] addresses_by_frequency(Notmuch.Messages msgs,
										   string name,
										   bool sort_asc) {
		string[] return_value = null;

		/* hashtable with mail address (hash) and number of occurances */
		var ht = new HashTable<string,uint>.full(GLib.str_hash, str_equal, 
												 g_free, null);

		/* Hashtable pointing from lower case email addresses to a
		 * HashTable with "real name + email address" ->
		 * occurances. */
		//TODO: do we leak the value Hashtable?
		var addr2realname = new HashTable<string,HashTable>.full(
			GLib.str_hash, str_equal, g_free, null);

		/* email-identifying regex based on 
		 *  http://regexlib.com/DisplayPatterns.aspx
		 */
		Regex re = null;
		try {
			re = new Regex("\\s*((\\\"(\\\\.|[^\\\\\"])*\\\"|[^,])*" +
						   "<?(?P<mail>\\b\\w+([-+.]\\w+)*\\@\\w+[-\\.\\w]*\\.([-\\.\\w]+)*\\w\\b)>?)");
		} catch (GLib.RegexError ex) { }

		string[] headers = {"to","from","cc","bcc"};
		/* go through all messages and fill the hashtable */
		while (msgs.valid()) {
			MatchInfo matches;
			var msg = msgs.get();
			/* go through all defined headers */
			foreach (string header in headers) {
				var froms = (string)msg.get_header(header);
				var found = re.match(froms, 0, out matches);

				/* go through all mail addresses in this header */
				while (found) {
					var from = matches.fetch(1);
					var addr = matches.fetch_named("mail");
					addr = addr.down();
				
					/* forward to next email address for the next while loop */
					try { found = matches.next(); }
					catch (RegexError ex) {}

					/* not all fetched addresses fit our search criteria,
					 *  so only use those that do, ie 'name' is a word beginning
					 *  in "real name <email@address>" */
					var is_match =  Regex.match_simple ("\\b" + name,
													from,
													RegexCompileFlags.CASELESS);
					if (!is_match) continue;

					/* increase ht value by one for the lower case email */
					uint occurs = ht.lookup(addr) +1 ;
					ht.replace(addr, occurs);

					HashTable<string,uint> realname_freq = 
					addr2realname.lookup(addr);
					if (realname_freq == null) {
						/* Create a new hashtable to insert */
						realname_freq
						    = new HashTable<string,uint>.full(
							  GLib.str_hash, str_equal, null, null);
						addr2realname.insert(addr, realname_freq);
					}
				occurs = realname_freq.lookup(from) +1;
				realname_freq.replace(from, occurs);

				}
			}
			msg.destroy(); //get 'too many files open' if we don't destroy
			msgs.move_to_next();
		}
		
		/* SList with unique addresses (to be sorted after occurances)*/
		var addrs = new SList<MailAddress_freq?>();

		/* Populate and sort addresses by frequency (least-to-most) */
		foreach (var addr in ht.get_keys()) {
			MailAddress_freq mail = { addr, ht.lookup(addr) };
			addrs.prepend(mail);
			}

		addrs.sort((GLib.CompareFunc)sort_by_freq);

		/* add most frequent real name for each mail address */
		foreach (var addr in addrs) {
			HashTable<string,uint> freqs = addr2realname.lookup( addr.address );
			return_value += this.frequent_fullname( freqs );
		}

		return return_value;
	}

	public void run(string? name) {
		/* Open the database */
		this.db = new Notmuch.Database.open(this.user_db_path);
		var querystr = new StringBuilder ();
		if (name != null)
			querystr.append("to:"+name+"*");
		else
			/* set name to empty string if undefined */
			name = "";
		if (this.user_primary_email != null)
			querystr.append(" from:" + this.user_primary_email);
		
		var q = new Query.create(db, querystr.str);

		if (q.count_messages() == 0) {
			/* never sent this search a message, check all froms */
			querystr = new StringBuilder ();
			if (name != null)
				querystr.append("from:"+name+"*");
			q = new Query.create(db, querystr.str);
		}

		var msgs = q.search_messages();

		/* actually retrieve and sort the addresses */
		var result = this.addresses_by_frequency(msgs, name, true);
		foreach (string name in result) {
			stdout.printf("%s\n", name); 
		}
	}
} /*End of class AddressMatcher*/

public static int main(string[] args) {
	var app = new AddressMatcher();
	app.run(args[1]);
	return 0;
}
