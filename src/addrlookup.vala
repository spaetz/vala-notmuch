using Notmuch;

class AddressMatcher {
	/* contains the Database */
	private Notmuch.Database db;
	/* Full path of the notmuch database */
	private string user_db_path = null;
	/* User's primary email */
	private string user_primary_email = null;
	/* User's tag to mark from addresses as in the address book */
	private string user_addrbook_tag = null;

	private struct MailAddress_freq {
		public string address;
		public uint[] occurances;
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
		try {
			this.user_addrbook_tag = config.get_string ("user", "addrbook_tag");
		} catch (Error ex) {this.user_addrbook_tag = "addressbook";}
	}

	/* Used to sort the email addresses from most to least used */
	private static int sort_by_freq(MailAddress_freq* mail1, 
									MailAddress_freq* mail2){
		if (mail1->occurances[0] == mail2->occurances[0] &&
			mail1->occurances[1] == mail2->occurances[1] &&
			mail1->occurances[2] == mail2->occurances[2]) return 0;

		if (mail1->occurances[0] > mail2->occurances[0] ||
			mail1->occurances[0] == mail2->occurances[0] &&
			mail1->occurances[1] > mail2->occurances[1] ||
			mail1->occurances[0] == mail2->occurances[0] &&
			mail1->occurances[1] == mail2->occurances[1] &&
			mail1->occurances[2] > mail2->occurances[2])
			return -1;
		return 1;
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
	 * pass 0-2 looking at 'from', 'to,cc,bcc', and 'from' headers respectively
	 * Returns: hashtable with mail address (hash) and number of occurances
	 */
	public HashTable<string,uint> addresses_by_frequency(Messages msgs,
								string name,
								uint pass,
								ref HashTable<string,HashTable> addr2realname) {

		/* hashtable with mail address (hash) and number of occurances */
		var ht = new HashTable<string,uint>.full(GLib.str_hash, str_equal, 
												 g_free, null);

		/* email-identifying regex based on 
		 *  http://regexlib.com/DisplayPatterns.aspx
		 */
		Regex re = null;
		try {
			re = new Regex("\\s*((\\\"(\\\\.|[^\\\\\"])*\\\"|[^,])*" +
						   "<?(?P<mail>\\b\\w+([-+.]\\w+)*\\@\\w+[-\\.\\w]*\\.([-\\.\\w]+)*\\w\\b)>?)");
		} catch (GLib.RegexError ex) { }

		/*Usually look at from header only, just in pass 1 look at to,cc,bcc*/
		string[] headers = {"from"};
		if (pass == 1)
			headers = {"to","cc","bcc"};

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
		return ht;
}

	public string[] search_address_passes(Query*[] queries,
										   string name
										   ) {
		string[] return_value = null;
		var addrfreq = new HashTable<string,MailAddress_freq?>.full(
			GLib.str_hash, str_equal, g_free, null);

        /* Hashtable pointing from lower case email addresses to a
		 * HashTable with "real name + email address" ->
		 * occurances. */
		//TODO: do we leak the value Hashtable?
		var addr2realname = new HashTable<string,HashTable>.full(
			GLib.str_hash, str_equal, g_free, null);

		uint pass = 0; /* 0-based*/
		foreach (var q in queries){
			var msgs = q->search_messages();
			/* returns hashtable with mail address (hash) 
			 * and number of occurances */
			var ht = addresses_by_frequency(msgs, name, pass, ref addr2realname);

			/* Populate and sort addresses by frequency (least-to-most) */
			foreach (var addr in ht.get_keys()) {
				MailAddress_freq? freq = addrfreq.lookup(addr);
				if (freq == null) {
					freq = MailAddress_freq() { address = addr,
							occurances = {0,0,0} };
				}
				freq.occurances[pass] = ht.lookup(addr);
				addrfreq.replace(addr,freq);
			}
			msgs.destroy();
			pass += 1;
		}

		/* SList with unique addresses (to be sorted after occurances)*/
		List<MailAddress_freq?> addrs = addrfreq.get_values();
		addrs.sort((GLib.CompareFunc)sort_by_freq);

		/* add most frequent real name for each mail address */
		foreach (var addr in addrs) {
			HashTable<string,uint> freqs = addr2realname.lookup( addr.address );
			return_value += this.frequent_fullname( freqs );
		}

		return return_value;
	}

	public void run(string? name) {
		Query*[3] queries = {};

		/* Open the database */
		this.db = new Notmuch.Database.open(this.user_db_path);

		/* Pass 1 looks at all from: addresses with the address book tag */
		var querystr = new StringBuilder ("tag:" + this.user_addrbook_tag);
		if (name != null)
			querystr.append(" and from:"+name+"*");
		else
			/* set name to empty string if undefined */
			name = "";		
		queries += new Query.create(db, querystr.str);

		/* Pass 2 looks at all to: addresses sent from our primary mail */
		querystr = new StringBuilder ();
		if (name != null)
			querystr.append("to:"+name+"*");
		if (this.user_primary_email != null)
			querystr.append(" from:" + this.user_primary_email);
		queries += new Query.create(db, querystr.str);

		/* If that leads only to a few hits, we check every from too */
		if (queries[0]->count_messages() + queries[1]->count_messages() < 10) {
			querystr = new StringBuilder ();
			if (name != null)
				querystr.append("from:"+name+"*");
			queries += new Query.create(db, querystr.str);
		}

		/* actually retrieve and sort the addresses */
		var result = this.search_address_passes(queries, name);
		foreach (string addr in result) {
			stdout.printf("%s\n", addr); 
		}
	}
} /*End of class AddressMatcher*/

public static int main(string[] args) {
	var app = new AddressMatcher();
	app.run(args[1]);
	return 0;
}
