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
