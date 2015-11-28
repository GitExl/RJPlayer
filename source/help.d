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

module text.help;

public string HELP = "Plays Richard Joseph music files.

Usage: rjplayer [input files] [options]

-h, --help     Show this help message.
-l, --license  Display this program's license.

Song
--song=filename     The filename of the song to load.
--samples=filename  The filename containing the song's sample data.
-s, --subsong=0     The subsong index to play.

Playback
-r, --samplerate=44100   The samplerate to play at.
--stereo-separation=0.2  The amount of stereo separation to use. Valid values
                         are between 0. and 1.0 (0 to 100%).
-v, --volume=1.0         The master volume to play back with. Valid values are
                         between 0. and 1.0.
-d, --duration           The duration to play the song for, in seconds.

Other
-d, --dump          Outputs the song's data in a readable format and exits.
-w, --wav=filename  Writes the output to a Wave file. A playback duration is
                    required.
--silent            Disables output of song commands and events.";
