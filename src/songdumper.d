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

module song.songdumper;

import std.stdio;
import std.conv;
import std.algorithm;

import song.song;


public final class SongDumper {
    private Song _song;

    public this(Song song) {
        _song = song;
    }

    public void dumpInstruments() {
        writeln("Instruments");
        writeln("-----------");
        writeln("#    Size    Ilen   Ioffs  Vol       Loop   Loop len  Sld  Vib    Tre");
        foreach (uint index, ref Instrument ins; _song.getInstruments()) {
            writefln("%-3d  %-6d  %-5d  %-5d  %-8f  %-5d  %-8d  %-3d  %-5d  %d", index, ins.sampleData.length, ins.initialLength, ins.initialOffset, ins.volume, ins.sampleLoopStart, ins.sampleLoopLength, ins.volumeSlideIndex, ins.vibratoData.length, ins.tremoloData.length);
        }
        writeln("");
    }

    public void dumpVolumeSlides() {
        writeln("Volume slides");
        writeln("-------------");
        writeln("#   Vol 1     Dur 1-2  Vol 2     Dur 2-3  Vol 3     Dur 0");
        foreach (uint index, ref VolumeSlide slide; _song.getVolumeSlides()) {
            writefln("%-2d  %-8f  %-7d  %-8f  %-7d  %-8f  %-5d", index, slide.initialVolume, slide.toIntermediateDuration, slide.intermediateVolume, slide.toFinalDuration, slide.finalVolume, slide.toZeroDuration);
        }
        writeln("");
    }

    public void dumpSubSongs() {
        writeln("Subsongs");
        writeln("--------");
        writeln("#   Seq 1  Seq 2  Seq 3  Seq 4");
        foreach (uint index, ref SubSong subSong; _song.getSubSongs()) {
            writefln("%-2d  %5d  %5d  %5d  %5d", index, subSong.sequences[0], subSong.sequences[1], subSong.sequences[2], subSong.sequences[3]);
        }
        writeln("");
    }

    public void dumpSequences() {
        Sequence[uint] sequences = _song.getSequences();

        uint[] offsets = sequences.keys();
        offsets.sort();

        writeln("Sequences");
        writeln("---------");
        foreach (int index, uint offset; offsets) {
            Sequence sequence = sequences[offset];

            writefln("Sequence %d, 0x%04X", index, offset);
            write("Patterns     : ");
            foreach (uint pattern; sequence.patternIndices) {
                writef("%d ", pattern);
            }
            writeln("");

            writefln("Loopback     : %d", sequence.loopBack);
            writefln("Next sequence: 0x%04X", sequence.nextSequence);
            writeln("");
        }
    }

    public void dumpPatterns() {
        Pattern[uint] patterns = _song.getPatterns();
        uint[] offsets = patterns.keys();
        offsets.sort();

        foreach (int index, uint offset; offsets) {
            Pattern pattern = patterns[offset];

            writefln("Pattern %d, 0x%04X", index, offset);
            writeln("-------------------");
            foreach (ref Command cmd; pattern.commands) {
                writefln("%-14s  %-3d  %f", to!string(cmd.type), cmd.parameter1, cmd.parameter2);
            }
            writeln("");
        }
    }
}
