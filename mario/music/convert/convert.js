const midiParser = require("midi-parser-js");
const fs = require("fs");

function noteToFreq(note) {
    return (2 ** ((note - 69) / 12)) * 440
}

const noteNoms = ["la", "la#", "si", "do", "do#", "ré", "ré#", "mi", "fa", "fa#", "sol", "sol#"];
function noteToNom(note) {
	const idx = (note - (69%noteNoms.length)) % noteNoms.length;
	const octave = Math.floor((note - (66%noteNoms.length)) / noteNoms.length);
	return noteNoms[idx] + " " + octave;
}

fs.readFile("../song.mid", "base64", function(err, data) {
	const midiArray = midiParser.parse(data);
	console.log(midiArray);

	const stream = fs.createWriteStream("../song.aaf", { })
	stream.write(Buffer.from("\x13AAF\x03"));

	// milliseconds per quarter-note
	let notes = [];
	let usedChannels = 0;
	let tempo = 500.000;
	let deltaUnit = tempo / midiArray.timeDivision;
	let midiClockScale = 4 / 4;
	let tempoMap = [];

	for (const trackId in midiArray.track) {
		//tempo = 500.000;
		//deltaUnit = tempo / midiArray.timeDivision;

		let time = 0;
		console.log("track #" + trackId);

		const track = midiArray.track[trackId].event;
		if (midiArray.formatType == 1 && trackId > 0) { // follow tempo from first track
			for (const possible of tempoMap) {
				if (time >= possible.time) {
					//tempo = possible.tempo;
					//deltaUnit = tempo / midiArray.timeDivision;
				}
			}
		}
		for (const id in track) {
			const event = track[id];
			if (event.type == 0x9) { // Note On
				const key = event.data[0];
				const velocity = event.data[1];
				if (velocity != 0) {
					let offId = parseInt(id) + 1;
					while (true) {
						if (!track[offId]) break;
						if (track[offId].type == 0x8 && track[offId].data[0] == key) { // corresponding note off
							break;
						} else if (track[offId].type == 0x9 && track[offId].data[0] == key) {
							if (track[offId].data[1] == 0) break; // note on with velocity = 0 is a release
						}
						offId++;
					}

					let delta = 0;
					let count = parseInt(id);
					while (count < offId) {
						count += 1;
						if (track[count]) delta += track[count].deltaTime;
					}
					let freeChannel = 0;
					for (const note of notes) {
						// Condition for this layout (A is checked note, B is current note):
						// <====A====>
						//   <====B====>
						const right = note.start <= time && note.start + note.duration > time;

						// Condition for this layout (can happen with multiple tracks):
						//   <====A====>
						// <====B====>
						const left = note.start + note.duration > time + delta*deltaUnit;

						// const collide = left | right;
						const collide = note.start + note.duration >= time && note.start < time + delta*deltaUnit;

						if (collide && note.channel === freeChannel) { // if note still playing
							freeChannel += 1;
						}
					}
					if (freeChannel+1 > usedChannels) usedChannels = freeChannel+1;
					notes.push({
						channel: freeChannel,
						start: Math.floor(time),
						duration: Math.floor(delta * deltaUnit),
						frequency: Math.floor(noteToFreq(key)),
						noteName: noteToNom(key),
						track: trackId
					});
				}
			} else if (event.type == 0xFF) { // meta event
				if (event.metaType == 81) { // Set Tempo
					if (midiArray.formatType == 1 && trackId > 0) {
						console.error("Tried to set tempo in track #" + trackId);
						return;
					}
					tempo = event.data / 1000;
					deltaUnit = tempo / midiArray.timeDivision;
					console.log(time + "ms: set tempo to " + ((1 / tempo) * 1000 * 60) + " bpm");
					console.log("set deltaUnit to " + deltaUnit);
					if (midiArray.formatType == 1) {
						tempoMap.push({ time: time, tempo: event.data / 1000 });
					}
				} else if (event.metaType == 88) { // Time Signature
					// TODO
					if (midiArray.formatType == 1 && trackId > 0) {
						console.error("Tried to set tempo in track #" + trackId);
						return;
					}
					console.warn("TODO: Time Signature");
					console.warn(event.data);
					/*const numerator = event.data[0];
					const denominator = 2 ** event.data[1];
					console.log(time + "ms: = " + numerator + "/" + denominator)
					deltaUnit = tempo / midiArray.timeDivision * (numerator / denominator);
					if (midiArray.formatType == 1) {
						tempoMap.push({ time: time, tempo: event.data / 1000 * (numerator / denominator) });
					}*/
				} else if (event.metaType == 89) { // Key Signature
					const key = event.data >> 8;
					const scale = event.data & 0xFF;
					console.log("Key " + key + ", scale = " + scale);
					console.warn("TODO: Key Signature");
					console.warn(event);
					//return;
				} else if (event.metaType == 33) {
					console.warn("TODO: 33 not in spec")
				} else if (event.metaType == 47) {
					console.log("End Of Track");
				} else {
					console.error("Unknown type: " + event.metaType);
					console.error(event);
					return;
				}
			}

			time += event.deltaTime * deltaUnit;
		}
	}

	notes.sort((a, b) => {
		return a.start - b.start;
	});

	for (const note of notes) {
		console.log(note.start + "ms: press " + note.frequency + " Hz = " + note.noteName + " for " + note.duration + " ms, channel "
			+ note.channel + " (track " + note.track + ")");
	}

	console.log("Using " + usedChannels + " channels in total.");

	let caps = Buffer.alloc(3);
	caps.writeUInt8(0b1111, 0); // all wave types
	caps.writeUInt8(0b11, 1); // adsr and volume
	caps.writeUInt8(usedChannels, 2);
	stream.write(caps);

	let channelDatas = [];
	for (let channelId = 0; channelId < usedChannels; channelId++) {
		let channelData = [];
		let time = 0;
		for (const note of notes) {
			if (note.channel == channelId) {
				if (note.start - time > 0) {
					let duration = note.start - time;
					while (duration > 0) { // to handle large pauses (> 65535ms)
						const incr = Math.min(65535, duration);
						duration -= incr;
						channelData.push({
							frequency: 0,
							duration: incr
						});
					}
				}
				channelData.push({
					frequency: note.frequency,
					duration: note.duration
				});
				time = note.start + note.duration;
			}
		}

		channelDatas[channelId] = channelData;
	}

	let id = 0;
	while (true) {
		let allEnded = true;
		for (const data of channelDatas) {
			const datom = data[id];
			if (datom) {
				allEnded = false;
			} else {
				let pause = Buffer.alloc(4);
				pause.writeUInt16LE(0, 0);
				pause.writeUInt16LE(100, 2);
				stream.write(pause);
				continue;
			}

			let note = Buffer.alloc(4);
			note.writeUInt16LE(datom.frequency, 0);
			note.writeUInt16LE(datom.duration, 2);
			stream.write(note);
		}
		if (allEnded) break;
		id++;
	}

	stream.close();
});
