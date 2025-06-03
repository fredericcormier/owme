package owme

import "core:encoding/json"
import "core:fmt"
import "core:log"
import "core:math"
import "core:mem"
import "core:os"
import "core:slice"
import "core:strings"

/*TODO add the option to pass file path to init_from_json */

init_owme :: proc() {
	log.info("Using JSON data")
	_ = init_notes_from_json()
	_ = init_tunings_from_json()

}

cleanup_owme :: proc() {
	cleanup_notes()
	cleanup_tunings()
	log.info("owme cleaned up")
}


A440_FREQUENCY: f32 : 440
A440_MIDI_NOTE_NUMBER :: 69

NOTE_NAMES: [12]string = {"C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"}

CHROMATIC_SCALE_LENGTH: i8 : 12
DOUBLE_OCTAVE_SCALE_LENGTH: i8 : CHROMATIC_SCALE_LENGTH * 2


/* The Note type represents a musical note

- name is the note name - e.g. `C, D#, F#`
- octave is the octave number from `-1 to 9`
- mnn stands for `MIDI Note Number`
- frequency is the frequency of the note in Hz

the range of MIDI note numbers is 0 to 127

* from `{"C", -1, 0, 8.175798}`  to `	{"G", 9, 127, 12543.855}`

*/

Note :: struct {
	name:      string,
	octave:    i8,
	mnn:       i8,
	frequency: f32,
}

/*
A **NoteCollection** is a collection of midi note numbers, representing an actual chord or scale
and is the result of calculating the MIDI note numbers using a formula.

ie C#4 Mixolydian midi note numbers are `[61, 63, 65, 66, 68, 70, 71, 73]`
*/
NoteCollection :: distinct []i8

/*On occasion we need to know if a NoteCollection is a Chord*/
Chord :: distinct NoteCollection

/*On occasion we need to know if a NoteCollection is a Scale*/
Scale :: distinct NoteCollection


/*
 A **Formula** is a collection of interval starting at  0 (for
the root note )followed by intervals that form a chord or scale.

ie the formula for gypsyMinor is `[0, 2, 3, 6, 7, 8, 11, 12]`
*/
Formula :: distinct []i8


/*
container of scale Formulas
*/
@(private = "file")
g_scale_formulas: map[string]Formula

/*
container of chord Formulas
*/
@(private = "file")
g_chord_formulas: map[string]Formula


/*

Returns a Note struct and a boolean indicating success (or not)
from either a note name and octave, a midi note number, or a frequency


*usage:*

`	n := note(60)`

`	n := note(440.0)`

`	n := note("C", 4)`

*you may need to disambiguate the call(i8 or f32) with a type cast*

*/
note :: proc {
	_note_from_notename_and_octave,
	_note_from_midi_note_number,
	_note_from_frequency,
}

@(private = "file")
_note_from_notename_and_octave :: proc(n: string, o: i8) -> (note: Note, ok: bool) #optional_ok {
	if mnn, ok := _midi_note_number_from_notename_and_octave(n, o); ok {
		if freq, ok2 := _frequency_from_midi_note_number(mnn); ok2 {
			return Note{n, o, mnn, freq}, true
		}
	}
	return Note{}, false
}

@(private = "file")
_note_from_midi_note_number :: proc(mnn: i8) -> (note: Note, ok: bool) #optional_ok {
	if n, o, ok := _notename_and_octave_from_mnn(mnn); ok {
		if freq, ok2 := _frequency_from_midi_note_number(mnn); ok2 {
			return Note{n, o, mnn, freq}, true
		}
	}
	return Note{}, false
}

@(private = "file")
_note_from_frequency :: proc(freq: f32) -> (note: Note, ok: bool) #optional_ok {
	if n, o, ok := _notename_and_octave_from_frequency(freq); ok {
		if mnn, ok2 := _midi_note_number_from_notename_and_octave(n, o); ok2 {
			return Note{n, o, mnn, freq}, true
		}
	}
	return Note{}, false
}


/*

Returns a collection of notes and a boolean indicating success (or not)
from a collection of midi note numbers


A collection of notes is an array of Note structs representing a chord or a scale

*Allocates Using Provided Allocator, default allocator: context.allocator*

-The caller is responsible for freeing the returned array as well as the collection
that fed the proc
- Don't nest the call to scale/chords with the call to notes, as you 'll need to free the collection
- ie `DON'T DO:` `notes(scale("C", 4, .ionian)` as you will not be able to free the collection with the default allocator
allocator

*/
notes :: proc {
	_notes_from_chord,
	_notes_from_scale,
}

_notes_from_chord :: proc(c: Chord, allocator := context.allocator) -> ([]Note, bool) {
	return _notes_from_collection(cast(NoteCollection)c)
}

_notes_from_scale :: proc(s: Scale, allocator := context.allocator) -> ([]Note, bool) {
	return _notes_from_collection(cast(NoteCollection)s)
}

@(private = "file")
_notes_from_collection :: proc(collection: NoteCollection, allocator := context.allocator) -> ([]Note, bool) {
	notes := make([]Note, len(collection), allocator)
	for mnn, i in collection {
		if n, o, ok := _notename_and_octave_from_mnn(mnn); ok {
			if freq, ok2 := _frequency_from_midi_note_number(mnn); ok2 {
				notes[i] = {n, o, mnn, freq}
			}
		}
	}
	return notes, true
}


/*

Returns the note name and octave and a boolean indicating success (or not)
from either a midi note number or a frequency


usage:

*you may need to disambiguate the call(i8 or f32) with a type cast*

`	n, o, ok := notename_and_octave(i8(60))`

`	n, o, ok := notename_and_octave(440.0)`

or
`	n, o, ok := notename_and_octave(f32(440))`


*/
notename_and_octave :: proc {
	_notename_and_octave_from_mnn,
	_notename_and_octave_from_frequency,
}

@(private = "file")
_notename_and_octave_from_mnn :: proc(mnn: i8) -> (n: string, o: i8, ok: bool) {
	if mnn >= 0 && mnn <= 127 {
		n := NOTE_NAMES[mnn % 12]
		o := mnn / 12 - 1
		return n, o, true
	} else {
		return "", 0, false
	}
}

// this returns the name and octave of the "closest" note for the frequency
@(private = "file")
_notename_and_octave_from_frequency :: proc(freq: f32) -> (n: string, o: i8, ok: bool) {
	if freq > 0 {
		mnn := cast(i8)(math.round_f32(12 * math.log2_f32(freq / A440_FREQUENCY) + A440_MIDI_NOTE_NUMBER))
		return _notename_and_octave_from_mnn(mnn)
	} else {
		return "", 0, false
	}
}

/*

Returns a midi note number and an optional boolean indicating success (or not)
from either a note name and octave or a frequency


usage:

`	 mnn, ok := midi_note_number("C", 4)`

`	 mnn, ok := midi_note_number(440.0)`

*/
midi_note_number :: proc {
	_midi_note_number_from_notename_and_octave,
	_midi_note_number_from_frequency,
}

@(private = "file")
_midi_note_number_from_notename_and_octave :: proc(n: string, o: i8) -> (mnn: i8, ok: bool) #optional_ok {
	n := strings.to_upper(n)
	defer (delete(n))
	for note_name, i in NOTE_NAMES {
		if note_name == n {
			mnn := i8(i) + 12 * (o + 1)
			return mnn, true
		}
	}
	return 0, false
}

@(private = "file")
_midi_note_number_from_frequency :: proc(freq: f32) -> (mnn: i8, ok: bool) #optional_ok {
	if n, o, ok := _notename_and_octave_from_frequency(freq); ok {
		return _midi_note_number_from_notename_and_octave(n, o)
	} else {
		return 0, false
	}
}
/*

Returns a frequency value and an optional boolean indicating success (or not)
from either a midi note number or a note name and octave

usage:

`	freq, ok := frequency(60)`

`	freq, ok := frequency("C", 4)`

*/
frequency :: proc {
	_frequency_from_midi_note_number,
	_frequency_from_notename_and_octave,
}

@(private = "file")
_frequency_from_midi_note_number :: proc(mnn: i8) -> (frequency: f32, ok: bool) #optional_ok {
	if mnn >= 0 && mnn <= 127 {
		frequency = math.pow_f32(2, f32(mnn - A440_MIDI_NOTE_NUMBER) / f32(12)) * A440_FREQUENCY
		return frequency, true
	} else {
		return
	}
}

@(private = "file")
_frequency_from_notename_and_octave :: proc(n: string, o: i8) -> (frequency: f32, ok: bool) #optional_ok {
	if mnn, ok := _midi_note_number_from_notename_and_octave(n, o); ok {
		return _frequency_from_midi_note_number(mnn)
	} else {
		return
	}
}
/*

Returns a Chord collection(array) of MIDI Note numbers representing a chord and a boolean indicating success (or not),
based on a note name, octave, and chord name


*Allocates Using Provided Allocator, default allocator: context.allocator*

usage:

`	 chord, ok := chord("C", 4, .major)`
*/
chord :: proc {
	_chord_from_notename_octave_and_chordname,
}

@(private = "file")
_chord_from_notename_octave_and_chordname :: proc(n: string, o: i8, c: string, allocator := context.allocator) -> (chord: Chord, ok: bool) #optional_ok {
	collection, success := _collection_from_notename_octave_and_formula(n, o, g_chord_formulas[c], allocator);if !success {
		return nil, false
	}
	chord = cast(Chord)collection
	return chord, true
}


/*

returns the inversion number of a potentially inverted chord

- 0 is root position
- 1 is first inversion
- 2 second inversion
- etc

*/
inversion :: proc(chord: Chord) -> i8 {

	lowest_note := chord[0]
	chord_copy := slice.clone(cast([]i8)chord)

	//sorts a copy of the chord in ascending order
	slice.sort(chord_copy)

	//returns the index in the sorted array of the lowest note of the chord
	for n, i in chord_copy {
		if lowest_note == n {
			delete(chord_copy)
			return i8(i)
		}
	}
	delete(chord_copy)
	return 0
}


/*

Invert the chord in place.

No copy, no memory allocation

*/
invert_chord :: proc(chord: Chord, inversion: i8) {
	slice.sort(chord)
	slice.rotate_left(chord, cast(int)inversion)
}


/*

Returns a new chord that is the inversion of the chord passed in as argument

*Allocates Using Provided Allocator, default allocator: context.allocator*

usage:

`	 inv_chord:= inverted_chord(c1, 2)`
*/
inverted_chord :: proc(chord: Chord, inversion: i8, allocator := context.allocator) -> Chord {
	chord_copy := slice.clone(cast([]i8)chord)
	slice.sort(chord_copy)
	slice.rotate_left(chord_copy, cast(int)inversion)
	return cast(Chord)chord_copy

}
/*

Returns a Scale collection(array) of MIDI Note numbers representing a scale and a boolean indicating success (or not),
based on a note name, octave, and scale name


*Allocates Using Provided Allocator, default allocator: context.allocator*

usage:

`	scale, ok := scale("C", 4, .ionian)`

*/
scale :: proc {
	_scale_from_notename_octave_and_scalename,
}

@(private = "file")
_scale_from_notename_octave_and_scalename :: proc(n: string, o: i8, s: string, allocator := context.allocator) -> (scale: Scale, ok: bool) #optional_ok {
	collection, success := _collection_from_notename_octave_and_formula(n, o, g_scale_formulas[s], allocator);if !success {
		return nil, false
	}
	scale = cast(Scale)collection
	return scale, true
}


@(private = "file")
_collection_from_notename_octave_and_formula :: proc(n: string, o: i8, f: Formula, allocator := context.allocator) -> (c: NoteCollection, ok: bool) #optional_ok {
	mnn: i8
	mnn, ok = _midi_note_number_from_notename_and_octave(n, o);if !ok {
		return nil, false
	}
	collection, err := make(NoteCollection, len(f), allocator);if err != .None {
		return nil, false
	} else {
		for interval, i in f {
			collection[i] = mnn + i8(interval)
		}
		return collection, true
	}

}

expand_collection :: proc(note_collection: NoteCollection, upward: bool, downward: bool, allocator := context.allocator) -> (NoteCollection, mem.Allocator_Error) #optional_allocator_error {
	expanded_collection: [dynamic]i8
	append_error: mem.Allocator_Error

	if upward {
		for n in note_collection {
			for i in 1 ..= 10 {
				nx := n * i8(i)
				if nx < 127 {
					_, append_error = append(&expanded_collection, nx)
				}
			}
		}
	};if downward {
	};if !upward && !downward {
		log.warn("expand_collection: at least one of upward or downward must be true")
		return nil, mem.Allocator_Error.Invalid_Argument
	}
	return cast(NoteCollection)expanded_collection[:], append_error
}

/*

INTERVALS

*/
IntervalNames :: enum {
	unused_interval = -1,
	unison = 0,
	minor_2nd,
	major_2nd,
	minor_3rd,
	major_3rd,
	perfect_4th,
	diminished_5th,
	perfect_5th,
	minor_6th,
	major_6th,
	minor_7th,
	major_7th,
	octave,
	minor_9th,
	major_9th,
	minor_10th,
	major_10th,
	perfect_11th,
	diminished_12th,
	perfect_12th,
	minor_13th,
	major_13th,
	minor_14th,
	major_14th,
	double_octave,
}

Interval :: struct {
	name_1: string,
	name_2: string,
}

IntervalNameType :: enum {
	minorMajorName,
	augmentedDiminishedName,
}


@(private = "file")
g_interval_names: [25][IntervalNameType]string = {
	{.minorMajorName = "Unison", .augmentedDiminishedName = "Diminished 2nd"},
	{.minorMajorName = "Minor 2nd", .augmentedDiminishedName = "Augmented Unison"},
	{.minorMajorName = "Major 2nd", .augmentedDiminishedName = "Diminished 3rd"},
	{.minorMajorName = "Minor 3rd", .augmentedDiminishedName = "Augmented 2nd"},
	{.minorMajorName = "Major 3rd", .augmentedDiminishedName = "Diminished 4th"},
	{.minorMajorName = "Perfect 4th", .augmentedDiminishedName = "Augmented 3rd"},
	{.minorMajorName = "Diminished 5th", .augmentedDiminishedName = "Augmented 4th"},
	{.minorMajorName = "Perfect 5th", .augmentedDiminishedName = "Diminished 6th"},
	{.minorMajorName = "Minor 6th", .augmentedDiminishedName = "Augmented 5th"},
	{.minorMajorName = "Major 6th", .augmentedDiminishedName = "Diminished 7th"},
	{.minorMajorName = "Minor 7th", .augmentedDiminishedName = "Augmented 6th"},
	{.minorMajorName = "Major 7th", .augmentedDiminishedName = "Diminished Octave"},
	{.minorMajorName = "Octave", .augmentedDiminishedName = "Augmented 7th"},
	{.minorMajorName = "Minor 9th", .augmentedDiminishedName = "Augmented Octave"},
	{.minorMajorName = "Major 9th", .augmentedDiminishedName = "Diminished 10th"},
	{.minorMajorName = "Minor 10th", .augmentedDiminishedName = "Augmented 9th"},
	{.minorMajorName = "Major 10th", .augmentedDiminishedName = "Diminished 11th"},
	{.minorMajorName = "Perfect 11th", .augmentedDiminishedName = "Aujgmented 10th"},
	{.minorMajorName = "Diminished 12th", .augmentedDiminishedName = "Augmented 11th"},
	{.minorMajorName = "Perfect 12th", .augmentedDiminishedName = "Diminished 13th"},
	{.minorMajorName = "Minor 13th", .augmentedDiminishedName = "Augmented 12th"},
	{.minorMajorName = "Major 13th", .augmentedDiminishedName = "Diminished 14th"},
	{.minorMajorName = "Minor 14th", .augmentedDiminishedName = "Augmented 13th"},
	{.minorMajorName = "Major 14th", .augmentedDiminishedName = "Diminished 15th"},
	{.minorMajorName = "Double Octave", .augmentedDiminishedName = "Augmented 14th"},
}


/*

Returns the numbers of semitones and an optional boolean indicating success (or not)
from either 2 notes or 2 MIDI Note Numbers (mnn)


usage:


	n1 := Note {mnn = 66}
	n2 := Note {mnn = 70}

	intvl, ok := interval_between(n1, n2)
	intvl, ok := interval_between(66, 73)
`

*/

interval_between :: proc {
	_interval_between_notes,
	_interval_between_mnn,
}

@(private = "file")
_interval_between_notes :: proc(n1: Note, n2: Note) -> (interval: i8, ok: bool) #optional_ok {
	return _interval_between_mnn(n1.mnn, n2.mnn)
}

@(private = "file")
_interval_between_mnn :: proc(n1: i8, n2: i8) -> (interval: i8, ok: bool) #optional_ok {
	if (n1 >= 0 && n1 <= 127) && (n2 >= 0 && n2 <= 127) {
		return n2 - n1, true
	} else {
		log.warn("Invalid note numbers")
	}
	return 0, false
}

/*

Returns the name of the interval, the octave of the interval, and a boolean for success (or not)

Interval names are defined for the first 24 semitones.
- Up to 24, interval_name returns "O" octave and the **interval name** corresponding to the given interval integer
ie:

`o, s, _ := interval_name(17)` *=> O octaves, Perfect 11th*

- Past 24 (or Double octave) the proc returns the number of octaves and the **interval name**
ie:

`o, s, _ := interval_name(27)` *=> 2 octaves and a Major Third*

- For negative intervals or interval inversions, the proc returns the number of (negative)octaves and the **12 first interval names**
then wraps around the names
ie:

`o, s, _ := interval_name(-29)` *=> -3 octaves, Perfect 5th*

`o, s, _ := interval_name(-14)` *=> -2 octaves, Minor Seventh*

By default, interval_name returns the Major Minor type of the name (if that exists)
Pass **.augmentedDiminishedName** as name_type to get the alternative name


*/
interval_name :: proc(interval: i8, name_type: IntervalNameType = .minorMajorName) -> (octaves: i8, name: string, ok: bool) {
	switch interval {

	case 0 ..= 24:
		return 0, g_interval_names[interval][name_type], true

	case 25 ..= 127:
		octaves := interval / CHROMATIC_SCALE_LENGTH
		remainder := interval %% DOUBLE_OCTAVE_SCALE_LENGTH
		return octaves, g_interval_names[remainder][name_type], true

	case -127 ..= -1:
		octaves := -(abs(interval) / CHROMATIC_SCALE_LENGTH) - 1
		remainder := abs(interval) %% CHROMATIC_SCALE_LENGTH
		inverted_interval := 12 - remainder
		return octaves, g_interval_names[inverted_interval][name_type], true

	case:
		return 0, "Not a valid interval", false
	}
}


mnn_at_interval :: proc(note_ref: i8, name: IntervalNames) -> i8 {
	return note_ref + cast(i8)name
}


//----------------------------------------------------------------------------
//
//		Helpers

round_to :: proc(x: f32, places: i8) -> f32 {
	decimals := math.pow_f32(10, f32(places))
	return math.round(x * decimals) / decimals
}


note_to_string :: proc(n: Note) -> string {
	return fmt.tprintf("%v %i", n.name, n.octave)
}


/*

Init the whole shebang from JSON

default path for json files is "data/"

*/
init_notes_from_json :: proc(scale_path := "data/scales.json", chord_path := "data/chords.json") -> bool {
	ok_scales := _load_formulas_from_json(&g_scale_formulas, scale_path)
	if ok_scales {
		log.info("Scales loaded from JSON")
		//keep going
	} else {
		log.warn("Failed to load scales from JSON")
		return false
	}

	ok_chords := _load_formulas_from_json(&g_chord_formulas, chord_path)
	if ok_chords {
		log.info("Chords loaded from JSON")
		return true
	} else {
		log.warn("Failed to load chords from JSON")
		return false
	}
}


cleanup_notes :: proc() {
	for s1, collection in g_scale_formulas {
		delete(s1)
		delete(collection)
	}
	delete(g_scale_formulas)
	clear(&g_scale_formulas)
	g_scale_formulas = {}

	for s2, collection in g_chord_formulas {
		delete(s2)
		delete(collection)
	}
	delete(g_chord_formulas)
	clear(&g_chord_formulas)
	g_chord_formulas = {}
}


@(private = "file")
_load_formulas_from_json :: proc(formula: ^map[string]Formula, path: string) -> (ok: bool) {
	data, rerr := os.read_entire_file_or_err(path)
	if rerr != nil {
		log.warnf("Unable to read file: %v", rerr)
		delete(data)
		return false
	}
	err := json.unmarshal(data, formula)
	if err != nil {
		log.warnf("Unable to unmarshal JSON: %v", err)
		delete(data)
		return false
	}
	delete(data)
	return true
}


export_formulas_to_json :: proc(formula: [$T][]i8, path: string) -> (ok: bool) {
	if len(formula) == 0 {
		log.warn("Cannot export collection: collection is empty")
		return false
	}
	if path == "" {
		log.warn("Cannot export collection: path is empty")
		return false
	}

	json_data, err := json.marshal(formula, {pretty = true, use_enum_names = true})
	if err != nil {
		log.warnf("Unable to marshal JSON: %v", err)
		return false
	}
	werr := os.write_entire_file_or_err(path, json_data)
	if werr != nil {
		log.warnf("Unable to write JSON to file: %v", werr)
		return false
	}
	return true
}


print_scale_formulas :: proc() {
	fmt.printfln("scales: %v", g_scale_formulas)
}

print_chord_formulas :: proc() {
	fmt.printfln("chords: %v", g_chord_formulas)
}


String_Gauge :: enum {
	stringGaugeThin = 0,
	stringGaugeMedium,
	stringGaugeThick,
	stringGaugeBig,
}


Tuning :: struct {
	name:    string,
	strings: [dynamic]struct {
		open_note_name:   string,
		open_note_octave: i8,
		number_of_frets:  i8,
		string_gauge:     String_Gauge,
	},
}


@(private = "file")
g_tunings: map[string]Tuning


init_tunings_from_json :: proc(path := "data/tunings.json") -> (ok: bool) {
	if g_tunings != nil {
		log.info("Tunings already initialized, erasing!")
		cleanup_tunings()
	}
	log.info("Initializing tunings")

	data, rerr := os.read_entire_file_or_err(path)
	if rerr != nil {
		log.warnf("Unable to read file: %v", rerr)
		return false
	}
	defer delete(data)

	err := json.unmarshal(data, &g_tunings)
	if err != nil {
		log.warnf("Unable to unmarshal JSON: %v", err)
		return false
	}
	return true
}


cleanup_tunings :: proc() {
	log.info("Cleaning up tunings")
	for k, tuning in g_tunings {
		delete(tuning.name)
		delete(k)
		for &s in tuning.strings {
			delete(s.open_note_name)
		}
		delete(tuning.strings)
	}
	delete(g_tunings)
	clear(&g_tunings)
	g_tunings = {}
}


/*
Accessor to retreive a tuning since the global g_tunings map is private to this file
*/

tuning :: proc(name := "") -> (tuning: Tuning) {
	if nil == g_tunings {
		log.warn("Tunings not initialized")
		return Tuning{}
	}
	return g_tunings[name]
}


export_tunings_as_json :: proc(path := "data/tunings.json") -> (ok: bool) {
	if nil == g_tunings {
		log.warn("No tunings to convert to JSON")
		return false
	}
	json_data, err := json.marshal(g_tunings, {pretty = true, use_enum_names = true})
	if err != nil {
		log.warnf("Unable to marshal JSON: %v", err)
		return false
	}
	werr := os.write_entire_file_or_err(path, json_data)
	if werr != nil {
		log.warnf("Unable to write file: %v", werr)
		return false
	}
	return true
}


/*
- Returns a slice containing the names of all tunings.
-  Must be deleted after use.
 - Note the t_names[:]  "`:`" that turns the dynamic array into a slice.

*/

tuning_names :: proc(allocator := context.allocator) -> (names: []string) {
	t_names: [dynamic]string
	for _, t in g_tunings {
		append_elem(&t_names, t.name)
	}
	return t_names[:]
}


/*s
open_string == no_finger
*/
FingerNames :: enum {
	open_string = 0,
	indexFinger,
	middleFinger,
	ringFinger,
	pinky,
}

FrettedNote :: struct {
	using note:    Note,
	interval:      IntervalNames,
	string_number: i8,
	fret:          i8,
	finger:        FingerNames,
}

/*

Fingering is an array of arrays of i8 (MIDI Note numbers).
- Each array represents a string on the instrument.
- Each element in the "string" array represents a fret on the string.
- The value of the element is the MIDI note number of the note at that fret. If the note is not in the collection, the value is -1.
- ie C3 ionian for standard guitar tuning:

- String 1 --> [-1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1]
- String 2 --> [59, 60, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1]
- String 3 --> [55, -1, 57, -1, 59, 60, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1]
- String 4 --> [50, -1, 52, 53, -1, 55, -1, 57, -1, 59, 60, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1]
- String 5 --> [-1, -1, -1, 48, -1, 50, -1, 52, 53, -1, 55, -1, 57, -1, 59, 60, -1, -1, -1, -1, -1, -1, -1, -1]
- String 6 --> [-1, -1, -1, -1, -1, -1, -1, -1, 48, -1, 50, -1, 52, 53, -1, 55, -1, 57, -1, 59, 60, -1, -1, -1]

*/
Fingering :: [dynamic][dynamic]FrettedNote

ShowFingering :: enum {
	ShowDots,
	ShowMnn,
	ShowInterval,
	ShowStringNumber,
	ShowFret,
	ShowFinger,
}

print_ascii_fingering :: proc(f: Fingering, show: ShowFingering) {
	for string, s in f {
		fmt.printf("String %d |", s + 1)
		for note in string {
			switch show {
			case .ShowDots:
				_ = note.mnn == -1 ? fmt.printf(" - | ") : fmt.printf(" ◉ | ")

			case .ShowMnn:
				fmt.printf(" - %2d", note.mnn)

			case .ShowInterval:
				fmt.printf(" - %2d", note.interval)

			case .ShowStringNumber:
				fmt.printf(" - %2d", note.string_number)

			case .ShowFret:
				fmt.printf(" - %2d", note.fret)

			case .ShowFinger:
				fmt.printf(" - %2d", note.finger)

			}
		}
		fmt.printfln("")
	}
}


fingering_for_scale :: proc(tuning: Tuning, scale_collection: Scale, allocator := context.allocator) -> (Fingering, mem.Allocator_Error) #optional_allocator_error {

	result, make_error := make(Fingering, allocator);if make_error == .None {
		resize(&result, len(tuning.strings))
	} else {
		return nil, make_error
	}

	// For each string in the tuning
	for s, string_index in tuning.strings {
		// Initialize array for this string
		result[string_index] = make([dynamic]FrettedNote, allocator)
		// Get MIDI note number for the open string
		open_mnn := midi_note_number(s.open_note_name, s.open_note_octave)
		// For each fret up to the number of frets on this string
		for f in 0 ..< s.number_of_frets {
			// Calculate the note at this fret (open note + fret number)
			fret_note := open_mnn + i8(f)
			// Check if this note is in our collection
			match := false
			for note, i in scale_collection {
				if note == fret_note {
					match = true

					found_fretted_note := FrettedNote {
						mnn           = fret_note,
						interval      = IntervalNames(i),
						string_number = i8(string_index) + 1,
						fret          = f,
					}

					append(&result[string_index], found_fretted_note)
					break
				}
			}

			if !match {
				not_found_fretted_note := FrettedNote {
					mnn           = -1,
					interval      = .unused_interval,
					string_number = -1,
					fret          = -1,
				}
				_, append_err := append(&result[string_index], not_found_fretted_note);if append_err != .None {
					return nil, append_err
				}
			}
		}
	}
	return result, .None
}

cleanup_fingering :: proc(f: Fingering) {
	for s, i in f {
		delete(s)
	}
	delete(f)
}
