module obfuscator.obfuscatable;

import obfuscator.namemap;
import obfuscator.globalsymbols;
import abcfile;
import tagutils;

class Obfuscatable {
	private NameMap excludes = new NameMap("EXC:");
	private NameMap partExcludes = new NameMap("PEX:");
	private GlobalSymbols globalSymbols;

	this(string excludesFile, string partExcludesFile, string[] globalFiles) {
		if (excludesFile)
			excludes.load(excludesFile);
		
		if (partExcludesFile)
			partExcludes.load(partExcludesFile);

		globalSymbols = new GlobalSymbols(globalFiles);
	}

	bool check(ABCFile abc, string name, uint n) {
		if (excludes.contains(name) || globalSymbols.contains(name) || isUrl(name))
			return false;

		//only include name if it is not excluded and not in globalSymbols & not be a url
		if (partExcludes.containsPart(name))
			return false;

		return abc.isNamespace(n) || abc.isMultiname(n);
	}

	bool isPartialExclude(string name) {
		return excludes.contains(name) || globalSymbols.contains(name);
	}
}
