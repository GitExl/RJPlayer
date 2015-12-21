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

module song.songplayer;

import std.stdio;
import std.string;
import std.algorithm;

import song.song;
import song.songchannel;

import audio.mixer;
import audio.channel;


private immutable float UPDATE_INTERVAL = 1.0 / 50;


public final class SongPlayer {
    private Song _song;
    private SongChannel[4] _songChannels;

    private Mixer _mixer;
    private Channel[4] _channels;

    private bool _playing = false;
    private double _timeIndex = 0.0;
    private bool _outputCommands = false;


    public this(Mixer mixer, Song song) {
        _mixer = mixer;
        _song = song;

        // Create mixer channels.
        _channels[0] = _mixer.createChannel(OutputChannel.LEFT);
        _channels[1] = _mixer.createChannel(OutputChannel.RIGHT);
        _channels[2] = _mixer.createChannel(OutputChannel.RIGHT);
        _channels[3] = _mixer.createChannel(OutputChannel.LEFT);

        // Create song channels for channel state.
        _songChannels[0] = new SongChannel(_song, _channels[0]);
        _songChannels[1] = new SongChannel(_song, _channels[1]);
        _songChannels[2] = new SongChannel(_song, _channels[2]);
        _songChannels[3] = new SongChannel(_song, _channels[3]);

        // Update function for every interval.
        _mixer.setUpdateCallback(delegate void(Mixer mixer) {
            update();
        }, UPDATE_INTERVAL);
    }

    public void destroy() {
        _mixer.returnChannel(_channels[0]);
        _mixer.returnChannel(_channels[1]);
        _mixer.returnChannel(_channels[2]);
        _mixer.returnChannel(_channels[3]);

        _playing = false;
        _mixer.destroy();
    }

    public void playSubSong(const uint index) {
        SubSong[] subSongs = _song.getSubSongs();
        if (index >= subSongs.length) {
            throw new Exception(format("Invalid subsong index %d.", index));
        }

        if (_outputCommands) {
            writeln("+-------+----------------+----------------+----------------+----------------+");
        }

        // Stop all channels.
        stop();

        // Start subsong sequences on each channel.
        _songChannels[0].setSequence(subSongs[index].sequences[0]);
        _songChannels[1].setSequence(subSongs[index].sequences[1]);
        _songChannels[2].setSequence(subSongs[index].sequences[2]);
        _songChannels[3].setSequence(subSongs[index].sequences[3]);

        _playing = true;
    }

    public void playSequence(const uint sequence) {
        if (sequence >= _song.getSequences().length) {
            throw new Exception(format("Invalid sequence index %d.", sequence));
        }

        if (_outputCommands) {
            writeln("+-------+----------------+----------------+----------------+----------------+");
        }

        stop();

        _songChannels[3].setSequence(sequence);

        _playing = true;
    }

    public void stop() {
        foreach (Channel channel; _channels) {
            channel.stop();
        }
        _playing = false;
    }


    public void update() {
        _timeIndex += UPDATE_INTERVAL;
        uint stopped = 0;

        // Update each active song channel.
        uint maxTextLines = 0;
        foreach (int index, SongChannel songChannel; _songChannels) {
            if (!songChannel.active) {
                stopped++;
                continue;
            }
            songChannel.update();

            maxTextLines = max(songChannel.getEventText().length, maxTextLines);
        }

        // Detect some song endings if no more channels are active.
        // Only works for a few songs that use all 4 channels and fully stop all of them.
        if (stopped == _songChannels.length) {
            _playing = false;
        }

        // Output gathered event commands, formatted into columns.
        if (maxTextLines && _outputCommands) {
            string[][4] eventText;
            eventText[0] = _songChannels[0].getEventText();
            eventText[1] = _songChannels[1].getEventText();
            eventText[2] = _songChannels[2].getEventText();
            eventText[3] = _songChannels[3].getEventText();

            for (int i = 0; i < maxTextLines; i++) {
                string s1 = (i < eventText[0].length) ? eventText[0][i] : "";
                string s2 = (i < eventText[1].length) ? eventText[1][i] : "";
                string s3 = (i < eventText[2].length) ? eventText[2][i] : "";
                string s4 = (i < eventText[3].length) ? eventText[3][i] : "";

                writefln("| %-5.1f | %-14s | %-14s | %-14s | %-14s |", _timeIndex, s1, s2, s3, s4);
            }
            writeln("+-------+----------------+----------------+----------------+----------------+");
        }
    }

    @property
    public bool playing() {
        return _playing;
    }

    @property
    public double timeIndex() {
        return _timeIndex;
    }

    @property
    public void outputCommands(const bool outputCommands) {
        _outputCommands = outputCommands;
    }
}
