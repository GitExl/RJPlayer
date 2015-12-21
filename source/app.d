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

import std.stdio;
import std.conv;
import std.getopt;
import std.file;
import std.c.stdlib;

import derelict.sdl2.sdl;

import audio.mixer;
import audio.outputwav;
import audio.outputsdl;

import song.song;
import song.songreader;
import song.songdumper;
import song.songplayer;

import text.help;
import text.license;


private immutable string NAME = "RJPlayer";

private immutable ubyte VERSION_MAJOR = 1;
private immutable ubyte VERSION_MINOR = 2;
private immutable ubyte VERSION_PATCH = 0;


struct Options {
    string inputSong = "";
    string inputSamples = "";
    ubyte subSong = 0;
    uint sampleRate = 44100;
    double stereoSeparation = 1.0 / 5;
    double volume = 1.0;
    bool linearInterpolation = false;
    string wav = "";
    double duration = float.nan;
    bool dump = false;
    bool silent = false;
    int sequence = -1;
}


int main(string[] argv) {
    writeHeader();

    if (argv.length == 1) {
        writeHelp();
    }

    Options options;
    getopt(
        argv,
        "license|l",           &writeLicense,
        "help|h|?",            &writeHelp,
        "song",                &options.inputSong,
        "samples",             &options.inputSamples,
        "subsong|s",           &options.subSong,
        "samplerate|r",        &options.sampleRate,
        "stereo-separation",   &options.stereoSeparation,
        "volume|v",            &options.volume,
        "lerp",                &options.linearInterpolation,
        "wav|w",               &options.wav,
        "duration|d",          &options.duration,
        "dump|d",              &options.dump,
        "silent",              &options.silent,
        "sequence|q",          &options.sequence
    );

    // Validate basic input.
    if (!exists(options.inputSong)) {
        writeln("A valid input song filename is required.");
        return -1;
    }

    if (!exists(options.inputSamples)) {
        writeln("A valid input sample data filename is required.");
        return -1;
    }

    // Attempt to read the song.
    SongReader songReader = new SongReader(options.inputSong, options.inputSamples);
    Song song = songReader.read();

    if (!song.hasSubSong(options.subSong)) {
        writefln("Subsong index %d does not exist.", options.subSong);
        return -1;
    }

    // Dump song data.
    if (options.dump) {
        SongDumper dumper = new SongDumper(song);

        writeln();
        dumper.dumpInstruments();
        dumper.dumpVolumeSlides();
        dumper.dumpSubSongs();
        dumper.dumpSequences();
        dumper.dumpPatterns();

    // Write WAV file.
    } else if (options.wav != "") {
        if (options.sequence > -1) {
            writefln("Writing sequence %d to %s for %.1f seconds.", options.sequence, options.wav, options.duration);
        } else {
            writefln("Writing subsong %d to %s for %.1f seconds.", options.subSong, options.wav, options.duration);
        }

        if (options.duration is float.nan) {
            writefln("No duration specified.");
            return -1;
        }

        AudioOutputWAV output = new AudioOutputWAV(options.wav, 2, options.sampleRate);

        Mixer mixer = new Mixer(output);
        mixer.volume = options.volume;
        mixer.stereoSeparation = options.stereoSeparation;

        SongPlayer player = new SongPlayer(mixer, song);
        player.outputCommands = false;
        if (options.sequence > -1) {
            player.playSequence(options.sequence);
        } else {
            player.playSubSong(options.subSong);
        }
        mixer.lerp = options.linearInterpolation;

        // Write data until either the song stops or the maximum duration elapses.
        while (player.playing && player.timeIndex < options.duration) {
            output.write();
        }
        player.destroy();
        output.destroy();

    // Audio playback.
    } else {
        DerelictSDL2.load();

        if (options.sequence > -1) {
            writefln("Playing sequence %d. Press Ctrl+C to quit.", options.sequence);
        } else {
            writefln("Playing subsong %d. Press Ctrl+C to quit.", options.subSong);
        }

        if (options.duration !is float.nan) {
            writefln("Stopping playback after %.1f seconds.", options.duration);
        }

        AudioOutputSDL output = new AudioOutputSDL(2, options.sampleRate, cast(uint)(options.sampleRate * 0.04));

        Mixer mixer = new Mixer(output);
        mixer.volume = options.volume;
        mixer.stereoSeparation = options.stereoSeparation;

        SongPlayer player = new SongPlayer(mixer, song);
        player.outputCommands = !options.silent;
        if (options.sequence > -1) {
            player.playSequence(options.sequence);
        } else {
            player.playSubSong(options.subSong);
        }
        mixer.lerp = options.linearInterpolation;

        // Play forever. CTRL+C to stop (sadly, without cleanup).
        while (player.playing) {
            if (options.duration !is double.nan && player.timeIndex >= options.duration) {
                break;
            }
            SDL_Delay(500);
        }
        player.destroy();
        output.destroy();

        SDL_Quit();
    }

    return 0;
}

private void writeHeader() {
    writefln("%s, version %d.%d.%d", NAME, VERSION_MAJOR, VERSION_MINOR, VERSION_PATCH);
    writeln("Copyright (c) 2015, Dennis Meuwissen");
    writeln("All rights reserved.");
    writeln("Special thanks to Martin Bazley for the RJP file format specifications.");
    writeln();
}

private void writeLicense() {
    writeln(text.license.LICENSE);
    exit(0);
}

private void writeHelp() {
    writeln(text.help.HELP);
    exit(0);
}
