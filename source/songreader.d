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

module song.songreader;

import std.stdio;
import std.string;

import song.song;

import util.binaryfile;


public final class SongReader {
    private string _songFileName;
    private string _sampleFileName;


    public this(const string songFileName, const string sampleFileName) {
        _songFileName = songFileName;
        _sampleFileName = sampleFileName;
    }

    public Song read() {
        BinaryFile songFile = new BinaryFile(_songFileName);
        BinaryFile sampleFile = new BinaryFile(_sampleFileName);

        writefln("Reading %s and %s...", _songFileName, _sampleFileName);

        // Read and validate song file header.
        Header header;
        header.id = songFile.readChars(3);
        if (header.id != "RJP") {
            throw new Exception("Song file is not a valid Richard Joseph song file.");
        }

        header.index = songFile.readByte();
        header.type = songFile.readChars(4);
        if (header.type != "SMOD") {
            throw new Exception("Song file is not a valid Richard Joseph song file.");
        }

        // Sample file header.
        header.samplesId = sampleFile.readChars(3);
        header.samplesIndex = sampleFile.readByte();
        if (header.samplesId != "RJP") {

            // Try again 8 bytes in. Chaos Engine menu sample data starts with 8 junk bytes,
            // and sample data offsets take this into account.
            sampleFile.seek(8);
            header.samplesId = sampleFile.readChars(3);
            header.samplesIndex = sampleFile.readByte();
            if (header.samplesId != "RJP") {
                throw new Exception("Sample file is not a valid Richard Joseph sample file.");
            }
        }

        Song song = new Song();
        song.setHeader(header);
        song.setInstruments(readInstruments(songFile, sampleFile));
        song.setVolumeSlides(readVolumeSlides(songFile));
        song.setSubSongs(readSubSongs(songFile));
        uint[] sequenceOffsets = readSequenceOffsets(songFile);
        song.setSequenceOffsets(sequenceOffsets);
        uint[] patternOffsets = readPatternOffsets(songFile);
        song.setPatternOffsets(patternOffsets);
        song.setSequences(readSequences(songFile, sequenceOffsets, patternOffsets));
        song.setPatterns(readPatterns(songFile, patternOffsets));

        writefln("Song has %d subsongs.", song.getSubSongs().length);

        return song;
    }

    private Instrument[] readInstruments(BinaryFile songFile, BinaryFile sampleFile) {
        Instrument[] instruments = new Instrument[songFile.readUInt() / 32];

        foreach (int index, ref Instrument ins; instruments) {
            immutable uint offsetSampleData = songFile.readUInt();
            immutable uint offsetVibratoData = songFile.readUInt();
            immutable uint offsetTremoloData = songFile.readUInt();

            ins.volumeSlideIndex = cast(ushort)(songFile.readUShort() / 6);

            ins.volume = songFile.readUShort() / 64.0;
            ins.initialOffset = songFile.readUShort() * 2;
            ins.initialLength = songFile.readUShort() * 2;

            ins.sampleLoopStart = songFile.readUShort() * 2;
            ins.sampleLoopLength = songFile.readUShort() * 2;

            ins.vibratoLoopStart = songFile.readUShort() * 2;
            ins.vibratoLength = songFile.readUShort() * 2;

            ins.tremoloLoopStart = songFile.readUShort() * 2;
            ins.tremoloLength = songFile.readUShort() * 2;

            // Read data from sample file.
            if (offsetSampleData + 4 >= sampleFile.length) {
                writefln("Instrument %d sample starts beyond sample data range. Sample data not read.", index);
                ins.sampleData.length = ins.initialLength + ins.initialOffset;
            } else if (offsetSampleData + 4 + ins.initialLength + ins.initialOffset > sampleFile.length) {
                writefln("Instrument %d sample continues beyond sample data range. Sample data not read.", index);
                ins.sampleData.length = ins.initialLength + ins.initialOffset;
            } else {
                sampleFile.seek(offsetSampleData + 4);
                ins.sampleData = byteAudioToFloat(sampleFile.readBytes(ins.initialLength + ins.initialOffset));
            }

            if (offsetVibratoData + 4 > sampleFile.length) {
                writefln("Instrument %d vibrato starts beyond sample data range. Vibrato data not read.", index);
                ins.vibratoData.length = ins.vibratoLength;
            } else {
                sampleFile.seek(offsetVibratoData + 4);
                ins.vibratoData = byteVibratoToFloat(sampleFile.readBytes(ins.vibratoLength));
            }

            if (offsetTremoloData + 4 > sampleFile.length) {
                writefln("Instrument %d tremolo starts beyond sample data range. Tremolo data not read.", index);
                ins.tremoloData.length = ins.tremoloLength;
            } else {
                sampleFile.seek(offsetTremoloData + 4);
                ins.tremoloData = byteTremoloToFloat(sampleFile.readBytes(ins.tremoloLength));
            }
        }

        return instruments;
    }

    private VolumeSlide[] readVolumeSlides(BinaryFile songFile) {
        VolumeSlide[] volumeSlides = new VolumeSlide[songFile.readUInt() / 6];

        foreach (ref VolumeSlide slide; volumeSlides) {
            slide.initialVolume = songFile.readUByte() / 64.0;
            slide.intermediateVolume = songFile.readUByte() / 64.0;
            slide.toIntermediateDuration = songFile.readUByte();
            slide.finalVolume = songFile.readUByte() / 64.0;
            slide.toFinalDuration = songFile.readUByte();
            slide.toZeroDuration = songFile.readUByte();
        }

        return volumeSlides;
    }

    private SubSong[] readSubSongs(BinaryFile songFile) {
        SubSong[] subSongs = new SubSong[songFile.readUInt() / 4];

        // Subsong sequence indices.
        foreach (ref SubSong subSong; subSongs) {
            subSong.sequences[0] = songFile.readUByte();
            subSong.sequences[1] = songFile.readUByte();
            subSong.sequences[2] = songFile.readUByte();
            subSong.sequences[3] = songFile.readUByte();
        }

        return subSongs;
    }

    private uint[] readPatternOffsets(BinaryFile songFile) {
        uint[] patternOffsets = new uint[songFile.readUInt() / 4];

        foreach (ref uint offset; patternOffsets) {
            offset = songFile.readUInt();
        }

        return patternOffsets;
    }

    private uint[] readSequenceOffsets(BinaryFile songFile) {
        uint[] sequenceOffsets = new uint[songFile.readUInt() / 4];

        foreach (ref uint offset; sequenceOffsets) {
            offset = songFile.readUInt();
        }

        return sequenceOffsets;
    }

    private Sequence[uint] readSequences(BinaryFile songFile, uint[] sequenceOffsets, uint[] patternOffsets) {
        Sequence[uint] sequences;

        immutable uint size = songFile.readUInt();
        immutable uint start = songFile.tell();

        foreach (uint offset; sequenceOffsets) {
            songFile.seek(start + offset);

            // Each sequence contains a list of patterns.
            Sequence sequence;
            while (1) {
                immutable ubyte pattern = songFile.readUByte();
                if (pattern == 0) {
                    break;
                }
                sequence.patternIndices ~= pattern;
            }

            // Read what to do after the sequence's last pattern has played.
            immutable ubyte postAction = songFile.readUByte();
            if (postAction == 1) {
                throw new Exception("Invalid sequence post action byte.");
            } else if (postAction >= 2 && postAction <= 127) {
                sequence.loopBack = cast(ubyte)(postAction - 1);
            } else if (postAction >= 128 && postAction <= 255) {
                sequence.nextSequence = songFile.readUByte() * 4;
            }

            sequences[offset] = sequence;
        }
        songFile.seek(start + size);

        return sequences;
    }

    private Pattern[uint] readPatterns(BinaryFile songFile, uint[] patternOffsets) {
        Pattern[uint] patterns;

        immutable uint size = songFile.readUInt();
        immutable uint start = songFile.tell();

        foreach (uint offset; patternOffsets) {
            if (start + offset >= songFile.length) {
                continue;
            }

            // Read pattern commands.
            songFile.seek(start + offset);
            Pattern pattern;
            while (1) {
                Command cmd;
                immutable ubyte type = songFile.readUByte();

                // Read note commands.
                if (type < 0x80) {
                    cmd.type = CommandType.NOTE;
                    cmd.parameter1 = type / 2;

                // Read other command types.
                } else {
                    if (type > 0x87) {
                        throw new Exception(format("Unknown pattern command 0x%X.", type));
                    }

                    // Read command parameters.
                    cmd.type = cast(CommandType)type;
                    if (cmd.type == CommandType.SET_SPEED || cmd.type == CommandType.SET_DELAY ||
                        cmd.type == CommandType.SET_INSTRUMENT || cmd.type == CommandType.SET_VOLUME ||
                        cmd.type == CommandType.PITCH_SLIDE) {
                        cmd.parameter1 = songFile.readUByte();
                    }

                    if (cmd.type == CommandType.SET_VOLUME) {
                        songFile.readUByte();
                    } else if (cmd.type == CommandType.PITCH_SLIDE) {
                        cmd.parameter2 = songFile.readInt() / 65536.0;
                    }
                }

                pattern.commands ~= cmd;

                if (cmd.type == CommandType.PATTERN_END) {
                    break;
                }
            }

            patterns[offset] = pattern;
        }

        return patterns;
    }

    private float[] byteAudioToFloat(byte[] data) {
        float[] output = new float[data.length];

        for (int index; index < data.length; index++) {
            output[index] = cast(float)data[index] * (1.0 / 128.0);
        }

        return output;
    }

    private float[] byteTremoloToFloat(byte[] data) {
        float[] output = new float[data.length];

        for (int index; index < data.length; index++) {
            output[index] = data[index] / 128.0;
        }

        return output;
    }

    private float[] byteVibratoToFloat(byte[] data) {
        float[] output = new float[data.length];

        for (int index; index < data.length; index++) {
            output[index] = (data[index] < 0) ? data[index] / 128.0 : data[index] / 256.0;
        }

        return output;
    }
}
