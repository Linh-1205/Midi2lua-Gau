/*
 * midi61.js - MIDI -> AutoPiano sheet (Virtual Piano 61 keys, C2..C7)
 * Không phụ thuộc thư viện ngoài. Dùng được cả trong trình duyệt lẫn Node.
 *
 *   const midi  = Midi61.parseMidi(arrayBuffer);
 *   const out   = Midi61.midiToSheet(midi, { bpm: 120, transpose: 0, fold: true, hold: false });
 *   out.sheet   -> chuỗi Lua: keypress(...) / rest(...) / finishedSong()
 */
(function (root) {
  "use strict";

  const WHITE = "1234567890qwertyuiopasdfghjklzxcvbnm"; // 36 phím trắng: C2..C7
  const SHIFT_SYMS = "!@#$%^&*()";
  const WHITE_DEGREE = { 0: 0, 2: 1, 4: 2, 5: 3, 7: 4, 9: 5, 11: 6 };
  const LOW = 36; // C2
  const HIGH = 96; // C7

  // midi note (C4 = 60) -> ký tự Virtual Piano, null nếu ngoài C2..C7
  function midiToKey(m) {
    if (m < LOW || m > HIGH) return null;
    const oct = Math.floor(m / 12) - 1;
    let pc = m % 12;
    let sharp = false;
    if (WHITE_DEGREE[pc] === undefined) {
      pc -= 1;
      sharp = true;
    }
    const idx = (oct - 2) * 7 + WHITE_DEGREE[pc];
    let ch = WHITE[idx];
    if (!ch) return null;
    if (sharp) {
      if (ch >= "0" && ch <= "9") ch = SHIFT_SYMS[ch === "0" ? 9 : Number(ch) - 1];
      else ch = ch.toUpperCase();
    }
    return ch;
  }

  // Đưa nốt về trong dải 61 phím bằng cách dịch cả quãng tám
  function fitToRange(m, fold) {
    if (!fold) return m >= LOW && m <= HIGH ? m : null;
    while (m < LOW) m += 12;
    while (m > HIGH) m -= 12;
    return m;
  }

  // ---------------------------------------------------------------- parser
  function parseMidi(buffer) {
    const data = new Uint8Array(buffer);
    let p = 0;
    const u8 = () => data[p++];
    const u16 = () => (data[p++] << 8) | data[p++];
    const u32 = () => ((data[p++] << 24) | (data[p++] << 16) | (data[p++] << 8) | data[p++]) >>> 0;
    const str = (n) => { let s = ""; for (let i = 0; i < n; i++) s += String.fromCharCode(data[p++]); return s; };
    const vlq = () => {
      let v = 0, b;
      do { b = u8(); v = (v << 7) | (b & 0x7f); } while (b & 0x80);
      return v >>> 0;
    };

    if (str(4) !== "MThd") throw new Error("Không phải file MIDI (thiếu MThd)");
    const hdrLen = u32();
    const format = u16();
    const ntrks = u16();
    const division = u16();
    p += hdrLen - 6;
    if (division & 0x8000) throw new Error("MIDI dùng SMPTE time code - chưa hỗ trợ");

    const notes = []; // { tick, endTick, pitch, vel }
    const tempos = []; // { tick, usPerBeat }

    for (let t = 0; t < ntrks; t++) {
      if (p >= data.length) break;
      const id = str(4);
      const len = u32();
      const end = p + len;
      if (id !== "MTrk") { p = end; continue; }

      let tick = 0, running = 0;
      const active = {}; // "ch:pitch" -> [note,...]
      while (p < end) {
        tick += vlq();
        let status = data[p];
        if (status & 0x80) { p++; if (status < 0xf0) running = status; }
        else status = running;

        if (status === 0xff) {
          const type = u8();
          const mlen = vlq();
          if (type === 0x51 && mlen === 3) tempos.push({ tick, usPerBeat: (data[p] << 16) | (data[p + 1] << 8) | data[p + 2] });
          p += mlen;
        } else if (status === 0xf0 || status === 0xf7) {
          p += vlq();
        } else {
          const kind = status & 0xf0, ch = status & 0x0f;
          if (kind === 0xc0 || kind === 0xd0) { p += 1; continue; }
          const a = u8(), b = u8();
          const key = ch + ":" + a;
          if (kind === 0x90 && b > 0) {
            if (ch === 9) continue; // kênh 10 = drum, bỏ qua
            const n = { tick, endTick: null, pitch: a, vel: b };
            (active[key] = active[key] || []).push(n);
            notes.push(n);
          } else if (kind === 0x80 || (kind === 0x90 && b === 0)) {
            const list = active[key];
            if (list && list.length) list.shift().endTick = tick;
          }
        }
      }
      for (const k in active) for (const n of active[k]) if (n.endTick === null) n.endTick = n.tick;
      p = end;
    }

    tempos.sort((a, b) => a.tick - b.tick);
    if (!tempos.length || tempos[0].tick > 0) tempos.unshift({ tick: 0, usPerBeat: 500000 });

    // tick -> giây theo tempo map
    const segs = [];
    let sec = 0;
    for (let i = 0; i < tempos.length; i++) {
      segs.push({ tick: tempos[i].tick, sec, usPerBeat: tempos[i].usPerBeat });
      const next = tempos[i + 1];
      if (next) sec += ((next.tick - tempos[i].tick) / division) * (tempos[i].usPerBeat / 1e6);
    }
    function tickToSec(tk) {
      let s = segs[0];
      for (let i = segs.length - 1; i >= 0; i--) if (segs[i].tick <= tk) { s = segs[i]; break; }
      return s.sec + ((tk - s.tick) / division) * (s.usPerBeat / 1e6);
    }

    for (const n of notes) {
      n.start = tickToSec(n.tick);
      n.end = tickToSec(n.endTick);
    }
    notes.sort((a, b) => a.start - b.start || a.pitch - b.pitch);

    const firstBpm = Math.round(60e6 / tempos[0].usPerBeat);
    const duration = notes.reduce((m, n) => Math.max(m, n.end), 0);
    return { format, division, notes, tempos, firstBpm, duration };
  }

  // ---------------------------------------------------------------- sheet
  function midiToSheet(midi, opts) {
    opts = opts || {};
    const bpm = Number(opts.bpm) > 0 ? Number(opts.bpm) : midi.firstBpm || 120;
    const transpose = Number(opts.transpose) || 0;
    const fold = opts.fold !== false;
    const hold = !!opts.hold;
    const EPS = 0.001; // nốt cách nhau <1ms coi là cùng timestamp (chord)
    const fmt = (v) => String(Math.round(v * 10000) / 10000);

    // gom theo timestamp
    const groups = [];
    let dropped = 0, folded = 0;
    for (const n of midi.notes) {
      let m = n.pitch + transpose;
      const fitted = fitToRange(m, fold);
      if (fitted === null) { dropped++; continue; }
      if (fitted !== m) folded++;
      const key = midiToKey(fitted);
      const last = groups[groups.length - 1];
      const beatLen = ((n.end - n.start) * bpm) / 60;
      if (last && Math.abs(n.start - last.start) < EPS) {
        if (!last.keys.includes(key)) { last.keys.push(key); last.beats = Math.max(last.beats, beatLen); }
      } else {
        groups.push({ start: n.start, keys: [key], beats: beatLen });
      }
    }

    const lines = [];
    let prevBeat = 0; // vị trí đã làm tròn của dòng trước
    for (const g of groups) {
      const absBeat = Math.round(((g.start * bpm) / 60) * 10000) / 10000;
      const gap = Math.round((absBeat - prevBeat) * 10000) / 10000;
      if (gap > 0) lines.push("rest(" + fmt(gap) + ", bpm)");
      prevBeat = absBeat;
      const keys = g.keys.join("").replace(/\\/g, "\\\\").replace(/"/g, '\\"');
      const len = hold ? fmt(Math.max(g.beats, 0.05)) : "x";
      lines.push('keypress("' + keys + '", ' + len + ", bpm)");
    }
    // chờ hết nốt cuối rồi mới finish
    const endBeat = Math.round(((midi.duration * bpm) / 60) * 10000) / 10000;
    if (endBeat > prevBeat) lines.push("rest(" + fmt(endBeat - prevBeat) + ", bpm)");
    lines.push("finishedSong()");

    return {
      sheet: lines.join("\n"),
      bpm,
      stats: {
        notes: midi.notes.length,
        groups: groups.length,
        dropped,
        folded,
        seconds: midi.duration,
      },
    };
  }

  const api = { parseMidi, midiToSheet, midiToKey };
  if (typeof module !== "undefined" && module.exports) module.exports = api;
  else root.Midi61 = api;
})(typeof window !== "undefined" ? window : this);
