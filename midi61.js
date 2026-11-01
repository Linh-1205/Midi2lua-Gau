/**
 * midi61.js — MIDI → AutoPiano Lua sheet converter
 * Maps pitches to Virtual Piano 61-key QWERTY layout.
 * Output: keypress("...", x, bpm) / rest(beats, bpm) / finishedSong()
 */

(function (global) {
  "use strict";

  // Virtual Piano 61-key style mapping (approx C2–C7)
  // White + black keys via shift symbols
  // Layout rows: 1-0, q-p, a-l, z-m with shifts for sharps
  const NOTE_TO_KEY = {
    // Octave 1 (low)
    36: "1", 37: "!", 38: "2", 39: "@", 40: "3", 41: "4", 42: "$", 43: "5", 44: "%", 45: "6", 46: "^", 47: "7",
    // Octave 2
    48: "8", 49: "*", 50: "9", 51: "(", 52: "0", 53: "q", 54: "Q", 55: "w", 56: "W", 57: "e", 58: "E", 59: "r",
    // Octave 3
    60: "t", 61: "T", 62: "y", 63: "Y", 64: "u", 65: "i", 66: "I", 67: "o", 68: "O", 69: "p", 70: "P", 71: "a",
    // Octave 4
    72: "s", 73: "S", 74: "d", 75: "D", 76: "f", 77: "g", 78: "G", 79: "h", 80: "H", 81: "j", 82: "J", 83: "k",
    // Octave 5
    84: "l", 85: "L", 86: "z", 87: "Z", 88: "x", 89: "c", 90: "C", 91: "v", 92: "V", 93: "b", 94: "B", 95: "n",
    // Octave 6
    96: "m",
  };

  // Clamp / nearest fallback
  function pitchToKey(midiNote) {
    if (NOTE_TO_KEY[midiNote]) return NOTE_TO_KEY[midiNote];
    // nearest in range
    let best = 60;
    let bestDist = 999;
    for (const n of Object.keys(NOTE_TO_KEY)) {
      const d = Math.abs(Number(n) - midiNote);
      if (d < bestDist) {
        bestDist = d;
        best = Number(n);
      }
    }
    return NOTE_TO_KEY[best] || "t";
  }

  /**
   * Parse standard MIDI file (ArrayBuffer) → array of { time, type, note, velocity }
   * time in ticks
   */
  function parseMidi(buffer) {
    const view = new DataView(buffer);
    let offset = 0;

    function readStr(n) {
      let s = "";
      for (let i = 0; i < n; i++) s += String.fromCharCode(view.getUint8(offset++));
      return s;
    }
    function readU32() {
      const v = view.getUint32(offset);
      offset += 4;
      return v;
    }
    function readU16() {
      const v = view.getUint16(offset);
      offset += 2;
      return v;
    }
    function readU8() {
      return view.getUint8(offset++);
    }
    function readVarLen() {
      let v = 0;
      while (true) {
        const b = readU8();
        v = (v << 7) | (b & 0x7f);
        if ((b & 0x80) === 0) break;
      }
      return v;
    }

    if (readStr(4) !== "MThd") throw new Error("Not a MIDI file (missing MThd)");
    const headerLen = readU32();
    const format = readU16();
    const nTracks = readU16();
    const division = readU16(); // ticks per quarter if high bit clear
    offset += headerLen - 6; // skip rest of header if any

    const ticksPerQuarter = division & 0x8000 ? 480 : division;
    const events = [];

    for (let t = 0; t < nTracks; t++) {
      if (offset + 8 > view.byteLength) break;
      if (readStr(4) !== "MTrk") {
        // try recover
        offset -= 3;
        continue;
      }
      const trackLen = readU32();
      const trackEnd = offset + trackLen;
      let tick = 0;
      let runningStatus = 0;

      while (offset < trackEnd && offset < view.byteLength) {
        const delta = readVarLen();
        tick += delta;
        let status = view.getUint8(offset);
        if (status < 0x80) {
          status = runningStatus;
        } else {
          offset++;
          runningStatus = status;
        }
        const type = status & 0xf0;
        const channel = status & 0x0f;

        if (type === 0x90 || type === 0x80) {
          const note = readU8();
          const vel = readU8();
          const isOn = type === 0x90 && vel > 0;
          events.push({
            tick,
            type: isOn ? "on" : "off",
            note,
            velocity: vel,
            channel,
          });
        } else if (type === 0xa0 || type === 0xb0 || type === 0xe0) {
          offset += 2;
        } else if (type === 0xc0 || type === 0xd0) {
          offset += 1;
        } else if (status === 0xff) {
          const meta = readU8();
          const len = readVarLen();
          offset += len;
        } else if (status === 0xf0 || status === 0xf7) {
          const len = readVarLen();
          offset += len;
        } else {
          // unknown – skip 1
          break;
        }
      }
      offset = trackEnd;
    }

    events.sort((a, b) => a.tick - b.tick || (a.type === "on" ? -1 : 1));
    return { events, ticksPerQuarter };
  }

  /**
   * Convert parsed MIDI → Lua sheet string
   * @param {ArrayBuffer} buffer
   * @param {{ bpm?: number, shortNote?: boolean }} opts
   */
  function midiToLua(buffer, opts) {
    opts = opts || {};
    const bpm = opts.bpm || 120;
    const useShort = opts.shortNote !== false; // default short notes (x)

    const { events, ticksPerQuarter } = parseMidi(buffer);

    // Group note-ons by tick → chords
    const byTick = new Map();
    for (const ev of events) {
      if (ev.type !== "on") continue;
      if (!byTick.has(ev.tick)) byTick.set(ev.tick, []);
      byTick.get(ev.tick).push(ev.note);
    }

    const ticks = Array.from(byTick.keys()).sort((a, b) => a - b);
    if (ticks.length === 0) {
      return "-- empty MIDI\nfinishedSong()\n";
    }

    const lines = [];
    lines.push("-- AutoPiano sheet generated from MIDI");
    lines.push("-- BPM hint: " + bpm);
    lines.push("");

    let prevTick = ticks[0];

    // optional lead-in rest if first note not at 0
    if (prevTick > 0) {
      const beats = prevTick / ticksPerQuarter;
      if (beats > 0.01) {
        lines.push(`rest(${roundBeats(beats)}, bpm)`);
      }
    }

    for (let i = 0; i < ticks.length; i++) {
      const tick = ticks[i];
      const notes = byTick.get(tick);
      // unique + sorted
      const unique = [...new Set(notes)].sort((a, b) => a - b);
      const keys = unique.map(pitchToKey).join("");

      if (useShort) {
        lines.push(`keypress("${escapeKeys(keys)}", x, bpm)`);
      } else {
        // estimate duration from next event or 0.5 beat
        let durBeats = 0.5;
        if (i + 1 < ticks.length) {
          durBeats = Math.max(0.05, (ticks[i + 1] - tick) / ticksPerQuarter * 0.85);
        }
        lines.push(`keypress("${escapeKeys(keys)}", ${roundBeats(durBeats)}, bpm)`);
      }

      // rest until next note-on group
      if (i + 1 < ticks.length) {
        const deltaTicks = ticks[i + 1] - tick;
        const beats = deltaTicks / ticksPerQuarter;
        if (beats > 0.01) {
          lines.push(`rest(${roundBeats(beats)}, bpm)`);
        }
      }
    }

    lines.push("");
    lines.push("finishedSong()");
    return lines.join("\n");
  }

  function roundBeats(b) {
    // keep up to 3 decimals, strip trailing zeros
    const r = Math.round(b * 1000) / 1000;
    return String(r);
  }

  function escapeKeys(s) {
    return s.replace(/\\/g, "\\\\").replace(/"/g, '\\"');
  }

  global.Midi61 = {
    parseMidi,
    midiToLua,
    pitchToKey,
    NOTE_TO_KEY,
  };
})(typeof window !== "undefined" ? window : globalThis);
