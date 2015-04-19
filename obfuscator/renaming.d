module obfuscator.renaming;

import std.experimental.logger;
import std.regex;
import std.exception;
import std.string;

import abcfile;
import swffile;
import tagutils;
import obfuscator.obfuscatable;

class Renaming {
	string[string] fullRenames;
	string[string] partialRenames;
	private uint tagNumber = 0;
	private string namePrefix;
	private Obfuscatable obfuscatable;
	
	this(string namePrefix, Obfuscatable obfuscatable) {
		this.namePrefix = namePrefix;
		this.obfuscatable = obfuscatable;
	}
	
	private string renameFull(string s, uint n) {
		string rename = s in partialRenames ? partialRenames[s] : reformatName(n, 0);
		
		fullRenames[s] = rename;
		
		return rename;
	}
	
	private string renameByParts(string s, uint n) {
		string r;
		uint i = 0;
		
		auto m = match(s, regex(`([^.:]+)([.:]?)`, "g"));
		
		while (!m.empty) {
			string name = m.captures[1];
			string rename;
			
			if (name in fullRenames) {
				rename = fullRenames[name];
			} else if (name in partialRenames) {
				rename = partialRenames[name];
			} else if (obfuscatable.isPartialExclude(name)) { //check excludes for partials
				r = s;
				break;
			} else {
				rename = reformatName(n, i++);
				partialRenames[name] = rename;
			}
			
			r ~= rename ~ m.captures[2];
			m.popFront();
		}
		
		enforce(s.length > 0 && r.length > 0, "Invalid rename!");
		
		fullRenames[s] = r;
		fullRenames[tr(s, [':'], ['.'])] = tr(r, [':'], ['.']);
		
		return r;
	}
	
	//static const char[] DIGITS = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz_$0123456789";
	//static ubyte[] toDigits(uint n, ubyte b) {
	//  ubyte[] digits = [];
	//  while (n > 0) {
	//    digits ~= n % b;
	//    n /= b;
	//  }
	//  return digits;
	//}
	//static string toBasedName(uint n) {
	//  auto digits = toDigits(n, DIGITS.length);
	//  char[] s = [];
	//  foreach_reverse(ubyte d; digits) {
	//    s ~= DIGITS[d];
	//  }
	//  return s.dup;
	//}
	//static string[string] formatedNames = [];
	
	private string reformatName(uint n, uint p) {
		return format("%s%dt%ds%d", namePrefix, tagNumber, n, p);
		//return opt.namePrefix ~ toBasedName(tagNumber) ~ "t" ~ toBasedName(n) ~ "s" ~ toBasedName(p);
	}
	
	private string renameString(string s, uint n) {
		if (s in fullRenames)
			return fullRenames[s];
		
		if (match(s, regex(`[.:]`)))
			return renameByParts(s, n);
		
		return renameFull(s, n);
	}
	
	void generateFullRenames(ref SWFFile.Tag tag) {
		ABCFile abc = readTag!(ABCFile)(tag);
		
		if (abc) {
			++tagNumber;
			
			trace("REN: Generating full renames ...");
			
			for (uint n = 1; n < abc.strings.length; ++n) {
				string name = abc.strings[n];
				
				if (obfuscatable.check(abc, name, n)) {
					string rename = renameString(name, n);
					
					trace("REN: " ~ name ~ " => " ~ rename);
				}
			}
		}
		
		//		SymFile sym = readTag!(SymFile)(tag); //TODO uncomment
		//		
		//		if (sym) {
		//			foreach (ref symbol; sym.symbols)
		//				if (find(opt.jsonNames, symbol.name) != []) {
		//					jsonIds ~= symbol.idref;
		//					tracef("REN: json symbol %d %s %s", symbol.idref, symbol.name, jsonIds);
		//				}
		//		}
	}
}
