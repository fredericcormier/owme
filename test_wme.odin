package owme

import "core:fmt"
import "core:log"
import "core:math"
import "core:testing"

//-----------------------------------------------------------------------------
//		rounding

@(test)
test_rounding_1 :: proc(t: ^testing.T) {
	testing.expectf(t, round_to(1.234567, 3) == 1.235, "Rounding 1.234567 to 3 decimal places should be 1.235 not: %f", round_to(1.234567, 3))
}

@(test)
test_rounding_to_1 :: proc(t: ^testing.T) {
	testing.expectf(t, round_to(1.234567, 2) == 1.23, "Rounding 1.234567 to 2 decimal places should be 1.22 not: %f", round_to(1.234567, 2))
}

@(test)
test_rounding_to_2 :: proc(t: ^testing.T) {
	testing.expectf(t, round_to(1.234567, 3) == 1.235, "Rounding 1.234567 to 3 decimal place should be 1.234 not: %f", round_to(1.234567, 3))
}
//-----------------------------------------------------------------------------
//		Note

@(test)
test_note_1 :: proc(t: ^testing.T) {
	note := note("A", 4)
	testing.expectf(t, note.name == "A", "Note name should be A, not %s", note.name)
	testing.expectf(t, note.octave == 4, "Note octave should be 4, not %d", note.octave)
}

@(test)
test_note_2 :: proc(t: ^testing.T) {
	note := note(69)
	testing.expectf(t, note.name == "A", "Note name should be A, not %s", note.name)
	testing.expectf(t, note.octave == 4, "Note octave should be 4, not %d", note.octave)
}

@(test)
test_note_3 :: proc(t: ^testing.T) {
	note := note("B", 7)
	testing.expectf(t, note.name == "B", "Note name should be C, not %s", note.name)
	testing.expectf(t, note.octave == 7, "Note octave should be 4, not %d", note.octave)
}


@(test)
test_note_4 :: proc(t: ^testing.T) {
	note := note(109)
	testing.expectf(t, note.name == "C#", "Note name should be C#, not %s", note.name)
	testing.expectf(t, note.octave == 8, "Note octave should be 8, not %d", note.octave)
}

//-----------------------------------------------------------------------------
//		frequency from midi note number
//

@(test)
test_frequency_from_number_1 :: proc(t: ^testing.T) {
	f, ok := frequency(69)
	testing.expectf(t, f == 440.0, "Note 69 should be 440 hertz, not %f", f)
}

@(test)
test_frequency_from_number_2 :: proc(t: ^testing.T) {
	f, ok := frequency(60)
	f_rounded := round_to(f, 2)
	testing.expectf(t, f_rounded == 261.63, "Note 60 should be 261.63 hertz, not %f32", f_rounded)
}

@(test)
test_frequency_from_number_3 :: proc(t: ^testing.T) {
	f, ok := frequency(97)
	f_rounded := round_to(f, 2)
	testing.expectf(t, f_rounded == 2217.46, "Note 97 should be 2217.460 hertz, not %f32", f_rounded)
}

@(test)
test_frequency_from_number_4 :: proc(t: ^testing.T) {
	f, ok := frequency(106)
	f_rounded := round_to(f, 3)
	testing.expectf(t, f_rounded == 3729.310, "Note 106 should be 3729.310 hertz, not %f32", f_rounded)
}

@(test)
test_frequency_from_number_5 :: proc(t: ^testing.T) {
	f, ok := frequency(6)
	f_rounded := round_to(f, 2)
	testing.expectf(t, f_rounded == 11.56, "Note 106 should be 11.56 hertz, not %f32", f_rounded)
}

//-----------------------------------------------------------------------------
//		Frequency from name and octave

@(test)
test_frequency_from_notename_and_octave_1 :: proc(t: ^testing.T) {
	f, ok := frequency("A", 4)
	testing.expectf(t, f == 440.0, "Note A4 should be 440 hertz, not %f", f)
}

@(test)
test_frequency_from_notename_and_octave_2 :: proc(t: ^testing.T) {
	f, ok := frequency("D", 2)
	testing.expectf(t, round_to(f, 3) == 73.416, "Note D2 should be 73.416 hertz, not %f", f)
}

@(test)
test_frequency_from_notename_and_octave_3 :: proc(t: ^testing.T) {
	f, ok := frequency("B", 6)
	// it should be 1975.533 but because of rounding "variances" it is 1975.534
	testing.expectf(t, round_to(f, 3) == 1975.534, "Note B6 should be 1975.534 hertz, not %f", f)
}

//-----------------------------------------------------------------------------
//		Midi note number from name and octave

@(test)
test_midi_note_number_from_notename_and_octave_1 :: proc(t: ^testing.T) {
	n, ok := midi_note_number("A", 4)
	testing.expectf(t, n == 69, "A4 should be note 69, not %d", n)
}

@(test)
test_midi_note_number_from_notename_and_octave_2 :: proc(t: ^testing.T) {
	n, ok := midi_note_number("F#", 5)
	testing.expectf(t, n == 78, "F#5 should be note 78, not %d", n)
}

@(test)
test_midi_note_number_from_notename_and_octave_3 :: proc(t: ^testing.T) {
	n, ok := midi_note_number("C#", 8)
	testing.expectf(t, n == 109, "C# 8 should be note 109, not %d", n)
}

@(test)
test_midi_note_number_from_notename_and_octave_4 :: proc(t: ^testing.T) {
	n, ok := midi_note_number("G#", 2)
	testing.expectf(t, n == 44, "G#2 should be note 44, not %d", n)
}


//-----------------------------------------------------------------------------
//		Name and octave from frequency
//
//     	"XXX_from_frequency" returns the name and octave OR
// 		the midi note number of the "closest" note for the frequency

@(test)
test_notename_and_octave_from_frequency_1 :: proc(t: ^testing.T) {
	name, octave, ok := notename_and_octave(440.0)
	testing.expectf(t, name == "A", "Note 440.0 should be A, not %s", name)
	testing.expectf(t, octave == 4, "Note 440.0 should be in octave 4, not %d", octave)
}

@(test)
test_notename_and_octave_from_frequency_2 :: proc(t: ^testing.T) {
	name, octave, ok := notename_and_octave(261.63)
	testing.expectf(t, name == "C", "Note 261.63 should be C, not %s", name)
	testing.expectf(t, octave == 4, "Note 261.63 should be in octave 4, not %d", octave)
}

@(test)
test_notename_and_octave_from_frequency_3 :: proc(t: ^testing.T) {
	name, octave, ok := notename_and_octave(2217)
	testing.expectf(t, name == "C#", "Note 2217.46 should be C#, not %s", name)
	testing.expectf(t, octave == 7, "Note 2217.46 should be in octave 7, not %d", octave)
}

@(test)
test_notename_and_octave_from_frequency_4 :: proc(t: ^testing.T) {
	name, octave, ok := notename_and_octave(3729.310)
	testing.expectf(t, name == "A#", "Note 3729.310 should be F#, not %s", name)
	testing.expectf(t, octave == 7, "Note 3729.310 should be in octave 8, not %d", octave)
}

//-----------------------------------------------------------------------------
//		Midi note number from frequency
//
//     	"XXX_from_frequency" returns the name and octave OR
// 		the midi note number of the "closest" note for the frequency

@(test)
test_midi_note_number_from_frequency_1 :: proc(t: ^testing.T) {
	n, ok := midi_note_number(440.0)
	testing.expectf(t, n == 69, "Note 440.0 should be note 69, not %d", n)
}

@(test)
test_midi_note_number_from_frequency_2 :: proc(t: ^testing.T) {
	n, ok := midi_note_number(261.63)
	testing.expectf(t, n == 60, "Note 261.63 should be note 60, not %d", n)
}

@(test)
test_midi_note_number_from_frequency_3 :: proc(t: ^testing.T) {
	n, ok := midi_note_number(2217)
	testing.expectf(t, n == 97, "Note 2217.46 should be note 97, not %d", n)
}

//-----------------------------------------------------------------------------
//Chords

@(test)
//[60, 64, 67]
test_chord_1 :: proc(t: ^testing.T) {
	init_owme()
	chord := chord("C", 4, "major")
	testing.expectf(t, chord[0] == 60, "Chord note 0 should be 60, not %d", chord[0])
	testing.expectf(t, chord[1] == 64, "Chord note 1 should be 64, not %d", chord[1])
	testing.expectf(t, chord[2] == 67, "Chord note 2 should be 67, not %d", chord[2])
	delete(chord)
	cleanup_owme()

}
@(test)
//[62, 65, 69]
test_chord_2 :: proc(t: ^testing.T) {
	init_owme()
	chord := chord("D", 4, "major")
	testing.expectf(t, chord[0] == 62, "Chord note 0 should be 62, not %d", chord[0])
	testing.expectf(t, chord[1] == 66, "Chord note 1 should be 66, not %d", chord[1])
	testing.expectf(t, chord[2] == 69, "Chord note 2 should be 69, not %d", chord[2])
	delete(chord)
	cleanup_owme()
}


@(test)
//[64, 67, 71]
test_chord_3 :: proc(t: ^testing.T) {
	init_owme()
	chord := chord("E", 4, "major")
	testing.expectf(t, chord[0] == 64, "Chord note 0 should be 64, not %d", chord[0])
	testing.expectf(t, chord[1] == 68, "Chord note 1 should be 68, not %d", chord[1])
	testing.expectf(t, chord[2] == 71, "Chord note 2 should be 71, not %d", chord[2])
	delete(chord)
	cleanup_owme()
}

@(test)
//[30,33,37,40]
test_chord_4 :: proc(t: ^testing.T) {
	init_owme()
	chord := chord("F#", 1, "minor7")
	testing.expectf(t, chord[0] == 30, "Chord note 0 should be 30, not %d", chord[0])
	testing.expectf(t, chord[1] == 33, "Chord note 1 should be 33, not %d", chord[1])
	testing.expectf(t, chord[2] == 37, "Chord note 2 should be 37, not %d", chord[2])
	testing.expectf(t, chord[3] == 40, "Chord note 3 should be 40, not %d", chord[3])
	delete(chord)
	cleanup_owme()
}

@(test)
//[30,34,37,41,44,47,51]
test_chord_5 :: proc(t: ^testing.T) {
	init_owme()
	chord := chord("F#", 1, "major13")
	testing.expectf(t, chord[0] == 30, "Chord note 0 should be 30, not %d", chord[0])
	testing.expectf(t, chord[1] == 34, "Chord note 1 should be 34, not %d", chord[1])
	testing.expectf(t, chord[2] == 37, "Chord note 2 should be 37, not %d", chord[2])
	testing.expectf(t, chord[3] == 41, "Chord note 3 should be 41, not %d", chord[3])
	testing.expectf(t, chord[4] == 44, "Chord note 4 should be 44, not %d", chord[4])
	testing.expectf(t, chord[5] == 47, "Chord note 5 should be 47, not %d", chord[5])
	testing.expectf(t, chord[6] == 51, "Chord note 6 should be 51, not %d", chord[6])
	delete(chord)
	cleanup_owme()
}

//-----------------------------------------------------------------------------
//	Scale

@(test)
test_scale_1 :: proc(t: ^testing.T) {
	init_owme()
	scale := scale("C", 4, "ionian")
	testing.expectf(t, scale[0] == 60, "Scale note 0 should be 60, not %d", scale[0])
	testing.expectf(t, scale[1] == 62, "Scale note 1 should be 62, not %d", scale[1])
	testing.expectf(t, scale[2] == 64, "Scale note 2 should be 64, not %d", scale[2])
	testing.expectf(t, scale[3] == 65, "Scale note 3 should be 65, not %d", scale[3])
	testing.expectf(t, scale[4] == 67, "Scale note 4 should be 67, not %d", scale[4])
	testing.expectf(t, scale[5] == 69, "Scale note 5 should be 69, not %d", scale[5])
	testing.expectf(t, scale[6] == 71, "Scale note 6 should be 71, not %d", scale[6])
	testing.expectf(t, scale[7] == 72, "Scale note 7 should be 72, not %d", scale[7])
	delete(scale)
	cleanup_owme()
}

@(test)
test_scale_2 :: proc(t: ^testing.T) {
	init_owme()
	scale := scale("D", 4, "dorian")
	testing.expectf(t, scale[0] == 62, "Scale note 0 should be 62, not %d", scale[0])
	testing.expectf(t, scale[1] == 64, "Scale note 1 should be 64, not %d", scale[1])
	testing.expectf(t, scale[2] == 65, "Scale note 2 should be 65, not %d", scale[2])
	testing.expectf(t, scale[3] == 67, "Scale note 3 should be 67, not %d", scale[3])
	testing.expectf(t, scale[4] == 69, "Scale note 4 should be 69, not %d", scale[4])
	testing.expectf(t, scale[5] == 71, "Scale note 5 should be 71, not %d", scale[5])
	testing.expectf(t, scale[6] == 72, "Scale note 6 should be 72, not %d", scale[6])
	testing.expectf(t, scale[7] == 74, "Scale note 7 should be 74, not %d", scale[7])
	delete(scale)
	cleanup_owme()
}

@(test)
test_scale_3 :: proc(t: ^testing.T) {
	init_owme()
	scale := scale("E", 4, "phrygian")
	testing.expectf(t, scale[0] == 64, "Scale note 0 should be 64, not %d", scale[0])
	testing.expectf(t, scale[1] == 65, "Scale note 1 should be 65, not %d", scale[1])
	testing.expectf(t, scale[2] == 67, "Scale note 2 should be 67, not %d", scale[2])
	testing.expectf(t, scale[3] == 69, "Scale note 3 should be 69, not %d", scale[3])
	testing.expectf(t, scale[4] == 71, "Scale note 4 should be 71, not %d", scale[4])
	testing.expectf(t, scale[5] == 72, "Scale note 5 should be 72, not %d", scale[5])
	testing.expectf(t, scale[6] == 74, "Scale note 6 should be 74, not %d", scale[6])
	testing.expectf(t, scale[7] == 76, "Scale note 7 should be 76, not %d", scale[7])
	delete(scale)
	cleanup_owme()
}

@(test)
test_string_from_note_1 :: proc(t: ^testing.T) {
	note := note("A", 4)
	s := note_to_string(note)
	testing.expectf(t, s == "A 4", "String should be A 4, not %s", s)
}

@(test)
test_string_from_note_2 :: proc(t: ^testing.T) {
	note := note(97)
	s := note_to_string(note)
	testing.expectf(t, s == "C# 7", "String should be C# 7, not %s", s)
}

@(test)
test_string_from_note_3 :: proc(t: ^testing.T) {
	note := note(123.470)
	s := note_to_string(note)
	testing.expectf(t, s == "B 2", "String should be B 2, not %s", s)
}

@(test)
test_notes_from_chord_1 :: proc(t: ^testing.T) {
	init_owme()
	chord := chord("C", 4, "major")
	notes, _ := notes(chord)
	testing.expectf(t, len(notes) == 3, "There should be 3 notes in the chord, not %d", len(notes))
	testing.expectf(t, notes[0].name == "C", "First note should be C, not %s", notes[0].name)
	testing.expectf(t, notes[1].name == "E", "Second note should be E, not %s", notes[1].name)
	testing.expectf(t, notes[2].name == "G", "Third note should be G, not %s", notes[2].name)
	delete(chord)
	delete(notes)
	cleanup_owme()
}

@(test)
test_notes_from_chord_2 :: proc(t: ^testing.T) {
	init_owme()
	chord := chord("D", 4, "major")
	notes, _ := notes(chord)
	testing.expectf(t, len(notes) == 3, "There should be 3 notes in the chord, not %d", len(notes))
	testing.expectf(t, notes[0].name == "D", "First note should be D, not %s", notes[0].name)
	testing.expectf(t, notes[1].name == "F#", "Second note should be F#, not %s", notes[1].name)
	testing.expectf(t, notes[2].name == "A", "Third note should be A, not %s", notes[2].name)
	delete(chord)
	delete(notes)
	cleanup_owme()
}


@(test)
test_notes_from_scale_1 :: proc(t: ^testing.T) {
	init_owme()
	scale := scale("C#", 4, "mixolydian")
	notes, _ := notes(scale)
	testing.expectf(t, len(notes) == 8, "There should be 8 notes in the scale, not %d", len(notes))
	testing.expectf(t, notes[0].name == "C#", "First note should be C#, not %s", notes[0].name)
	testing.expectf(t, notes[1].name == "D#", "Second note should be D#, not %s", notes[1].name)
	testing.expectf(t, notes[2].name == "F", "Third note should be F, not %s", notes[2].name)
	testing.expectf(t, notes[3].name == "F#", "Fourth note should be F#, not %s", notes[3].name)
	testing.expectf(t, notes[4].name == "G#", "Fifth note should be G#, not %s", notes[4].name)
	testing.expectf(t, notes[5].name == "A#", "Sixth note should be A#, not %s", notes[5].name)
	testing.expectf(t, notes[6].frequency == 493.8833, "Seventh note should be 493.8833, not %f", notes[6].frequency)
	testing.expectf(t, notes[7].mnn == 73, "Eighth note should be 73, not %i", notes[7].mnn)
	delete(scale)
	delete(notes)
	cleanup_owme()
}

@(test)
test_c_ionian_fingering :: proc(t: ^testing.T) {
	init_owme()
	scale := scale("C", 3, "ionian")
	guitar_standard := tuning("guitarStandard")
	fingering := fingering(guitar_standard, NoteCollection(scale))
	testing.expectf(t, fingering[4][3].mnn == 48, "Note should be 48, not %i", fingering[4][3].mnn)
	testing.expectf(t, fingering[3][7].mnn == 57, "Note should be 57, not %i", fingering[3][7].mnn)
	testing.expectf(t, fingering[2][1].mnn == -1, "Note should be -1, not %i", fingering[2][1].mnn)
	testing.expectf(t, fingering[1][4].mnn == -1, "Note should be -1, not %i", fingering[1][4].mnn)
	testing.expectf(t, fingering[5][13].mnn == 53, "Note should be 53, not %i", fingering[5][13].mnn)
	delete(scale)
	cleanup_fingering(fingering)
	cleanup_owme()
}


/**********************
*/
@(test)
test_simple_intervals :: proc(t: ^testing.T) {
	n1 := Note {
		mnn = 60,
	}
	n2 := Note {
		mnn = 62,
	}
	testing.expectf(t, interval_between(n1, n2) == 2, "Interval between C and D should be 2, not %i", interval_between(n1, n2))
	testing.expectf(t, interval_between(60, 62) == 2, "Interval between 60 and 62 should be 2, not %i", interval_between(60, 62))
}

@(test)
test_simple_intervals_2 :: proc(t: ^testing.T) {
	n1 := Note {
		mnn = 66,
	}
	n2 := Note {
		mnn = 73,
	}
	testing.expectf(t, interval_between(n1, n2) == 7, "Interval between 66 and 73 should be 7, not %i", interval_between(n1, n2))
	testing.expectf(t, interval_between(66, 73) == 7, "Interval between 66 and 73 should be 7, not %i", interval_between(66, 73))
}

@(test)
test_simple_interval_names_ :: proc(t: ^testing.T) {
	n1 := Note {
		mnn = 66,
	}
	n2 := Note {
		mnn = 71,
	}
	testing.expectf(t, interval_between(n1, n2) == 5, "Interval between 66 and 71 should be 5, not %i", interval_between(n1, n2))
	testing.expectf(t, interval_between(66, 71) == 5, "Interval between 66 and 71 should be 5, not %i", interval_between(66, 71))

	o, s, _ := interval_name(5)
	testing.expectf(t, (o == 0 && s == "Perfect 4th"), "Interval name for a perfect fourth should be Perfect 4th, not %i, %s", interval_name(5))
}

@(test)
test_simple_interval_names_2 :: proc(t: ^testing.T) {
	n1 := Note {
		mnn = 66,
	}
	n2 := Note {
		mnn = 73,
	}
	testing.expectf(t, interval_between(n1, n2) == 7, "Interval between 66 and 73 should be 7, not %i", interval_between(n1, n2))
	testing.expectf(t, interval_between(66, 73) == 7, "Interval between 66 and 73 should be 7, not %i", interval_between(66, 73))
	o, s, _ := interval_name(7)
	testing.expectf(t, (o == 0 && s == "Perfect 5th"), "Interval name for a Perfect 5th should not be %i, %s", interval_name(7))
}

@(test)
test_simple_interval_names_3 :: proc(t: ^testing.T) {
	n1 := Note {
		mnn = 66,
	}
	n2 := Note {
		mnn = 70,
	}
	testing.expectf(t, interval_between(n1, n2) == 4, "Interval between 66 and 70 should be 4, not %i", interval_between(n1, n2))
	testing.expectf(t, interval_between(66, 70) == 4, "Interval between 66 and 70 should be 4, not %i", interval_between(66, 70))
	o, s, _ := interval_name(4)
	testing.expectf(t, (o == 0 && s == "Major 3rd"), "Interval name for a Major Third should not be %i, %s", interval_name(4))
}


@(test)
test_over_thirteenth_intervals_1 :: proc(t: ^testing.T) {
	o, s, _ := interval_name(14)
	testing.expectf(t, (o == 0 && s == "Major 9th"), "Interval name for 14 should be Major 9th, not %i, %s", interval_name(14))
}

@(test)
test_over_thirteenth_intervals_2 :: proc(t: ^testing.T) {
	o, s, _ := interval_name(23)
	testing.expectf(t, (o == 0 && s == "Major 14th"), "Interval name for 23h should be Perfect 14th, not %i, %s", interval_name(23))
}


@(test)
test_over_2_octaves_intervals_1 :: proc(t: ^testing.T) {
	o, s, _ := interval_name(27)
	testing.expectf(t, (o == 2 && s == "Minor 3rd"), "Interval name for 27 should be 2 octaves and Major 3rd, not %i octaves and %s", interval_name(27))
}

@(test)
test_simple_negative_intervals_1 :: proc(t: ^testing.T) {
	testing.expectf(t, interval_between(73, 66) == -7, "Interval between 66 and 73 should be -7, not %i", interval_between(73, 66))
}


@(test)
test_negative_intervals_name_1 :: proc(t: ^testing.T) {
	o, s, _ := interval_name(-5)
	testing.expectf(t, (o == -1 && s == "Perfect 5th"), "Interval name for -5 st should be octave -1, Perfect Fith, not %i, %s ", interval_name(-5))
}

@(test)
test_negative_intervals_name_2 :: proc(t: ^testing.T) {
	o, s, _ := interval_name(-14)
	testing.expectf(t, (o == -2 && s == "Minor 7th"), "Interval name for -14 should be octave -2, Minor 7th, not %i, %s ", interval_name(-14))
}

@(test)
test_negative_intervals_name_3 :: proc(t: ^testing.T) {
	o, s, _ := interval_name(-29)
	testing.expectf(t, (o == -3 && s == "Perfect 5th"), "Interval name for -29 should be octave -2, Perfect 5th, not %i, %s ", interval_name(-29))
}

@(test)
test_mnn_at_interval_1 :: proc(t: ^testing.T) {
	testing.expectf(t, (mnn_at_interval(14, .major_3rd)) == 18, "Major 3rd from mnn 14 should be 18, not %i", mnn_at_interval(14, .major_3rd))
}

@(test)
test_mnn_at_interval_2 :: proc(t: ^testing.T) {
	testing.expectf(t, (mnn_at_interval(27, .major_7th)) == 38, "Major 7th from mnn 14 should be 38, not %i", mnn_at_interval(27, .major_7th))
}

@(test)
test_inversion1 :: proc(t: ^testing.T) {
	c1 := Chord{60, 64, 67}
	c2 := Chord{64, 67, 60}
	c3 := Chord{67, 60, 64}
	testing.expectf(t, inversion(c1) == 0, "c1 is C major in root position ")
	testing.expectf(t, inversion(c2) == 1, "c2 is C major in first inversion ")
	testing.expectf(t, inversion(c3) == 2, "c3 is C major in second inversion ")
}


@(test)
test_inversion_2 :: proc(t: ^testing.T) {
	c1 := Chord{30, 34, 37, 41, 44, 47, 51}
	c2 := Chord{41, 44, 47, 51, 30, 34, 37}
	c3 := Chord{47, 51, 30, 34, 37, 41, 44}
	testing.expectf(t, inversion(c1) == 0, "c1 is F# 1 Major13 in root position ")
	testing.expectf(t, inversion(c2) == 3, "c2 is F# 1 Major13 in third inversion ")
	testing.expectf(t, inversion(c3) == 5, "c3 is F# 1 Major13 in fith inversion ")
}


@(test)
test_invert_chord :: proc(t: ^testing.T) {
	f1 := Chord{30, 33, 37, 40}
	f2 := Chord{37, 40, 30, 33}
	invert_chord(f1, 2)
	testing.expectf(t, f1[0] == f2[0], "f1 inverted 2 times shoud be equal to f2")
	testing.expectf(t, f1[1] == f2[1], "f1 inverted 2 times shoud be equal to f2")
	testing.expectf(t, f1[2] == f2[2], "f1 inverted 2 times shoud be equal to f2")
	testing.expectf(t, f1[3] == f2[3], "f1 inverted 2 times shoud be equal to f2")
	testing.expectf(t, f1[3] == 33, "f1 inverted 2 times shoud be equal to f2")
}

@(test)
test_invert_chord2 :: proc(t: ^testing.T) {
	c1_inv2 := Chord{67, 60, 64}
	invert_chord(c1_inv2, 0)
	testing.expectf(t, c1_inv2[0] == 60, "c1_inv2 inverted 0 times shoud be sorted back to root position")
	testing.expectf(t, c1_inv2[1] == 64, "c1_inv2 inverted 0 times shoud be sorted back to root position")
	testing.expectf(t, c1_inv2[2] == 67, "c1_inv2 inverted 0 times shoud be sorted back to root position")
}


@(test)
test_inverted_chord_1 :: proc(t: ^testing.T) {
	c1 := Chord{30, 34, 37, 41, 44, 47, 51}
	c5 := Chord{47, 51, 30, 34, 37, 41, 44}
	testing.expectf(t, inversion(c1) == 0, "c1 is F# 1 Major13 in root position ")
	testing.expectf(t, inversion(c5) == 5, "c3 is F# 1 Major13 in fith inversion ")

	c1_inv5 := inverted_chord(c1, 5)
	defer delete(c1_inv5)

	testing.expectf(t, c1_inv5[0] == c5[0], "c1_inv5 should be the 5th inversion of c1 just like c5")
	testing.expectf(t, c1_inv5[1] == c5[1], "c1_inv5 should be the 5th inversion of c1 just like c5")
	testing.expectf(t, c1_inv5[2] == c5[2], "c1_inv5 should be the 5th inversion of c1 just like c5")
	testing.expectf(t, c1_inv5[3] == c5[3], "c1_inv5 should be the 5th inversion of c1 just like c5")
	testing.expectf(t, c1_inv5[4] == c5[4], "c1_inv5 should be the 5th inversion of c1 just like c5")
	testing.expectf(t, c1_inv5[5] == c5[5], "c1_inv5 should be the 5th inversion of c1 just like c5")
	testing.expectf(t, c1_inv5[6] == c5[6], "c1_inv5 should be the 5th inversion of c1 just like c5")
}
