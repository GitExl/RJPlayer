/*
    Copyright (c) 2015, Dennis Meuwissen
    All rights reserved.

    Redistribution and use in source and binary forms, with or without
    modification, are permitted provided that the following conditions are met:

    1. Redistributions of source code must retain the above copyright notice, this
       list of conditions and the following disclaimer.
    2. Redistributions in binary form must reproduce the above copyright notice,
       this list of conditions and the following disclaimer in the documentation
       and/or other materials provided with the distribution.

    THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
    ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
    WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
    DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR
    ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
    (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
    LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
    ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
    (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
    SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/

module util.riffwriter;

import std.stdio;
import std.bitmanip;


public final class RIFFWriter {
    private File _fp;
    private uint _dataSize;
    private ulong _partialStart;


    public this(string fileName) {
        _fp = File(fileName, "wb");
        _fp.write("RIFF");
        _fp.write("\0\0\0\0");
    }

    public File writeChunk(char[4] name) {
        _fp.write(name);
        _fp.write("\0\0\0\0");
        _partialStart = _fp.tell();

        return _fp;
    }

    public void finishChunk() {
        uint partialSize = cast(uint)(_fp.tell() - _partialStart);
        uint padSize;
        if (partialSize % 4 != 0) {
            padSize = 4 - (partialSize % 4);
        }

        // Write chunk padding.
        _fp.write(new ubyte[padSize]);
        partialSize += padSize;

        // Write chunk length.
        _fp.seek(_partialStart - 4);
        ubyte[] size = [0, 0, 0, 0];
        size.write!(uint, Endian.littleEndian)(partialSize, 0);
        _fp.rawWrite(size);

        // Seek to end of chunk data.
        _fp.seek(_partialStart + partialSize);

        _dataSize += partialSize + 8;
    }

    public void writeList(char[4] name) {
        _fp.write(name);
    }

    public void finish() {
        _dataSize += 8;
        _fp.seek(4);

        ubyte[] size = [0, 0, 0, 0];
        size.write!(uint, Endian.littleEndian)(_dataSize, 0);
        _fp.rawWrite(size);

        _fp.close();
    }
}
