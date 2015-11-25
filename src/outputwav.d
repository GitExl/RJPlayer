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

module audio.outputwav;

import std.stdio;

import audio.output;

import util.riffwriter;


private enum WAVFormatType : ushort {
    WAVE_FORMAT_PCM = 0x0001,
    WAVE_FORMAT_IEEE_FLOAT = 0x0003,
}


private align(1) struct WAVFormat {
    ushort type;
    ushort channelCount;
    uint sampleRate;
    uint byteRate;
    ushort blockAlign;
    ushort bitsPerSample;
}


public final class AudioOutputWAV : AudioOutput {
    private immutable uint BUFFER_SIZE = 4096;

    private float[] _buffer;

    private uint _channelCount;
    private uint _sampleRate;

    private RIFFWriter _writer;
    private File _fp;

    private AudioBufferFillFunc _callbackFunc;


    public this(const string fileName, const uint channelCount, const uint sampleRate) {
        _sampleRate = sampleRate;
        _channelCount = channelCount;

        _buffer = new float[BUFFER_SIZE * _channelCount];

        _writer = new RIFFWriter(fileName);

        // Write header.
        WAVFormat format;
        format.type = WAVFormatType.WAVE_FORMAT_IEEE_FLOAT;
        format.channelCount = cast(ushort)channelCount;
        format.sampleRate = sampleRate;
        format.byteRate = sampleRate * channelCount * float.sizeof;
        format.blockAlign = cast(ushort)(channelCount * float.sizeof);
        format.bitsPerSample = float.sizeof * 8;

        _writer.writeList("WAVE");

        // Write format.
        _fp = _writer.writeChunk("fmt ");
        _fp.rawWrite(cast(ubyte[format.sizeof])format);
        _writer.finishChunk();

        // Write start of data.
        _fp = _writer.writeChunk("data");
    }

    public void destroy() {
        _writer.finishChunk();
        _writer.finish();
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

    public void write() {
        fill(_buffer);
        _fp.rawWrite(_buffer);
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
        return BUFFER_SIZE;
    }
}

