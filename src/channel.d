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

module audio.channel;

import std.stdio;
import std.algorithm;

import audio.mixer;


public enum OutputChannel : uint {
    LEFT = 0,
    RIGHT = 1,
}

public final class Channel {
    private OutputChannel _outputChannel;
    
    private float[] _data;
    private float _position = 0.0;
    private float _step = 1.0;
    private uint _outputSampleRate;
    
    private float _volume = 1.0;

    private uint _loopStart;
    private uint _loopEnd;

    private bool _active = false;


    public this(const OutputChannel outputChannel, const uint outputSampleRate) {
        _outputChannel = outputChannel;
        _outputSampleRate = outputSampleRate;
    }

    public float getCurrentSample() {
        immutable float sample = _data[cast(uint)_position] * _volume;

        // Advance sample position.
        _position += _step;
        if (_loopEnd != 0 && _position >= _loopEnd) {
            _position -= _loopEnd - _loopStart;
        } else if (_position >= _data.length) {
            _position = 0;
            _active = false;
        }
        
        return sample;
    }

    public void setSampleData(float[] data, const uint sampleRate) {
        _data = data;
        _position = 0.0;
        _step = cast(float)sampleRate / _outputSampleRate;
        _loopStart = 0;
        _loopEnd = 0;
    }

    public void setLoop(const uint loopStart, const uint loopEnd) {
        if (loopStart >= _data.length) {
            writeln("Sample loop start is past sample data end.");
        }
        if (loopEnd > _data.length) {
            writeln("Sample loop end is past sample data end.");
        }
        if (loopEnd < loopStart) {
            writeln("Sample loop end is before sample loop start.");
        }

        _loopStart = loopStart;
        _loopEnd = loopEnd;
    }

    public void play() {
        if (!_data.length) {
            return;
        }

        _active = true;
    }

    public void pause() {
        _active = false;
    }

    public void stop() {
        _position = 0.0;
        _active = false;
    }

	public void setSampleRate(const uint sampleRate) {
		_step = cast(float)sampleRate / _outputSampleRate;
	}

    @property
    public void volume(const float volume) {
        _volume = max(0.0, min(1.0, volume));
    }

    @property float volume() {
        return _volume;
    }

    @property
    public void position(const uint position) {
        if (position >= _data.length) {
            writeln("Sample position is past sample data end.");
            return;
        }

        _position = cast(float)position;
    }

    @property
    public OutputChannel outputChannel() {
        return _outputChannel;
    }

    @property
    public bool active() {
        return _active;
    }
}