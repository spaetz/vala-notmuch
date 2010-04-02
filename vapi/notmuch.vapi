/* notmuch.vapi
 *
 * Copyright (C) 2010 Sebastian Spaeth
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2.1 of the License, or (at your option) any later version.

 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.

 * You should have received a copy of the GNU Lesser General Public
 * License along with this library; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301  USA
 *
 * Author:
 * 	Sebastian Spaeth <Sebastian@SSpaeth.de>
 */
[CCode (lower_case_cprefix = "notmuch_", cheader_filename = "notmuch.h")]
namespace Notmuch {	
	[CCode (cname = "int", cprefix = "NOTMUCH_STATUS_")]
	public enum Status {
		SUCCESS,
		OUT_OF_MEMORY,
		READ_ONLY_DATABASE,
		XAPIAN_EXCEPTION,
		FILE_ERROR,
		FILE_NOT_EMAIL,
		DUPLICATE_MESSAGE_ID,
		NULL_POINTER,
		TAG_TOO_LONG,
		UNBALANCED_FREEZE_THAW,
		LAST_STATUS
	}
 
    //unowned string status_to_string (Status);

	[Compact]
	[CCode (cprefix = "notmuch_database_", cname = "notmuch_database_t",free_function = "notmuch_database_close")]
	public class Database {

		[CCode (cname = "int", cprefix = "NOTMUCH_DATABASE_MODE_")]
		public enum Mode {
			READ_ONLY,
			READ_WRITE
		}

		[CCode (cname = "notmuch_database_create", 
				has_construct_function = false)]
		public Database.create (string path);
		[CCode (cname = "notmuch_database_open", 
				has_construct_function = false)]
		public Database.open (string path, Mode mode);
		public void close ();
		public unowned string get_path ();
        /* Return the database format version of the given database. */
		public uint get_version ();
		public bool needs_upgrade ();
		/*public Status upgrade (notmuch_database_t *database,
			  void (*progress_notify) (void *closure,
						   double progress),
						   void *closure);*/
		//public Directory get_directory (string path);
		//public Status add_message (string filename, out Message message);
		//public Status remove_message (string filename);
		/*Returns 'null' if none found*/
		public Message? find_message (string message_id);
		public Tags? get_all_tags ();

	}

	[Compact]
	[CCode (cprefix = "notmuch_query_", cname = "notmuch_query_t",free_function = "notmuch_query_destroy")]
	public class Query {
		[CCode (cname = "notmuch_query_create", 
				has_construct_function = false)]
		public Query.create (Database db, string querystr);

        /* Sort values for notmuch_query_set_sort */
		[CCode (cname = "int", cprefix = "NOTMUCH_SORT_")]
		public enum Sort {
			OLDEST_FIRST,
			NEWEST_FIRST,
			MESSAGE_ID
		}

        /* Specify the sorting desired for this query. */
		public void set_sort (Sort sort);
		//notmuch_threads_t * notmuch_query_search_threads (notmuch_query_t *query);
		public Messages search_messages ();
		public uint count_messages ();

		public void destroy ();
	}

	[Compact]
	[CCode (cprefix = "notmuch_messages_", cname = "notmuch_messages_t",free_function = "notmuch_messages_destroy")]
	public class Messages {
		public bool valid ();
		public Message get ();
		public void move_to_next ();

		public void destroy ();
	} /*End of Messages*/


	[Compact]
	[CCode (cprefix = "notmuch_message_", cname = "notmuch_message_t",free_function = "notmuch_message_destroy")]
	public class Message {
		public unowned string get_message_id ();
		public unowned string get_thread_id ();
//notmuch_messages_t * notmuch_message_get_replies (notmuch_message_t *message);
		public unowned string get_filename ();

        /* Message flags */
		[CCode (cname = "int", cprefix = "NOTMUCH_MESSAGE_FLAG_")]
		public enum Flag {
			MATCH
		}

		public bool get_flag (Flag flag);
		public void set_flag (Flag flag, bool value);
		//public time_t notmuch_message_get_date  (notmuch_message_t *message);
		public unowned string? get_header (string header);
		public Tags get_tags ();
		public Status add_tag (string tag);
		public Status remove_tag (string tag);
		public Status remove_all_tags ();
		public Status freeze ();
		public Status thaw ();

		public void destroy();
	}

	[Compact]
	[CCode (cprefix = "notmuch_tags_", cname = "notmuch_tags_t",free_function = "notmuch_tags_destroy")]
	public class Tags {
		public bool valid ();
		public unowned string get ();
		public void move_to_next ();

		public void destroy ();

	}

}
