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

module song.song;

import std.stdio;
import std.string;


package enum CommandType : ubyte {
    NOTE = 0x1,
    PATTERN_END = 0x80,
    EVENT_END_FADE = 0x81,
    SET_SPEED = 0x82,
    SET_DELAY = 0x83,
    SET_INSTRUMENT = 0x84,
    SET_VOLUME = 0x85,
    PITCH_SLIDE = 0x86,
    EVENT_END = 0x87,
}

package struct Pattern {
    Command[] commands;
}

package struct Command {
    CommandType type;
    ubyte parameter1;
    float parameter2;
}

package struct Sequence {
    uint[] patternIndices;
    ubyte loopBack;
    uint nextSequence;
}

package struct SubSong {
    uint[4] sequences;
}

package struct VolumeSlide {
    float initialVolume;
    float intermediateVolume;
    float finalVolume;

    ubyte toIntermediateDuration;
    ubyte toFinalDuration;
    ubyte toZeroDuration;
}

package struct Instrument {
    float volume;
    uint initialOffset;
    uint initialLength;
    ushort volumeSlideIndex;

    float[] sampleData;
    uint sampleLoopStart;
    uint sampleLoopLength;

    float[] vibratoData;
    uint vibratoLoopStart;
    uint vibratoLength;

    float[] tremoloData;
    uint tremoloLoopStart;
    uint tremoloLength;
}

package struct Header {
    char[3] id;
    ubyte index;
    char[4] type;

    char[3] samplesId;
    ubyte samplesIndex;
}


public final class Song {
    private Header _header;
    private Instrument[] _instruments;
    private VolumeSlide[] _volumeSlides;
    private SubSong[] _subSongs;
    private Sequence[uint] _sequences;
    private Pattern[uint] _patterns;
    private uint[] _sequenceOffsets;
    private uint[] _patternOffsets;

    package void setHeader(Header header) {
        _header = header;
    }

    package Header getHeader() {
        return _header;
    }

    package void setInstruments(Instrument[] instruments) {
        _instruments = instruments;
    }

    package Instrument[] getInstruments() {
        return _instruments;
    }

    package void setVolumeSlides(VolumeSlide[] volumeSlides) {
        _volumeSlides = volumeSlides;
    }

    package VolumeSlide[] getVolumeSlides() {
        return _volumeSlides;
    }

    package void setSubSongs(SubSong[] subSongs) {
        _subSongs = subSongs;
    }

    package SubSong[] getSubSongs() {
        return _subSongs;
    }

    package void setSequences(Sequence[uint] sequences) {
        _sequences = sequences;
    }

    package Sequence[uint] getSequences() {
        return _sequences;
    }

    package void setPatterns(Pattern[uint] patterns) {
        _patterns = patterns;
    }

    package Pattern[uint] getPatterns() {
        return _patterns;
    }

    package uint getSequenceOffset(const uint index) {
        if (index >= _sequenceOffsets.length) {
			writefln("Sequence index %d is out of range. Returning 0.", index);
            return 0;
        }

        return _sequenceOffsets[index];
    }

    package uint sequenceOffsetToIndex(const uint offset) {
        foreach (uint index, uint sequenceOffset; _sequenceOffsets) {
            if (offset == sequenceOffset) {
                return index;
            }
        }

        throw new Exception(format("Cannot find sequence offset 0x%04X.", offset));
    }

    package uint getPatternOffset(const uint index) {
        if (index >= _patternOffsets.length) {
            writefln("Pattern index %d is out of range. Returning 0.", index);
            return 0;
        }

        return _patternOffsets[index];
    }

    package void setSequenceOffsets(uint[] sequenceOffsets) {
        _sequenceOffsets = sequenceOffsets;
    }

    package void setPatternOffsets(uint[] patternOffsets) {
        _patternOffsets = patternOffsets;
    }

    package Instrument getInstrument(const uint index) {
        if (index >= _instruments.length) {
            return _instruments[0];
        }

        return _instruments[index];
    }

    package Pattern getPattern(const uint offset) {
        return _patterns[offset];
    }

    package Sequence getSequence(const uint offset) {
        return _sequences[offset];
    }

    package float[] getInstrumentSampleData(const uint index) {
        return _instruments[index].sampleData;
    }

    package VolumeSlide getVolumeSlide(const uint index) {
        return _volumeSlides[index];
    }

    public bool hasSubSong(const uint subSong) {
        return (subSong < _subSongs.length);
    }
}
