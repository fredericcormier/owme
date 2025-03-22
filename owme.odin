package owme

import "core:encoding/json"
import "core:fmt"
import "core:log"
import "core:math"
import "core:os"
import "core:strings"

init_WME :: proc() {
	log.info("Using JSON data")
	_ = init_notes_from_json()
	_ = init_tunings_from_json()

}

cleanup_WME :: proc() {
	cleanup_notes()
	cleanup_tunings()
	log.info("WME cleaned up")
}


A440_FREQUENCY: f32 : 440
A440_MIDI_NOTE_NUMBER :: 69

NOTE_NAMES: [12]string = {"C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"}

/* The Note type represents a musical note

- name is the note name - e.g. `C, D#, F#`
- octave is the octave number from `-1 to 9`
- mnn stands for `MIDI Note Number`
- frequency is the frequency of the note in Hz

the range of MIDI note numbers is 0 to 127

* from `{"C", -1, 0@, 8.175798}`  to `	{"G", 9, 127, 12543.855}`

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


/*
 A **Formula** is a collection of interval starting at  0 (for
the root note )followed by intervals that form a chord or scale.

ie the formula for gypsyMinor is `[0, 2, 3, 6, 7, 8, 11, 12]`
*/
Formula :: distinct []i8


/*
container scale of Formulas
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
	note_from_notename_and_octave,
	note_from_midi_note_number,
	note_from_frequency,
}

@(private = "file")
note_from_notename_and_octave :: proc(n: string, o: i8) -> (note: Note, ok: bool) #optional_ok {
	if mnn, ok := midi_note_number_from_notename_and_octave(n, o); ok {
		if freq, ok2 := frequency_from_midi_note_number(mnn); ok2 {
			return Note{n, o, mnn, freq}, true
		}
	}
	return Note{}, false
}

@(private = "file")
note_from_midi_note_number :: proc(mnn: i8) -> (note: Note, ok: bool) #optional_ok {
	if n, o, ok := notename_and_octave_from_mnn(mnn); ok {
		if freq, ok2 := frequency_from_midi_note_number(mnn); ok2 {
			return Note{n, o, mnn, freq}, true
		}
	}
	return Note{}, false
}

@(private = "file")
note_from_frequency :: proc(freq: f32) -> (note: Note, ok: bool) #optional_ok {
	if n, o, ok := notename_and_octave_from_frequency(freq); ok {
		if mnn, ok2 := midi_note_number_from_notename_and_octave(n, o); ok2 {
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
	notes_from_collection,
}

@(private = "file")
notes_from_collection :: proc(collection: NoteCollection, allocator := context.allocator) -> ([]Note, bool) {
	notes := make([]Note, len(collection), allocator)
	for mnn, i in collection {
		if n, o, ok := notename_and_octave_from_mnn(mnn); ok {
			if freq, ok2 := frequency_from_midi_note_number(mnn); ok2 {
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
	notename_and_octave_from_mnn,
	notename_and_octave_from_frequency,
}

@(private = "file")
notename_and_octave_from_mnn :: proc(mnn: i8) -> (n: string, o: i8, ok: bool) {
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
notename_and_octave_from_frequency :: proc(freq: f32) -> (n: string, o: i8, ok: bool) {
	if freq > 0 {
		mnn := cast(i8)(math.round_f32(12 * math.log2_f32(freq / A440_FREQUENCY) + A440_MIDI_NOTE_NUMBER))
		return notename_and_octave_from_mnn(mnn)
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
	midi_note_number_from_notename_and_octave,
	midi_note_number_from_frequency,
}

@(private = "file")
midi_note_number_from_notename_and_octave :: proc(n: string, o: i8) -> (mnn: i8, ok: bool) #optional_ok {
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
midi_note_number_from_frequency :: proc(freq: f32) -> (mnn: i8, ok: bool) #optional_ok {
	if n, o, ok := notename_and_octave_from_frequency(freq); ok {
		return midi_note_number_from_notename_and_octave(n, o)
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
	frequency_from_midi_note_number,
	frequency_from_notename_and_octave,
}

@(private = "file")
frequency_from_midi_note_number :: proc(mnn: i8) -> (frequency: f32, ok: bool) #optional_ok {
	if mnn >= 0 && mnn <= 127 {
		frequency = math.pow_f32(2, f32(mnn - A440_MIDI_NOTE_NUMBER) / f32(12)) * A440_FREQUENCY
		return frequency, true
	} else {
		return
	}
}

@(private = "file")
frequency_from_notename_and_octave :: proc(n: string, o: i8) -> (frequency: f32, ok: bool) #optional_ok {
	if mnn, ok := midi_note_number_from_notename_and_octave(n, o); ok {
		return frequency_from_midi_note_number(mnn)
	} else {
		return
	}
}
/*

Returns a collection(array) of MIDI Note numbers representing a chord and a boolean indicating success (or not),
based on a note name, octave, and chord name


*Allocates Using Provided Allocator, default allocator: context.allocator*

usage:

`	 chord, ok := chord("C", 4, .major)`
*/
chord :: proc {
	chord_from_notename_octave_and_chordname,
}

@(private = "file")
chord_from_notename_octave_and_chordname :: proc(
	n: string,
	o: i8,
	c: string,
	allocator := context.allocator,
) -> (
	chord: NoteCollection,
	ok: bool,
) #optional_ok {
	chord, ok = collection_from_notename_octave_and_formula(n, o, g_chord_formulas[c], allocator);if !ok {
		return nil, false
	}
	return chord, true
}

/*

Returns a collection(array) of MIDI Note numbers representing a scale and a boolean indicating success (or not),
based on a note name, octave, and scale name


*Allocates Using Provided Allocator, default allocator: context.allocator*

usage:

`	scale, ok := scale("C", 4, .ionian)`

*/
scale :: proc {
	scale_from_notename_octave_and_scalename,
}

@(private = "file")
scale_from_notename_octave_and_scalename :: proc(
	n: string,
	o: i8,
	s: string,
	allocator := context.allocator,
) -> (
	scale: NoteCollection,
	ok: bool,
) #optional_ok {
	scale, ok = collection_from_notename_octave_and_formula(n, o, g_scale_formulas[s], allocator);if !ok {
		return nil, false
	}
	return scale, true
}


@(private = "file")
collection_from_notename_octave_and_formula :: proc(
	n: string,
	o: i8,
	f: Formula,
	allocator := context.allocator,
) -> (
	c: NoteCollection,
	ok: bool,
) #optional_ok {
	mnn: i8
	mnn, ok = midi_note_number_from_notename_and_octave(n, o);if !ok {
		return nil, false
	}
	chord, err := make(NoteCollection, len(f), allocator);if err != .None {
		return nil, false
	} else {
		for interval, i in f {
			chord[i] = mnn + i8(interval)
		}
		return chord, true
	}

}

//-----------------------------------------------------------------------------
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
	ok_scales := load_formulas_from_json(&g_scale_formulas, scale_path)
	if ok_scales {
		log.info("Scales loaded from JSON")
		//keep going
	} else {
		log.warn("Failed to load scales from JSON")
		return false
	}

	ok_chords := load_formulas_from_json(&g_chord_formulas, chord_path)
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
load_formulas_from_json :: proc(formula: ^map[string]Formula, path: string) -> (ok: bool) {
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
Fingering :: [dynamic][dynamic]i8

print_ascii_fingering :: proc(f: Fingering) {
	for n, i in f {
		fmt.printfln("String %d --> %v", i + 1, n)
	}
}


fingering :: proc(tuning: Tuning, collection: NoteCollection, allocator := context.allocator) -> Fingering {

	result := make(Fingering, allocator)
	resize(&result, len(tuning.strings))

	// For each string in the tuning
	for s, i in tuning.strings {
		// Initialize array for this string
		result[i] = make([dynamic]i8, allocator)
		// Get MIDI note number for the open string
		open_mnn := midi_note_number(s.open_note_name, s.open_note_octave)
		// For each fret up to the number of frets on this string
		for f in 0 ..< s.number_of_frets {
			// Calculate the note at this fret (open note + fret number)
			fret_note := open_mnn + i8(f)
			// Check if this note is in our collection
			found := false
			for note in collection {
				if note == fret_note {
					found = true
					append(&result[i], fret_note)
					break
				}
			}
			// return -1 because 0 is a valid note number
			if !found {
				append(&result[i], -1)
			}
		}
	}
	return result
}


cleanup_fingering :: proc(f: Fingering) {
	for s, i in f {
		delete(s)
	}
	delete(f)
}
