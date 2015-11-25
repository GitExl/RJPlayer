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
