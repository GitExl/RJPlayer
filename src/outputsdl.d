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

module audio.outputsdl;

import std.stdio;
import std.string;

import core.stdc.stdio;

import derelict.sdl2.sdl;

import audio.output;


// This callback is called by SDL when more audio is required.
extern(C) void audioOutputSDLCallback(void *userData, ubyte* data, int length) nothrow {
    try {
        // Get the class instance from the user data pointer.
        AudioOutputSDL output = cast(AudioOutputSDL)userData;
        output.fill(cast(float[])data[0..length]);
    } catch (Exception e) {
        printf("An exception occured in the SDL audio output callback. File %s, line %d: %s\n", toStringz(e.file), e.line, toStringz(e.msg));
    }
}


public final class AudioOutputSDL : AudioOutput {
    private uint _sampleRate;
    private uint _bufferSize;
    private uint _channelCount;

    private AudioBufferFillFunc _callbackFunc;


    public this(const uint channelCount, const uint sampleRate, const uint bufferSize) {
        if (SDL_InitSubSystem(SDL_INIT_AUDIO) != 0) {
            throw new Exception(format("Could not initialize SDL audio subsystem. SDL error %s.", SDL_GetError()));
        }

        // Try to get an audio output specification.
        SDL_AudioSpec desired;
        SDL_AudioSpec obtained;
        desired.freq = sampleRate;
        desired.format = AUDIO_F32SYS;
        desired.channels = cast(ubyte)channelCount;
        desired.samples = cast(ushort)bufferSize;
        desired.callback = &audioOutputSDLCallback;
        desired.userdata = cast(void*)this;

        if (SDL_OpenAudio(&desired, &obtained) < 0) {
            throw new Exception(format("Could not open audio device for playback. %s", SDL_GetError()));
        }

        if (obtained.channels != channelCount) {
            throw new Exception(format("Could not obtain %d channels, only got %d.", channelCount, obtained.channels));
        }

        writefln("Sound output initialized at %d Hz, %d channels and %d samples in buffer.", obtained.freq, obtained.channels, obtained.samples);

        _channelCount = obtained.channels;
        _sampleRate = obtained.freq;
        _bufferSize = obtained.samples;

        SDL_PauseAudio(0);
    }

    public void destroy() {
        SDL_QuitSubSystem(SDL_INIT_AUDIO);
    }

    public void setBufferFillCallback(AudioBufferFillFunc func) {
        _callbackFunc = func;
    }

    public void fill(float[] output) {
        if (_callbackFunc is null) {
            return;
        }
        _callbackFunc(output);
    }

    @property
    public uint channelCount() {
        return _channelCount;
    }

    @property
    public uint sampleRate() {
        return _sampleRate;
    }

    @property
    public uint bufferSize() {
        return _bufferSize;
    }
}