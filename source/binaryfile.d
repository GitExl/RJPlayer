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

module util.binaryfile;

import std.stdio;
import std.bitmanip;


public final class BinaryFile {
    private ubyte[] _data;
    private uint _offset;


    public this(string fileName) {
        auto f = File(fileName, "rb");
        _data.length = cast(uint)f.size();
        f.rawRead(_data);
        f.close();
    }

    public byte readByte() {
        byte value = cast(byte)_data[_offset];
        _offset += 1;
        return value;
    }

    public byte readUByte() {
        ubyte value = _data[_offset];
        _offset += 1;
        return value;
    }

    public uint readUInt() {
        ubyte[uint.sizeof] value = _data[_offset.._offset + uint.sizeof];
        _offset += uint.sizeof;
        return bigEndianToNative!uint(value);
    }

    public int readInt() {
        ubyte[int.sizeof] value = _data[_offset.._offset + int.sizeof];
        _offset += int.sizeof;
        return bigEndianToNative!int(value);
    }

    public uint readUShort() {
        ubyte[ushort.sizeof] value = _data[_offset.._offset + ushort.sizeof];
        _offset += ushort.sizeof;
        return bigEndianToNative!ushort(value);
    }

    public uint readShort() {
        ubyte[short.sizeof] value = _data[_offset.._offset + short.sizeof];
        _offset += short.sizeof;
        return bigEndianToNative!short(value);
    }

    public ubyte[] readUBytes(const uint amount) {
        ubyte[] value = _data[_offset.._offset + amount];
        _offset += amount;
        return value;
    }

    public byte[] readBytes(const uint amount) {
        byte[] value = cast(byte[])_data[_offset.._offset + amount];
        _offset += amount;
        return value;
    }

    public char[] readChars(const uint amount) {
        char[] value = cast(char[])_data[_offset.._offset + amount];
        _offset += amount;
        return value;
    }

    public void seek(uint offset) {
        _offset = offset;
    }

    public uint tell() {
        return _offset;
    }

    @property
    public uint length() {
        return _data.length;
    }
}
