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

module audio.mixer;

import std.stdio;
import std.string;
import std.math;
import std.algorithm;

import derelict.sdl2.sdl;

import audio.channel;
import audio.output;


public alias void delegate(Mixer mixer) MixerCallbackFunc;


public final class Mixer {
    private AudioOutput _output;

    private double _volume = 1.0;
    private double _stereoSeparation = 1.0;

    private Channel[] _channels;

    private MixerCallbackFunc _callback;
    private uint _callbackCounter;
    private uint _callbackInterval;


    public this(AudioOutput output) {
        _output = output;
        _output.setBufferFillCallback(delegate void (float[] buffer) {
            this.mix(buffer);
        });
    }

    public void destroy() {
        _output.setBufferFillCallback(null);
    }

    // Sets the callback to call when an amount of time has passed. The amount of time is
    // converted to a number of samples.
    public void setUpdateCallback(MixerCallbackFunc callback, const double interval) {
        _callback = callback;
        _callbackInterval = cast(uint)ceil(_output.sampleRate * interval);
        writefln("Set mixer update callback at %d samples.", _callbackInterval);

        if (_callback !is null) {
            _callback(this);
        }
    }

    // Mixes all active channels into a single output buffer.
    public void mix(float[] output) {
        output[] = 0.0;

        for (uint bufferIndex = 0; bufferIndex < _output.bufferSize; bufferIndex++) {

            // Call the update callback after enough samples have been mixed to fill the callback interval.
            if (_callback !is null) {
                _callbackCounter += 1;
                if (_callbackCounter >= _callbackInterval) {
                    _callback(this);
                    _callbackCounter = 0;
                }
            }

            // Mix samples from each channel.
            foreach (Channel channel; _channels) {
                if (!channel.active) {
                    continue;
                }

                // Mix channel sample into each output channel.
                const double sample = channel.getCurrentSample();
                for (uint outputChannel = 0; outputChannel < _output.channelCount; outputChannel++) {

                    // Modify sample volume with stereo separation.
                    const double volume = (_output.channelCount == 2 && channel.outputChannel == outputChannel) ?
                        1.0 - _stereoSeparation : 1.0;
                    output[bufferIndex * _output.channelCount + outputChannel] += (sample * volume) / _channels.length;
                }
            }
        }

        output[] *= _volume;
    }

    public Channel createChannel(const OutputChannel outputChannel) {
        Channel channel = new Channel(outputChannel, _output.sampleRate);
        _channels ~= channel;
        return channel;
    }

    public void returnChannel(Channel removeChannel) {
        int removeIndex = -1;
        foreach (int index, Channel channel; _channels) {
            if (channel == removeChannel) {
                removeIndex = index;
            }
        }

        if (removeIndex == -1) {
            throw new Exception("Trying to remove a channel that is not registered.");
        }

        remove(_channels, removeIndex);
    }

    @property void lerp(const bool lerp) {
        foreach (Channel channel; _channels) {
            channel.lerp = lerp;
        }
    }

    @property
    public void stereoSeparation(const double stereoSeparation) {
        _stereoSeparation = max(0.0, min(1.0, stereoSeparation));
    }

    @property
    public void volume(const double volume) {
        _volume = max(0.0, min(1.0, volume));
    }
}
