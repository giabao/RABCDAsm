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

module swfobfuscator;

import std.algorithm : find;
import std.conv;
import std.digest.md;
import std.exception;
import std.file;
import std.json;
import std.path;
import std.random;
import std.regex;
import std.stdio;
import std.string;
import std.zip;
import swffile;
import swfobfuscatoroptions;
import tagoptions;
import tagutils;

import abcfile;
import binfile;
import expfile;
import frmfile;
import impfile;
import pobfile;
import sprfile;
import symfile;
import std.experimental.logger;

import obfuscator.fixednamemap;
import obfuscator.renaming;
import obfuscator.obfuscatable;

class SwfObfuscator {
  SwfObfuscatorOptions opt;

  FixedNameMap fixedNames = new FixedNameMap();
	Renaming renaming;
	@property string[string] fullRenames()  { return renaming.fullRenames; };
	@property string[string] partialRenames() { return renaming.partialRenames; };

	uint[] jsonIds;

	this(ref SwfObfuscatorOptions o) {
		opt = o;

		if (! o.verbose) globalLogLevel = LogLevel.info;

		auto obfuscatable = new Obfuscatable(o.excludesFile, o.partExcludesFile, o.globalFiles);
		renaming = new Renaming(o.namePrefix, obfuscatable);

		if (o.fixedNamesFile)
      fixedNames.load(o.fixedNamesFile);
	}

	void processAbcTag(ref SWFFile.Tag tag) {
		ABCFile abc = readTag!(ABCFile)(tag);
		if (! abc) return;

		trace("ABC: Processing abc ...");

		if (abc.hasDebugOpcodes && !opt.allowDebug) {
			const string msg = "Debug opcodes found! (to force obfuscation use the allowDebug command line option)";
			throw new Exception(msg);
		}

		for (uint n = 1; n < abc.strings.length; ++n) {
			string name = abc.strings[n];

			if (name in fullRenames) {
				string rename = fullRenames[name];
				infof("ABC: %s => %s", name, rename);
				abc.strings[n] = rename;
			}
		}

		replaceTagData(tag, abc.write(), false);
	}

	void processSymTag(ref SWFFile.Tag tag) {
		SymFile sym = readTag!(SymFile)(tag);
		if (! sym) return;

		trace("SYM: Processing sym ...");
		tracef("SYM: sym.symbols.length = %d", sym.symbols.length);

		foreach (ref symbol; sym.symbols) {
			tracef("SYM: idref = %d, name = %s", symbol.idref, symbol.name);

			if (symbol.name in fullRenames) {
				string rename = fullRenames[symbol.name];
				infof("SYM: %s => %s", symbol.name, rename);
				symbol.name = rename;
			}
		}

		replaceTagData(tag, sym.write(), false);
	}

	void processFrmTag(ref SWFFile.Tag tag) {
		FrmFile frm = readTag!(FrmFile)(tag);
		if (! frm) return;

		tracef("FRM: frameLabel %s", frm.frameLabel);
		tracef("FRM: hasAnchor %s", frm.hasAnchor);

		if (frm.frameLabel in fullRenames) {
			string rename = fullRenames[frm.frameLabel];
			infof("FRM: %s => %s", frm.frameLabel, rename);
			frm.frameLabel = rename;
		}

		replaceTagData(tag, frm.write(), false);
	}

	void processSprTag(ref SWFFile.Tag tag, ubyte swfver) {
		SprFile spr = readTag!(SprFile)(tag);
		if (! spr) return;

		tracef("SPR: spriteId %s", spr.spriteId);
		tracef("SPR: frameCount %s", spr.frameCount);

		foreach (count, ref sprtag; spr.tags) {
			tracef("SPR: %d %s %d %s %s", count, tagNames[sprtag.type], sprtag.length,
				sprtag.forceLongLength ? "true" : "false", getHexString(sprtag.data));

			processTag(sprtag, swfver);
		}

		replaceTagData(tag, spr.write(), false);
	}

	void processPobTag(ref SWFFile.Tag tag, ubyte ver) {
		TagOptions tagOptions = new TagOptions(ver, opt.skipCacheAsBitmapByte);
		PobFile pob = readTagOptions!(PobFile)(tag, tagOptions);
		if (! pob) return;

		trace("POB: " ~ pob.toString());

		if (pob.hasName && pob.name in fullRenames) {
			string rename = fullRenames[pob.name];
			infof("POB: %s => %s", pob.name, rename);
			pob.name = rename;
		}

		if (pob.hasClassName && pob.className in fullRenames) {
			string rename = fullRenames[pob.className];
			infof("POB: %s => %s", pob.className, rename);
			pob.className = rename;
		}

		replaceTagData(tag, pob.write(), false);
	}

	void processImpTag(ref SWFFile.Tag tag) {
		ImpFile imp = readTag!(ImpFile)(tag);
		if (! imp) return;

		foreach(ref a; imp.assets)
			if (a.name in fullRenames) {
				string rename = fullRenames[a.name];
				infof("IMP: %s => %s", a.name, rename);
				a.name = rename;
			}

		replaceTagData(tag, imp.write(), false);
	}

	void processExpTag(ref SWFFile.Tag tag) {
		ExpFile exp = readTag!(ExpFile)(tag);
		if (! exp) return;

		foreach(ref a; exp.assets)
			if (a.name in fullRenames) {
				string rename = fullRenames[a.name];
				infof("EXP: %s => %s", a.name, rename);
				a.name = rename;
			}

		replaceTagData(tag, exp.write(), false);
	}

	void processBinTag(ref SWFFile.Tag tag) {
		uint[string] jsonRenames;

		void renameKeys(ref JSONValue root) {
			void renameKeysObject(ref JSONValue root) {
				if (root.type != JSON_TYPE.OBJECT)
					return;

				bool[string] result;

				foreach (k, ref v; root.object) {
					if (k in fullRenames)
						result[k] = true;
					renameKeys(v);
				}

				foreach (ref k; result.keys) {
					++jsonRenames[k];
					root.object[fullRenames[k]] = root[k];
					root.object.remove(k);
				}
			}

			void renameKeysArray(ref JSONValue root) {
				if (root.type != JSON_TYPE.ARRAY)
					return;

				foreach (r; root.array)
					renameKeys(r);
			}

			renameKeysObject(root);
			renameKeysArray(root);
		}

		BinFile bin = readTag!(BinFile)(tag);

		if (bin && find(jsonIds, bin.characterId) != []) {
			JSONValue j = parseJSON(bin.binaryData);

			renameKeys(j);

			bin.binaryData = cast(ubyte[])toJSON(&j);

			tracef("BIN: %d %s %s", bin.characterId, opt.jsonNames, jsonIds);

			if (isLoggingActiveAt!(LogLevel.info))
				foreach (ref r; jsonRenames.keys)
					infof("BIN: %s => %s", r, fullRenames[r]);

			replaceTagData(tag, bin.write(), false);
		}
	}

	void checkEnableDebuggerTags(ref SWFFile.Tag tag) {
		if (!opt.allowDebug && (tag.type == TagType.EnableDebugger || tag.type == TagType.EnableDebugger2)) {
			const string msg = "EnableDebugger tag found! (to force obfuscation use the allowDebug command line option)";
			throw new Exception(msg);
		}
	}

	void processTag(ref SWFFile.Tag tag, ubyte swfver) {
		checkEnableDebuggerTags(tag);

		processAbcTag(tag);
		processBinTag(tag);
		processExpTag(tag);
		processFrmTag(tag);
		processImpTag(tag);
		processPobTag(tag, swfver);
		processSprTag(tag, swfver);
		processSymTag(tag);
	}

	void processSwf(string swfName) {
		SWFFile swf = SWFFile.read(cast(ubyte[])read(swfName));

		foreach (uint count, ref tag; swf.tags) {
			tracef("SWF: %d %s %d %s %s", count, tagNames[tag.type], tag.length,
				tag.forceLongLength ? "true" : "false", toHexString(md5Of(tag.data)));

			renaming.generateFullRenames(tag);
		}

		fullRenames.rehash();
    fixedNames.fix(renaming.fullRenames);

		foreach (uint count, ref tag; swf.tags) {
			tracef("SWF: %d %s %d %s %s", count, tagNames[tag.type], tag.length,
				tag.forceLongLength ? "true" : "false", toHexString(md5Of(tag.data)));

			processTag(tag, swf.header.ver);
		}

		jsonIds.destroy();

		std.file.write(swfName ~ "." ~ opt.outputExt, swf.write());
	}

	void reportWarnings() {
    fixedNames.reportWarnings(fullRenames);
	}
}
