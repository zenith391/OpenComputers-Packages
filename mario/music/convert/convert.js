const midiParser = require("midi-parser-js");
const fs = require("fs");

function noteToFreq(note) {
    return (2 ** ((note - 69) / 12)) * 440
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

	for (const trackId in midiArray.track) {
		let time = 0;
		console.log("track #" + trackId);

		const track = midiArray.track[trackId].event;
		for (const id in track) {
			const event = track[id];
			time += event.deltaTime * deltaUnit;
			if (event.type == 0x9) { // Note On
				const key = event.data[0];
				if (event.data[1] != 0) {
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
						delta += track[count].deltaTime;
					}
					let freeChannel = 0;
					for (const note of notes) {
						// Condition for this layout:
						// <====A====>
						//   <====B====>
						const right = note.start <= time && note.start + note.duration > time;

						// Condition for this layout (can happen with multiple tracks):
						//   <====A====>
						// <====B====>
						const left = note.start + note.duration > time + delta*deltaUnit;

						if ((left || right) && note.channel === freeChannel) { // if note still playing
							freeChannel += 1;
						}
					}
					if (freeChannel+1 > usedChannels) usedChannels = freeChannel+1;
					notes.push({
						channel: freeChannel,
						start: Math.floor(time),
						duration: Math.floor(delta * deltaUnit),
						frequency: Math.floor(noteToFreq(key)),
						track: trackId
					});
				}
			} else if (event.type == 0xFF) { // meta event
				if (event.metaType == 81) { // Set Tempo
					tempo = event.data / 1000;
					deltaUnit = tempo / midiArray.timeDivision
				}
			}
		}
	}

	notes.sort((a, b) => {
		return a.start - b.start;
	});

	for (const note of notes) {
		console.log(note.start + "ms: press " + note.frequency + " Hz for " + note.duration + " ms, channel " + note.channel + " (track " + note.track + ")");
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
