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

private immutable ubyte VERSION_MAJOR = 0;
private immutable ubyte VERSION_MINOR = 9;
private immutable ubyte VERSION_PATCH = 0;


struct Options {
    string inputSong = "";
    string inputSamples = "";
    ubyte subSong = 0;
    uint sampleRate = 44100;
    float stereoSeparation = 1.0 / 5;
    float volume = 1.0;
    string wav = "";
    float duration = float.nan;
    bool dump = false;
    bool silent = false;
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
        "wav|w",               &options.wav,
        "duration|d",          &options.duration,
        "dump|d",              &options.dump,
        "silent",              &options.silent
    );

    if (!exists(options.inputSong)) {
        writeln("A valid input song filename is required.");
        return -1;
    }

    if (!exists(options.inputSamples)) {
        writeln("A valid input sample data filename is required.");
        return -1;
    }

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
        writefln("Writing subsong %d to %s for %.1f seconds.", options.subSong, options.wav, options.duration);

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
        player.playSubSong(options.subSong);

        while (player.playing && player.timeIndex < options.duration) {
            output.write();
        }
        player.destroy();
        output.destroy();
    
    // Audio playback.
    } else {
        DerelictSDL2.load();

        writefln("Playing subsong %d. Press Ctrl+C to quit.", options.subSong);
        if (options.duration !is float.nan) {
            writefln("Stopping playback after %.1f seconds.", options.duration);
        }
    
        AudioOutputSDL output = new AudioOutputSDL(2, options.sampleRate, cast(uint)(options.sampleRate * 0.04));

        Mixer mixer = new Mixer(output);
        mixer.volume = options.volume;
        mixer.stereoSeparation = options.stereoSeparation;

        SongPlayer player = new SongPlayer(mixer, song);
        player.outputCommands = !options.silent;
        player.playSubSong(options.subSong);

        while (player.playing) {
            if (options.duration !is float.nan && player.timeIndex >= options.duration) {
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
