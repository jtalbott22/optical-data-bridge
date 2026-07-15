# Optical Data Bridge

**Send any file between two devices using nothing but their screens and cameras.**

One device flashes QR codes; the other reads them and flashes back what it still needs. The link tunes itself — frame rate first, then code density, then tiling — until it finds the fastest rate that stays error-free. Optionally, the two devices perform an ephemeral key exchange over the optical link itself and the entire transfer is end-to-end encrypted.

No Bluetooth. No Wi-Fi. No cables. No server. Just visible light.

**Live demo:** [joshuaallentalbott.com/optical-data-bridge.html](https://joshuaallentalbott.com/optical-data-bridge.html)

Video example: <https://youtube.com/shorts/ZntjNEJ7t1Y?is=q6BuPjFw9m81z4BB>

---

## Why

QR codes are usually treated as static, one-shot data containers. Optical Data Bridge treats them as **frames in a transport protocol** — with sessions, acknowledgements, retransmission, integrity checks, congestion control, and an optional authenticated-encryption layer — all carried over a bidirectional optical link between two commodity devices.

This makes it useful anywhere conventional channels are unavailable or prohibited:

- Air-gapped systems and secure facilities
- Devices that can't pair (no shared network, no compatible radios, no accounts)
- Disaster / degraded-infrastructure scenarios
- Demonstrating transport-protocol concepts (flow control, ARQ, AIMD-style adaptation, key exchange) in a form you can literally watch happen

## Quick start

1. Open `optical-data-bridge.html` on two devices (it's a single self-contained file — open it locally or from any static host).
2. On one device, pick a file — and optionally check **🔒 Encrypt transfer** — then tap **Send**. On the other, tap **Receive**.
3. Prop the phones so each camera can see the other's screen.
4. If encryption is on, the devices trade public keys in the first few frames and both screens display the same short emoji code — glance and confirm they match.
5. The link starts slow for a clean lock, then ramps up on its own — watch the **optimizer** readout.
6. When every unit lands, the receiver verifies the transfer (and decrypts it, if encrypted) and offers the file to save.

> **Note:** Camera access — and the Web Crypto API used by encrypted mode — requires a secure context: serve over `https://` or open via `localhost`. Optical transfer is slow (~hundreds of bytes/sec depending on hardware); files under ~200 KB are realistic.

## How it works

### Architecture

Both devices run the same page in different roles, forming a closed loop:

```
SENDER                                RECEIVER
file → [AES-GCM seal (optional)]      camera → jsQR decode
     → base64 → 48-byte units              → CRC16 validation
     → packet scheduler                    → reassembly
     → QR generation → screen ─────►       → progress persistence
                                           → [AES-GCM open (optional)]
camera ◄───────────────── screen ◄──  receiver report / public key (QR)
     → adaptive controller
```

The receiver's display is not idle — it continuously flashes a compact status report back at the sender. That feedback drives retransmission and rate adaptation, the same way ACKs drive a conventional transport protocol. The same back-channel carries the receiver's public key during an encrypted handshake.

### Protocol

Four pipe-delimited PDU types, each carried in its own QR code:

| PDU        | Format                                                       | Purpose                                                                                                                                                        |
| ---------- | ------------------------------------------------------------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Header** | `H | sess | total | size | b64len | crc32 | nameB64 | enc`    | Session descriptor: identifies the file, its size, the whole-payload CRC32, and whether the payload is encrypted. Re-broadcast periodically so a receiver can join or resync at any time. |
| **Data**   | `D | sess | start | count | total | crc16 | payload`         | A window of 48-byte base64 units, addressed by sequence index and protected by CRC16.                                                                          |
| **Report** | `R | sess | recv | total | dps | err | missCSV | done`       | Receiver status: units received, throughput, error count, an explicit missing-unit list, and a completion flag.                                                |
| **Key**    | `K | sess | role | pubKeyB64`                                | Ephemeral ECDH public key (`role` = `S`ender or `R`eceiver). Opens an encrypted session; the sender also re-broadcasts it periodically so a receiver that lost state can re-handshake. |

### Encrypted mode

Checking **🔒 Encrypt transfer** on the sender turns the optical link into an authenticated, end-to-end encrypted tunnel — implemented entirely with the browser's native Web Crypto API, keeping the single-file / zero-dependency design.

**Handshake.** Before any data is shown, the sender flashes an ephemeral ECDH (P-256) public key as a `K` frame. The receiver auto-detects it, generates its own ephemeral key pair, and flashes its public key back. Both sides derive the same AES-256-GCM session key (ECDH → `deriveKey`, non-extractable). Private keys and the session key never leave RAM and never appear on either screen.

**Verification.** Unauthenticated key exchange is vulnerable to a man-in-the-middle in principle, so both screens display a short authentication string — five emoji plus a hex pair, derived from a SHA-256 hash of both public keys. A MITM cannot make the two codes match; users glance and confirm, the same idea as Signal safety numbers. (In practice a MITM on this channel would need to physically interpose displays in the optical path — the SAS makes even that visible.)

**Sealing.** The whole file is encrypted once (12-byte random IV + AES-GCM ciphertext with its 128-bit auth tag) and the ciphertext enters the normal unit pipeline unchanged. CRC16/CRC32 remain purely transport-level error detection; the GCM tag is what authenticates the payload. Any tampered or injected frame — even a fully self-consistent forgery with valid CRCs — fails authentication at assembly and is discarded, after which the receiver re-collects from the genuine stream. Total cryptographic overhead: 28 bytes per transfer.

**Rekeying.** Session keys are ephemeral by design, so a receiver that reloads mid-transfer loses its key. The sender re-broadcasts its `K` frame every couple of seconds; when it sees a *new* receiver key come back, it transparently re-handshakes and re-encrypts (`REKEY`), and the transfer restarts cleanly under the fresh key. For the same reason, `localStorage` resume is disabled for encrypted transfers — ciphertext without the session key is useless, which is exactly the point.

**What an eavesdropper sees.** A camera (or RF receiver) recording both screens captures two public keys and a stream of AES-GCM ciphertext. Without either device's private key — which never leaves RAM — the recording is computationally useless.

### Adaptive optimizer

The sender searches for the highest sustainable operating point across three knobs, one at a time, in a fixed order:

1. **Frame rate** (2–20 fps)
2. **Density** — units packed per code (1–12 × 48 B)
3. **Tiling** — multiple codes shown per frame (1–9)

It starts conservative (1 unit, 1 tile, 3 fps) for a clean initial lock, ramps a knob while receiver reports stay clean, holds or steps back on errors, and eventually reaches `LOCKED`. If quality later degrades, it backs off in **reverse order** — shed tiles first, then density, then frame rate — which minimizes oscillation across wildly different camera/display pairings. The HUD shows the current phase (`RAMP FPS`, `HOLD DENS`, `BACKOFF TILE`, `LOCKED`, `RELINK`, `REKEY`) in real time.

### Reliability

- **CRC16 per packet** — corrupted decodes are silently discarded, never assembled.
- **CRC32 per payload** — the reassembled payload is verified end-to-end before download; on the rare CRC16 collision that lets a bad unit through, the receiver clears its buffer and re-collects rather than stalling at 100%.
- **AES-GCM authentication (encrypted mode)** — after transport checks pass, decryption authenticates every byte against the session key; forged or tampered payloads are rejected and re-collected.
- **Selective retransmission** — the receiver reports exactly which unit ranges are missing, and the sender schedules those first.
- **Link watchdog** — if receiver reports stop arriving, the sender drops back to conservative acquisition settings (`RELINK`) so the receiver can re-lock after motion, refocus, or lighting changes.
- **Resume across interruptions** (plaintext transfers) — receiver progress is persisted to `localStorage` keyed by the file's CRC32. Close the tab mid-transfer, come back later, and it picks up where it left off. If the sender restarts with a new session ID for the same file, the receiver adopts the new session and keeps its progress. Stale progress entries are garbage-collected automatically. Encrypted transfers instead rely on automatic rekeying (see above).
- **Screen Wake Lock** — both devices keep their displays awake for the duration of the transfer (where the browser supports it).

## Implementation notes

- **Single file, zero dependencies at runtime.** [jsQR](https://github.com/cozmo/jsQR) (decoding) and [qrcode-generator](https://github.com/kazuhikoarase/qrcode-generator) (encoding) are inlined; encryption uses the browser's built-in Web Crypto API. Nothing is fetched over the network.
- Camera frames are downscaled to 800 px and decoded on a ~55 ms throttle (~18 scans/s ceiling), with up to 9 QR detections per frame to support tiled layouts.
- Works in any modern browser with `getUserMedia` support; includes camera selection and a flip-camera control for multi-camera devices.

## Limitations

- Throughput is bounded by camera frame rate, display refresh, decode latency, and lighting — expect hundreds of bytes per second, not megabits. This is a channel of last resort, not a fast one.
- **Plaintext mode provides integrity, not confidentiality.** Without the 🔒 option, anyone who can see the screen can record and reconstruct the transfer. Encrypted mode addresses this with an ephemeral ECDH handshake and AES-256-GCM — but the SAS check is only as good as the humans performing it: if you skip comparing the codes, you skip the MITM defense.
- Encrypted mode requires a browser with Web Crypto (`crypto.subtle`), which in turn requires a secure context — the same HTTPS/localhost requirement the camera already imposes.
- Encryption protects the payload, not the fact of a transfer: an observer can still see that two devices are exchanging data, its approximate size, and its rate. Metadata privacy is out of scope.
- Bright, even lighting and steady positioning matter. The optimizer compensates for a lot, but physics wins.

## Roadmap ideas

Forward error correction, color multiplexing, multi-device broadcast, alternative symbol formats, and a formal protocol specification are all natural extensions.

## License

MIT — see [LICENSE](LICENSE).
