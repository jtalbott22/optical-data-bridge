# Optical Data Bridge

**Send any file between two devices using nothing but their screens and cameras.**

One device flashes QR codes; the other reads them and flashes back what it still needs. The link tunes itself — frame rate first, then code density, then tiling — until it finds the fastest rate that stays error-free. Optionally, the two devices perform an ephemeral key exchange over the optical link itself and the entire transfer is end-to-end encrypted.

No Bluetooth. No Wi-Fi. No cables. No server. Just visible light.

**Live demo:** [joshuaallentalbott.com/optical-data-bridge.html](https://joshuaallentalbott.com/optical-data-bridge.html)

Video example: <https://youtube.com/shorts/ZntjNEJ7t1Y?is=q6BuPjFw9m81z4BB>

---

## Hardcopy — the companion app

**[`hardcopy.html`](hardcopy.html)** · **Live:** [joshuaallentalbott.com/hardcopy.html](https://joshuaallentalbott.com/hardcopy.html) · **Demo reel:** [instagram.com/reel/DdMubjwtyLN](https://www.instagram.com/reel/DdMubjwtyLN/)

Hardcopy is a set of practical QR tools packed into one self-contained HTML file. It grew out of Optical Data Bridge: it keeps the optical transport and pairing handshake, and adds tools for making, reading and printing codes. Everything runs in the page and works offline. The decoders (including the WebAssembly binary) and the typefaces are embedded, so nothing has to be downloaded.

It has four tabs:

| Tab | What it does |
| --- | --- |
| **Studio** | **Make a code** for a link, Wi-Fi network, contact card, email, text message, phone number, location, or plain text. You can style it with themes, gradients, module and corner shapes, a centre logo, a frame and caption, and an error-correction level, then export PNG (1024 or 2048 px), JPEG, or SVG, or print it. **Read codes** (`hardcopy.html#read`) scans from a camera or from imported photos and screenshots, keeps a local history that flags duplicates, and exports that history. |
| **File → QR pages** | Turns any file into numbered, self-identifying QR tiles on printable pages (print or save as PDF). You can choose the paper size, density presets matched to how you'll read the pages back, optional compression, a calibration sheet, a cover page, and an optional passphrase (AES-256-GCM). **RAID-style redundancy** lets the file survive lost pages: mirroring (RAID 1), XOR parity (RAID 5), or double parity over GF(256) (RAID 6). A stripe's tiles are spread across different sheets, so losing one page costs each stripe only one tile. |
| **QR pages → file** | Rebuilds the file from its tiles, read by the camera or from photos, scans, or an imported PDF. Tiles can arrive in any order, and progress is saved in the browser until the file is complete. |
| **Beam** | Transfers a file or text from screen to camera. It uses **fountain coding**, so the receiver can join at any moment and needs no back channel. Three privacy modes: **Open**; **Passphrase** (AES-256-GCM, key from PBKDF2 with 250k rounds); and **Paired** (an ephemeral ECDH P-256 handshake over the optical link, confirmed by matching emoji on both screens, carried over from Optical Data Bridge). |

**Secret codes (HCS1).** Studio can seal a code's contents behind a passphrase. The payload is AES-256-GCM with the key derived by PBKDF2-HMAC-SHA256, encoded as `HCS1:` plus RFC 4648 base32. It can also be wrapped as `hardcopy.html#HCS1:…`, so any phone camera can open it in Hardcopy and unlock it there. The byte layout is documented in the app ("The format, for anyone writing a reader").

**Decoding architecture.** The primary reader is ZXing compiled to WebAssembly (via zxing-wasm), with jsQR as a JavaScript fallback. This design exists because Safari has never shipped `BarcodeDetector` ([WebKit bug 281848](https://bugs.webkit.org/show_bug.cgi?id=281848)). PDF imports are rasterised with pdf.js.

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

## Similar projects

The concept here was arrived at from looking at how stuff works. It turns out several people have had similar ideas, and their takes are all worth a look:

- [mohankumarelec/airgapped-qr-code-transfer](https://github.com/mohankumarelec/airgapped-qr-code-transfer): browser-based QR file transfer with compression and sequential chunking. Discovered after publicly demoing this project; convergent evolution in action.
- [divan/txqr](https://github.com/divan/txqr) (2018): animated QR plus fountain codes in Go, with two excellent write-ups on why fountain coding beats sequential looping.
- [sz3/libcimbar](https://github.com/sz3/libcimbar): goes past QR entirely with a custom high-density color code purpose-built for this channel.
- [bashalarmistalt/decimen-optical-transfer](https://github.com/bashalarmistalt/decimen-optical-transfer) (Decimen Optical Transfer): see *Credits* below. Several of Hardcopy's design decisions come from it.

## Credits & sources

Third-party code is bundled under each project's own licence, with thanks. Both apps embed their dependencies inline, so each licence travels with the file.

### Code

| Project | Author | Licence | Used in | Role |
| --- | --- | --- | --- | --- |
| [qrcode-generator](https://github.com/kazuhikoarase/qrcode-generator) ([d-project.com](http://www.d-project.com/)) | Kazuhiko Arase | MIT | Optical Data Bridge, Hardcopy | QR encoder |
| [jsQR](https://github.com/cozmo/jsQR) | Cosmo Wolfe | Apache-2.0 | Optical Data Bridge (decoder), Hardcopy (fallback decoder) | QR decoder |
| [zxing-cpp](https://github.com/zxing-cpp/zxing-cpp) | The ZXing C++ project | Apache-2.0 | Hardcopy | Primary decoder |
| [zxing-wasm](https://github.com/Sec-ant/zxing-wasm) | Ze-Zheng Wu | MIT | Hardcopy | zxing-cpp compiled to WebAssembly |
| [pdf.js](https://mozilla.github.io/pdf.js/) | Mozilla | Apache-2.0 | Hardcopy | Reads QR pages out of imported PDFs |

Encryption in both apps uses the browser's built-in [Web Crypto API](https://developer.mozilla.org/en-US/docs/Web/API/Web_Crypto_API) (ECDH P-256, AES-256-GCM, PBKDF2, SHA-256). Compression uses the native `CompressionStream`.

### Typefaces (Hardcopy)

All are embedded and licensed under the [SIL Open Font License 1.1](https://openfontlicense.org/).

| Typeface | Designer | Source |
| --- | --- | --- |
| Newsreader | Production Type | [github.com/productiontype/Newsreader](https://github.com/productiontype/Newsreader) (subset to the characters the app uses, weight axis instanced at 400) |
| Atkinson Hyperlegible | Braille Institute of America | [brailleinstitute.org/freefont](https://brailleinstitute.org/freefont) |
| B612 Mono | Airbus / PolarSys | [github.com/polarsys/b612](https://github.com/polarsys/b612) |

### Ideas

- **[Decimen Optical Transfer](https://github.com/bashalarmistalt/decimen-optical-transfer)** (AGPL-3.0). Hardcopy's decoding architecture follows Decimen's approach: a WebAssembly reader in front of a JavaScript fallback, because Safari lacks `BarcodeDetector`. Hardcopy's Beam tab borrows three more of its ideas: fountain coding over a channel with no back channel, a pinned QR mask, and error correction left at level L because the fountain code already covers what the parity would have. **None of Decimen's code is used.** The ideas are theirs; the measurements that justified adopting them were taken against Hardcopy.
- **[Optical Data Bridge](https://github.com/jtalbott22/optical-data-bridge)** (this repository). It supplies Hardcopy's optical transport and the paired ECDH handshake that Beam carries.

### Support

Hardcopy is made by one person. If it earned its keep, there's a tip jar: [Support on Patreon](https://www.patreon.com/duh_live_video/posts/hardcopy-html-169247321).

## License

MIT — see [LICENSE](LICENSE).
