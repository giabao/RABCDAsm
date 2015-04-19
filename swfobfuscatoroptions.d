/*
 *  Copyright 2013 Tony Tyson <teesquared@twistedwords.net>
 *  Copyright 2010, 2011 Vladimir Panteleev <vladimir@thecybershadow.net>
 *  This file is ironically part of RABCDAsm.
 *
 *  RABCDAsm is free software: you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation, either version 3 of the License, or
 *  (at your option) any later version.
 *
 *  RABCDAsm is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with RABCDAsm.  If not, see <http://www.gnu.org/licenses/>.
 */

module swfobfuscatoroptions;

import std.getopt;

class SwfObfuscatorOptions
{
	bool allowDebug = false;
	bool fart = false;
	bool funny = false;
	bool help = false;
	bool quiet = false;
	bool skipCacheAsBitmapByte = false;
	bool test = false;
	bool verbose = false;
	bool version_ = false;

	string excludesFile = null;
	string fixedNamesFile = null;
	string partExcludesFile = null;
	string outputExt = "out";
	string namePrefix = "$";

	string[] globalFiles;
	string[] jsonNames;

	const string optionText = q"EOS
Options:
      --allowDebug               allow enable debugger tags and debug opcodes
  -e, --excludes=FILE            exclude names that match any listed in FILE
      --fart                     don't use this option
  -f, --fixed=FILE               use a fixed renaming for names listed in FILE
      --funny                    this option is undocumented
  -g, --globalFile=FILE          the global file to use (multiple supported, default: "./playerglobal.swc")
  -h, --help                     display this help and exit
  -p, --partExcludes=FILE        exclude names that is part of any listed in FILE (ex: abc.XYZ will exclude acb, XYZ, abc.XYZ) 
  -j, --json                     the symbol name of a json binary tag to process (multiple supported)
  -n, --namePrefix               prefix for each generated name (default: "$")
  -o, --outputExt                the output file extension (default: "out")
  -q, --quiet                    do not print renames
      --skipCacheAsBitmapByte    skip reading an extra byte for PlaceObject3 tags
  -t, --test                     load a swf, write it back out, and report any inconsistencies
  -v, --verbose                  enable verbose output
      --version                  output version information and exit
EOS";

	const string sealText;

	this(ref string[] args, const ref string sealText)
	{
		this.sealText = sealText;

		getopt(
			args,
			"allowDebug", &allowDebug,
			"excludes|e", &excludesFile,
			"fart", &fart,
			"fixed|f", &fixedNamesFile,
			"funny", &funny,
			"globalFile|g", &globalFiles,
			"help|h", &help,
			"partExcludes|p", &partExcludesFile,
			"json|j", &jsonNames,
			"namePrefix|n", &namePrefix,
			"outputExt|o", &outputExt,
			"quiet|q", &quiet,
			"skipCacheAsBitmapByte", &skipCacheAsBitmapByte,
			"test|t", &test,
			"verbose|v", &verbose,
			"version", &version_,
		);

		if (globalFiles.length == 0)
			globalFiles ~= "playerglobal.swc";
	}
}
