/*
 *  Copyright 2010, 2011, 2012 Vladimir Panteleev <vladimir@thecybershadow.net>
 *  Portions Copyright 2013 Tony Tyson <teesquared@twistedwords.net>
 *  This file is part of RABCDAsm.
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

/// A simple tool to build RABCDAsm in one command.
/// You can use the DC and DCFLAGS environment variables to override the detected compiler and compilation flags.

module build_rabcdasm;

version(D_Version2)
	{ /* All OK */ }
else
	static assert(false, "Unsupported D version.\nThis software requires a D2 ( http://dlang.org/ ) compiler to build.");

version(D_Version2):

version(DigitalMars)
	const DEFAULT_COMPILER = "dmd";
else
	const DEFAULT_COMPILER = "gdmd";

const DEFAULT_FLAGS = "-O -inline -release";
const LZMA_FLAGS = "-version=HAVE_LZMA";

import std.exception;
import std.file;
import std.process;
import std.stdio;
import std.string;

string compiler, flags;

void compile(string program)
{
	stderr.writeln("* Building ", program);
	string command = format("rdmd --build-only --compiler=%s %s %s", compiler, flags, program);
	enforce(wait(spawnShell(command)) == 0, "Compilation of " ~ program ~ " failed");
}

void test(string code, string extraFlags=null)
{
	const FN = "test.d";
	std.file.write(FN, code);
	scope(exit) remove(FN);
	string command = format("rdmd --force --compiler=%s %s %s %s", compiler, flags, extraFlags, FN);
	enforce(wait(spawnShell(command)) == 0, "Test failed");
	stderr.writeln(" >>> OK");
}

int main()
{
	try
	{
		compiler = environment.get("DC", DEFAULT_COMPILER);

		flags = environment.get("DCFLAGS", DEFAULT_FLAGS);

		stderr.writeln("* Checking for working compiler...");
		test(`
			void main() {}
		`);

		bool haveLZMA;

		stderr.writeln("* Checking for LZMA...");
		try
		{
			test(`
				import lzma, std.exception;
				void main()
				{
					LZMAHeader header;
					auto data = cast(immutable(ubyte)[])"Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.";
					auto cdata = lzmaCompress(data, &header);
					header.decompressedSize = data.length;
					auto ddata = lzmaDecompress(header, cdata);
					enforce(data == ddata);
				}
			`, LZMA_FLAGS);

			// Test succeeded
			haveLZMA = true;
		}
		catch (Exception e)
			stderr.writeln(" >>> LZMA not found, building without LZMA support.");

		if (haveLZMA)
			flags ~= " " ~ LZMA_FLAGS;

		flags ~= " -J.";

		stderr.writeln("* Compliler flags are (" ~ flags ~ ")");

		foreach (program; ["rabcasm", "rabcdasm", "abcexport", "abcreplace", "swfbinexport", "swfbinreplace", "swfdecompress", "swf7zcompress", "flasturbate"])
			compile(program);

		if (haveLZMA)
			compile("swflzmacompress");

		return 0;
	}
	catch (Exception e)
	{
		stderr.writeln("Error: ", e.msg);
		return 1;
	}
}
