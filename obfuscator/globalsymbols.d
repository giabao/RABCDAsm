module obfuscator.globalsymbols;

import std.zip;
import std.file;
import std.experimental.logger;
import swffile;
import abcfile;
import tagutils;
import symfile;
import std.digest.md;

//This class parse a list of swc files and mark all ABCFile.strings from all abc tag from the swc files
//Then expose a function `bool contains(string name)` to check if `name` is in the marked strings.
class GlobalSymbols {
	private uint[string] symbols;
	
	bool contains(string name) {
		return false || name in symbols;
	}
	
	this(string[] globalFiles) {
		foreach (g; globalFiles)
			init(g);
		
		symbols.rehash();
		
		if (isLoggingActiveAt!(LogLevel.trace))
			foreach (key, val; symbols)
				tracef("GSY: %s = %d", key, val);
	}
	
	private void init(string globalFile) {
		if (!exists(globalFile)) {
			const string msg = "The global file does not exist! " ~ globalFile;
			throw new Exception(msg);
		}
		
		ZipArchive zip = new ZipArchive(read(globalFile));
		
		scope swf = SWFFile.read(zip.expand(zip.directory["library.swf"]));
		
		foreach (uint count, ref tag; swf.tags) {
			tracef("GSY: %d %s %d %s %s", count, tagNames[tag.type], tag.length,
				tag.forceLongLength ? "true" : "false", toHexString(md5Of(tag.data)));
			
			ABCFile abc = readTag!(ABCFile)(tag);
			
			for (uint n = 1; abc && n < abc.strings.length; ++n)
				++symbols[abc.strings[n]];
			
			SymFile sym = readTag!(SymFile)(tag);
			
			if (isLoggingActiveAt!(LogLevel.trace) && sym) {
				trace("GSY: sym.symbols.length = %d", sym.symbols.length);
				foreach (symbol; sym.symbols)
					trace("GSY: idref = %d, name = %s", symbol.idref, symbol.name);
			}
		}
	}
}
