module obfuscator.fixednamemap;

import std.experimental.logger;
import std.stdio;
import std.file;
import std.conv;
import std.string;

//TODO add comment
class FixedNameMap {
	private string[string] names;
	
	void load(string file) {
		if (!exists(file))
			throw new Exception("Fixed names file does not exist! " ~ file);
		
		uint num = 0;
		
		foreach (line; File(file).byLine()) {
			const string s = strip(to!string(line));
			
			if (s[0] == '#')
				continue;
			
			++num;
			
			if (s[0] == '!')
				continue;
			
			const string f = format("%df%d", num, s.length);
			
			if (s in names)
				throw new Exception("Duplicate fixed name found! " ~ s);
			
			names[s] = f;
			
			trace("FIX: " ~ s ~ " " ~ f);
		}
		
		names.rehash();
	}
	
	void fix(ref string[string] fullRenames) {
		foreach(ref f; names.keys)
		if (f in fullRenames) {
			tracef("SWF: Fixed name [%s] renamed to [%s] instead of [%s]", f, names[f], fullRenames[f]);
			fullRenames[f] = names[f];
		}
	}
	
	void reportWarnings(string[string] fullRenames) {
		foreach(ref f; names.keys)
			if (f !in fullRenames)
				warning("Warning: Fixed name [" ~ f ~ "] skipped because it doesn't qualify for obfuscation.");
	}
}

