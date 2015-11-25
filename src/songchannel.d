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

module song.songchannel;

import std.stdio;
import std.string;
import std.algorithm;

import audio.channel;

import song.song;


// Volume slide states.
public enum SlideState : ubyte {
    TO_INTERMEDIATE,
    TO_FINAL,
    TO_ZERO,
    DONE
}

// Playback periods for each note.
private immutable uint[] NOTE_PITCHES = [
    453, 480, 508, 538, 570, 604, 640, 678, 720, 762, 808, 856,
    226, 240, 254, 269, 285, 302, 320, 339, 360, 381, 404, 428,
    113, 120, 127, 135, 143, 151, 160, 170, 180, 190, 202, 214
];

// Period to samplerate conversion scalars.
private immutable float RATE_PAL = 7093789.2;
private immutable float RATE_NTSC = 7159090.5;


public final class SongChannel {
    private Song _song;
    private Channel _channel;

    // True if this channel is playing and executing commands.
    private bool _active;

    // Current playback position.
    private uint _sequenceOffset;
    private uint _sequencePatternIndex;
    private uint _patternOffset;
    private uint _commandIndex;
    private uint _instrumentIndex;

    // Channel volume.
    private float _masterVolume = 0.0;
    
    // Delay between events.
    private ubyte _speed = 6;
    private ubyte _delay = 1;
    private ubyte _speedCounter = 6;
    private ubyte _delayCounter = 1;

    // Current volume slide.
    private uint _slideIndex = 0;
    private float _sourceVolume = 1.0;
    private float _targetVolume = 0.0;
    private float _slideVolume = 1.0;
    private int _slideCounter = 0;
    private ubyte _slideDuration = 0;
    private SlideState _slideState = SlideState.DONE;

	// Tremolo.
    private uint _tremoloSample;
	private float _tremoloVolume = 1.0;

    // Vibrato.
	private uint _vibratoSample;
	private uint _initialPeriod;

    // Pitch slide.
    private float _pitchSlide = 0.0;
    private ubyte _pitchSlideDuration;
    private float _pitchSlideAccumulator = 0.0;

    // List of events from the last event execution.
    private string[] _eventText;


    public this(Song song, Channel channel) {
        _song = song;
        _channel = channel;
    }

    // Sets a new pattern on this channel.
    package void setPattern(const uint patternIndex) {
        Pattern[uint] patterns = _song.getPatterns();
        const uint offset = _song.getPatternOffset(patternIndex);

        // Invalid pattern.
        if (offset !in patterns) {
            throw new Exception(format("Invalid pattern 0x%04X.", offset));
        }
        
        // Start new pattern from command 0.
        _patternOffset = offset;
        _commandIndex = 0;
    }

    // Sets a new volume slide on this channel.
    package void setSlide(const uint slideIndex, const SlideState state) {
        const VolumeSlide slide = _song.getVolumeSlide(slideIndex);
        _slideIndex = slideIndex;
        
        // Set defaults for each volume slide state.
        switch (state) {
            case SlideState.TO_INTERMEDIATE:
                if (slideIndex) {
                    _eventText ~= format("VSLIDE %d INT", slideIndex);
                }
                _slideVolume = slide.initialVolume;
                _sourceVolume = slide.initialVolume;
                _targetVolume = slide.intermediateVolume;
                _slideDuration = slide.toIntermediateDuration;
                _slideCounter = slide.toIntermediateDuration;
                _slideState = SlideState.TO_INTERMEDIATE;
                break;

            case SlideState.TO_FINAL:
                if (slideIndex) {
                    _eventText ~= format("VSLIDE %d FINAL", slideIndex);
                }
                _sourceVolume = _slideVolume;
                _targetVolume = slide.finalVolume;
                _slideDuration = slide.toFinalDuration;
                _slideCounter = slide.toFinalDuration;
                _slideState = SlideState.TO_FINAL;
                break;

            case SlideState.TO_ZERO:
                if (slideIndex) {
                    _eventText ~= format("VSLIDE %d 0", slideIndex);
                }
                _sourceVolume = _slideVolume;
                _targetVolume = 0;
                _slideDuration = slide.toZeroDuration;
                _slideCounter = slide.toZeroDuration;
                _slideState = SlideState.TO_ZERO;
                break;

            case SlideState.DONE:
                if (slideIndex) {
                    _eventText ~= format("VSLIDE %d DONE", slideIndex);
                }
                _slideState = SlideState.DONE;
                break;

            default:
                throw new Exception("Invalid volume slide state.");
        }
    }

    // Sets a new sequence on this channel. Usually only called when a new
    // subsong starts.
    package void setSequence(const uint sequenceIndex) {
        
        // Sequence 0 stops the channel.
        if (sequenceIndex == 0) {
            _active = false;
            return;
        }

        Sequence[uint] sequences = _song.getSequences();
        const uint offset = _song.getSequenceOffset(sequenceIndex);
        
        // Invalid sequence.
        if (offset !in sequences) {
            throw new Exception(format("Invalid sequence 0x%04X.", offset));
        }

        // Valid sequence, acivate channel.
        _sequenceOffset = offset;
        _sequencePatternIndex = 0;
        _active = true;

        setPattern(sequences[offset].patternIndices[0]);
    }

    // Updates this channel's state.
    package void update() {
		_eventText.length = 0;

        // Advance counters until an event needs to run.
        _speedCounter -= 1;
        if (_speedCounter == 0) {
            _delayCounter -= 1;
            if (_delayCounter == 0) {
                executeEvent();
                _delayCounter = _delay;
            }
            _speedCounter = _speed;
        }

        updateVolume();
        updatePitch();
    }

    // Updates the pitch (channel samplerate) of the current sample.
    private void updatePitch() {
        const Instrument instrument = _song.getInstrument(_instrumentIndex);
        uint period = _initialPeriod;

        // Advance vibrato sample index and set new pitch.
		if (instrument.vibratoLength > 2) {
			_vibratoSample += 1;
			if (_vibratoSample >= instrument.vibratoData.length) {
				_vibratoSample = instrument.vibratoLoopStart;
			}
			
            // Calculate new pitch based on the initial note pitch and the
            // vibrato sample data.
			const float vibrato = instrument.vibratoData[_vibratoSample];
			period = cast(uint)(_initialPeriod * (1.0 - vibrato));
		}

        // Update pitch slide accumulator.
        if (_pitchSlideDuration) {
            _pitchSlideAccumulator += _pitchSlide;
            period += cast(uint)_pitchSlideAccumulator;
            _pitchSlideDuration -= 1;
        }

        _channel.setSampleRate(getSampleRateForPeriod(period));
    }

    // Updates the channel volume of the current sample.
    private void updateVolume() {
        const Instrument instrument = _song.getInstrument(_instrumentIndex);

        // Calculate volume slide volume.
        if (_slideIndex && _slideState != SlideState.DONE) {
            _slideVolume = _targetVolume - (_targetVolume - _sourceVolume) * _slideCounter / _slideDuration;

            // Transition to new slide state if needed.
            _slideCounter -= 1;
            if (_slideCounter < 0) {
                if (_slideState == SlideState.TO_INTERMEDIATE) {
                    setSlide(_slideIndex, SlideState.TO_FINAL);
                } else {
                    setSlide(_slideIndex, SlideState.DONE);
                }
            }
        }

		// Advance tremolo sample index.
		if (instrument.tremoloLength > 2) {
			_tremoloSample += 1;
			if (_tremoloSample >= instrument.tremoloData.length) {
				_tremoloSample = instrument.tremoloLoopStart;
			}
			_tremoloVolume += _tremoloVolume * instrument.tremoloData[_tremoloSample];
		}

        // Apply calculated volume to output audio channel.
        _channel.volume = _slideVolume * _tremoloVolume * _masterVolume;
		_channel.volume = max(0.0, min(_channel.volume, 1.0));
    }

    // Executes a pattern's commands until the event is considered done.
    // An event being done is determined by the last command, see eventEnd = true.
    package void executeEvent() {
        bool eventEnd = false;

        _pitchSlideDuration = 0;
        _pitchSlideAccumulator = 0.0;

        while (!eventEnd) {
            const Pattern pattern = _song.getPattern(_patternOffset);
            const Command command = pattern.commands[_commandIndex++];
            
            switch (command.type) {

                // Set playback speed.
                case CommandType.SET_SPEED:
                    _eventText ~= format("SPEED %d", command.parameter1);
                    _speed = command.parameter1;
                    break;

                // Set next event delay.
                case CommandType.SET_DELAY:
                    _eventText ~= format("DELAY %d", command.parameter1);
                    _delay = command.parameter1;
                    break;

                // Set master volume.
                case CommandType.SET_VOLUME:
                    _eventText ~= format("VOLUME %d", command.parameter1);
                    _masterVolume = command.parameter1 / 64.0;
                    break;

                // Set instrument.
                case CommandType.SET_INSTRUMENT:
                    _eventText ~= format("INSTR %d", command.parameter1);
                    setInstrument(command.parameter1);
                    break;

                // Play a note.
                case CommandType.NOTE:
                    _eventText ~= format("NOTE %d", command.parameter1);
                    playNote(command.parameter1);
                    eventEnd = true;
                    break;

				// Start a pitch slide.
                case CommandType.PITCH_SLIDE:
                    _eventText ~= format("PSLIDE %d %.1f", command.parameter1, command.parameter2);
                    _pitchSlideDuration = command.parameter1;
                    _pitchSlideAccumulator = 0.0;
                    _pitchSlide = command.parameter2;
                    break;

                // End this pattern (but not necessarily this event!).
                case CommandType.PATTERN_END:
                    _eventText ~= "PATTERN END";
                    eventEnd = endPattern();
                    break;

                // End this event whilst fading out.
                case CommandType.EVENT_END_FADE:
                    _eventText ~= "EVENT END";
                    setSlide(_slideIndex, SlideState.TO_ZERO);
                    eventEnd = true;
                    break;

                // End this event.
                case CommandType.EVENT_END:
                    _eventText ~= "EVENT END";
                    eventEnd = true;
                    break;

                default:
                    _eventText ~= format("UNKNOWN 0x%02X", command.type);
            }
        }
    }

    // Sets the current isntrument.
    private void setInstrument(const ubyte instrumentIndex) {

        // Setting instrument 0 or the same instrument as is currently set does nothing.
        if (instrumentIndex != 0 && instrumentIndex != _instrumentIndex) {
            const Instrument instrument = _song.getInstrument(instrumentIndex);
            _masterVolume = instrument.volume;

            // Reset tremolo and vibrato.
            _tremoloSample = 0;
		    _tremoloVolume = 1.0;
            _vibratoSample = 0;
        }

        _instrumentIndex = instrumentIndex;
    }

    // Plays a note using the current instrument.
    private void playNote(const ubyte note) {
        _channel.stop();

        // Zero length instruments do nothing.
        const Instrument instrument = _song.getInstrument(_instrumentIndex);
        if (instrument.initialLength <= 2) {
            return;
        }
		
        _initialPeriod = NOTE_PITCHES[note];
        _channel.setSampleData(_song.getInstrumentSampleData(_instrumentIndex), getSampleRateForPeriod(_initialPeriod));
        if (instrument.sampleLoopLength > 2) {
            _channel.setLoop(instrument.sampleLoopStart, instrument.sampleLoopStart + instrument.sampleLoopLength);
        }
        if (instrument.initialOffset > 0) {
            _channel.position = instrument.initialOffset;
        }
        setSlide(instrument.volumeSlideIndex, SlideState.TO_INTERMEDIATE);

        _channel.play();
    }

    // Ends this pattern. Advances to the next pattern in the current sequence, or
    // does something else if the sequence has ended.
    private bool endPattern() {

        // Advance to next pattern.
        _sequencePatternIndex += 1;

        // End of sequence is reached, do something else.
        const Sequence sequence = _song.getSequence(_sequenceOffset);
        if (_sequencePatternIndex >= sequence.patternIndices.length) {
            _eventText ~= "SEQUENCE END";

            // Loop back a number of patterns.
            if (sequence.loopBack) {
                _eventText ~= format("REVERT %d", sequence.loopBack);
                _sequencePatternIndex -= sequence.loopBack;

            // Start another sequence.
            } else if (sequence.nextSequence) {
                _eventText ~= format("GOTO %d", sequence.nextSequence);
                setSequence(_song.sequenceOffsetToIndex(sequence.nextSequence));

            // Stop playback.
            } else {
                _eventText ~= "STOP";
                _active = false;
                return true;
            }
        }

        _eventText ~= format("PATTERN %d", sequence.patternIndices[_sequencePatternIndex]);
        setPattern(sequence.patternIndices[_sequencePatternIndex]);

        return false;
    }

    // Returns the samplerate required to play back a note at a certain period.
	private uint getSampleRateForPeriod(const uint period) {
		return cast(uint)(RATE_PAL / (period * 2));
	}

    // Returns the text of events that occured in the last update.
    package string[] getEventText() {
        return _eventText;
    }

    @property
    package bool active() {
        return _active;
    }
}
