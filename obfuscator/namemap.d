module obfuscator.namemap;

import std.stdio;
import std.file;
import std.experimental.logger;
import std.string;
import std.conv;

//This class parse a text file and store each line that not start with '#' char into a names list
//Then expose a function `bool contains(string name)` to check if `name` is in the stored names list.
class NameMap {
	private bool[string] names;
	private string logName;
	
	bool contains(string name) {
		return false || name in names;
	}
	
	this(string logName) {
		this.logName = logName;
	}

	//check if ".$name." is substring of one of names.keys.map(n => ".$n.")
	bool containsPart(string name) {
		if (name in names) return true;

		foreach (k, _; names) {
			if(("." ~ k ~ ".").indexOf("." ~ name ~ ".") != -1) return true;
		}

		return false;
	}
	
	void load(string file) {
		if (!exists(file))
			throw new Exception(logName ~ " file does not exist! " ~ file);
		
		foreach (line; File(file).byLine()) {
			const string s = strip(to!string(line));
			
			if (s[0] == '#')
				continue;
			
			if (s in names)
				warning(logName ~ " Duplicate found! " ~ s);
			
			names[s] = true;
			
			trace(logName ~ s);
		}
		
		names.rehash();
	}
}

