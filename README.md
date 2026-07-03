# Optical Data Bridge

**Send any file between two devices using nothing but their screens and cameras.**

One device flashes QR codes; the other reads them and flashes back what it still needs. The link tunes itself — frame rate first, then code density, then tiling — until it finds the fastest rate that stays error-free.

No Bluetooth. No Wi-Fi. No cables. No server. Just visible light.

**Live demo:** [joshuaallentalbott.com/optical-data-bridge.html](https://joshuaallentalbott.com/optical-data-bridge.html)

---

## Why

QR codes are usually treated as static, one-shot data containers. Optical Data Bridge treats them as **frames in a transport protocol** — with sessions, acknowledgements, retransmission, integrity checks, and congestion control — all carried over a bidirectional optical link between two commodity devices.

This makes it useful anywhere conventional channels are unavailable or prohibited:

- Air-gapped systems and secure facilities
- Devices that can't pair (no shared network, no compatible radios, no accounts)
- Disaster / degraded-infrastructure scenarios
- Demonstrating transport-protocol concepts (flow control, ARQ, AIMD-style adaptation) in a form you can literally watch happen

## Quick start

1. Open `optical-data-bridge.html` on two devices (it's a single self-contained file — open it locally or from any static host).
2. On one device, pick a file and tap **Send**. On the other, tap **Receive**.
3. Prop the phones so each camera can see the other's screen.
4. The link starts slow for a clean lock, then ramps up on its own — watch the **optimizer** readout.
5. When every unit lands, the receiver verifies the file's CRC32 and offers it to save.

> **Note:** Camera access requires a secure context — serve over `https://` or open via `localhost`. Optical transfer is slow (~hundreds of bytes/sec depending on hardware); files under ~200 KB are realistic.

## How it works

### Architecture

Both devices run the same page in different roles, forming a closed loop:

```
  SENDER                                RECEIVER
  file → base64 → 48-byte units         camera → jsQR decode
       → packet scheduler                    → CRC16 validation
       → QR generation → screen ─────►       → reassembly
                                             → progress persistence
  camera ◄───────────────── screen ◄──  receiver report (QR)
       → adaptive controller
```

The receiver's display is not idle — it continuously flashes a compact status report back at the sender. That feedback drives retransmission and rate adaptation, the same way ACKs drive a conventional transport protocol.

### Protocol

Three pipe-delimited PDU types, each carried in its own QR code:

| PDU | Format | Purpose |
|-----|--------|---------|
| **Header** | `H \| sess \| total \| size \| b64len \| crc32 \| nameB64` | Session descriptor: identifies the file, its size, and the whole-file CRC32. Re-broadcast periodically so a receiver can join or resync at any time. |
| **Data** | `D \| sess \| start \| count \| total \| crc16 \| payload` | A window of 48-byte base64 units, addressed by sequence index and protected by CRC16. |
| **Report** | `R \| sess \| recv \| total \| dps \| err \| missCSV \| done` | Receiver status: units received, throughput, error count, an explicit missing-unit list, and a completion flag. |

### Adaptive optimizer

The sender searches for the highest sustainable operating point across three knobs, one at a time, in a fixed order:

1. **Frame rate** (2–20 fps)
2. **Density** — units packed per code (1–12 × 48 B)
3. **Tiling** — multiple codes shown per frame (1–9)

It starts conservative (1 unit, 1 tile, 3 fps) for a clean initial lock, ramps a knob while receiver reports stay clean, holds or steps back on errors, and eventually reaches `LOCKED`. If quality later degrades, it backs off in **reverse order** — shed tiles first, then density, then frame rate — which minimizes oscillation across wildly different camera/display pairings. The HUD shows the current phase (`RAMP FPS`, `HOLD DENS`, `BACKOFF TILE`, `LOCKED`, `RELINK`) in real time.

### Reliability

- **CRC16 per packet** — corrupted decodes are silently discarded, never assembled.
- **CRC32 per file** — the reassembled file is verified end-to-end before download; on the rare CRC16 collision that lets a bad unit through, the receiver clears its buffer and re-collects rather than stalling at 100%.
- **Selective retransmission** — the receiver reports exactly which unit ranges are missing, and the sender schedules those first.
- **Link watchdog** — if receiver reports stop arriving, the sender drops back to conservative acquisition settings (`RELINK`) so the receiver can re-lock after motion, refocus, or lighting changes.
- **Resume across interruptions** — receiver progress is persisted to `localStorage` keyed by the file's CRC32. Close the tab mid-transfer, come back later, and it picks up where it left off. If the sender restarts with a new session ID for the same file, the receiver adopts the new session and keeps its progress. Stale progress entries are garbage-collected automatically.
- **Screen Wake Lock** — both devices keep their displays awake for the duration of the transfer (where the browser supports it).

## Implementation notes

- **Single file, zero dependencies at runtime.** [jsQR](https://github.com/cozmo/jsQR) (decoding) and [qrcode-generator](https://github.com/kazuhikoarase/qrcode-generator) (encoding) are inlined; nothing is fetched over the network.
- Camera frames are downscaled to 800 px and decoded on a ~55 ms throttle (~18 scans/s ceiling), with up to 9 QR detections per frame to support tiled layouts.
- Works in any modern browser with `getUserMedia` support; includes camera selection and a flip-camera control for multi-camera devices.

## Limitations

- Throughput is bounded by camera frame rate, display refresh, decode latency, and lighting — expect hundreds of bytes per second, not megabits. This is a channel of last resort, not a fast one.
- The protocol provides **integrity, not confidentiality**. Payloads are not encrypted; anyone who can see the screen can record the transfer. Encrypt files before sending if that matters (the transport carries encrypted payloads without modification).
- Bright, even lighting and steady positioning matter. The optimizer compensates for a lot, but physics wins.

## Roadmap ideas

Forward error correction, color multiplexing, multi-device broadcast, alternative symbol formats, and a formal protocol specification are all natural extensions. See the companion write-up for a deeper discussion of the protocol design.

## License

MIT — see [LICENSE](LICENSE).
