This was my initial claude prompts. I tried using Fabel, but I was flagged and downgraded to 4.8.

"I need an html app. It will encode and transmit data using QR codes flashed in sequence to transmit a base64 payload. It should allow for opening any file and it will chunk it to QR codes that will show up tiled across the browser canvas. It will open a camera simultaneously to view any QR codes shown to it to confirm the transmission of data to the receiver. Basically two phones with their front facing cameras should be able to send data via codes. It should start with DPI that is low enough to be very successful in the beginning transmission, then increases DPI and tiles flashed until errors occur on the receiver side. The receiver side should communicate errors or needing repeated codes to complete a transmission sequence to the sender while the sender is still attempting sending. The sender should update the canvas for the optimum DPI and bytes per code as transmission happens. Use JavaScript libs for the ML code reader and code generation. One flat file should work on both the sender or the receiver with a elegant solution for toggling which mode and then you simply show the screens and cameras to each other and let that take over from there, and the frame rate of flashing codes should increase until errors start occurring on the receiver and the receiver informs the center of them and adjusts accordingly both the frame rate and the DPI. Use an optimization algorithm to determine these quickly over the series of several frames of samples acting as a focus buffer. basically we should be able to send any file over video."

follow up:

"The camera viewfinder covers the QR code, blocking it from starting the transmission."

follow up:

"Can you adjust the optimization algorithm to try things in a different order? I’m noticing that we could start with the low bite QR code and then we could probably try increasing the frame rate first before adding more density to the codes and then certainly before splitting them into multiple tiles. I think tiling should be the last optimization to try, but I’m noticing it doesn’t scan multiple codes simultaneously very well so I don’t know if that’s an issue on the reading side that might need addressed to thread the video better or if that’s just a limitation of the library. But anyway, if we just adjust the order of how the optimizations are run, I think we can find the best code per second rates by just tried to increase the frame rates and then once we get the fastest frame rates possible we can start adding more bites to the codes to see if we can cram more data and then we would back off of that before trying to tile across multiple codes. Also, if you could put a bounding box in the viewfinder around the codes to show, they are being detected as a visual indicator that would be great, but otherwise the structure of the site is really nice and should not change just this scanning optimization logic."

follow up:

"It works better speed wise. But it for some reason keeps stopping showing new codes before it’s done. No errors logged to the console but the transfer stalls and can’t be resumed. Can you add a resume feature too? Save the chunks to local storage somehow? Purge when reset."

follow up:

"Can you help me write a github readme based on this?"


follow up:

"Write me a build script for a custom Linux firmware that basically launches a single file with chromium at startup and has the display drivers and camera drivers included. Target raspberry pie."

Gemini prompts:

Does this mean it's easy for someone to decode QR codes flashing on a phone screen? https://www.cl.cam.ac.uk/~mgk25/pet2004-fpd.pdf

yeah or like in a building

Both. But I think if we use cameras and QRs to obtain a cryptographic session before transmitting, that would be good.

Yeah I wanted to make this more secure: https://github.com/jtalbott22/optical-data-bridge

Follow up with Claude:

Can we add encryption to our optical data bridge app successfully? I asked Google Gemini and it suggested this:

Looking at your Optical Data Bridge repository, it is an incredibly clever and well-engineered project. Treating QR codes as dynamic frames in a transport protocol—complete with ACK/NACK, AIMD-style adaptation, and dynamic tiling over a bidirectional optical link—is brilliant.
However, as it stands, the protocol is built for reliability, not security. Because the payload is divided into raw base64 chunks and flashed across the screen, it is fully vulnerable to the eavesdropping threats we just discussed (both high-resolution "shoulder-surfing" cameras and close-range TEMPEST snooping). Furthermore, it relies on a CRC32 checksum, which prevents accidental data corruption but offers zero defense against malicious tampering or frame injection.
Since your architecture is already bidirectional (both phones are actively scanning and flashing back to each other), you have the perfect foundation to build a highly secure, fully encrypted, mutually authenticated optical data bridge.
To fit the ethos of your project (a single, self-contained HTML/JS file with no external servers), you can implement this entirely using the browser's native Web Crypto API.
An upgrade blueprint can turn your optical transport layer into an encrypted tunnel.
The Threat Model to Address
 * Confidentiality: A third-party camera or RF receiver records the flashing screens and reconstructs the file.
 * Integrity & Authenticity: A malicious entity uses a screen overlay or a modulated light source to alter data frames or inject a completely different file payload while keeping a valid checksum.
The Security Blueprint: "Authenticated Optical Tunnel"
By leveraging the bidirectional loop your code already establishes, you can inject a cryptographic handshake before the optimization and file transmission phases begin.
Phase 1: The Ephemeral Handshake (ECDH)
Before the sender sends the first byte of the file, the two devices must agree on a symmetric encryption key without an eavesdropper being able to calculate it.
 * Sender Initiates: The sender generates an ephemeral (temporary) Elliptic-Curve Diffie-Hellman (ECDH) key pair. It encodes its Public Key (PK_S) into the initial QR frames and flashes it.
 * Receiver Responds: The receiver scans PK_S, generates its own ephemeral ECDH key pair, and flashes its Public Key (PK_R) back to the sender's camera.
 * Key Derivation: Both devices combine their private keys with the other's public key to derive the exact same shared secret. They pass this secret through a Key Derivation Function (HKDF-SHA256) to produce a unique Symmetric Session Key.
Security Win: Even if a spy records the entire handshake with a camera, owning PK_S and PK_R is useless. Mathematically, they cannot calculate the shared session key without the private keys, which never leave the devices' RAM.
Phase 2: Authenticated Encryption (AES-GCM)
Once the session key is established, you change how you slice and package the file.
 * Ditch raw Base64: Instead of turning a file chunk directly into Base64, you pass the raw binary chunk into an AES-GCM encryption function using your Session Key.
 * AES-GCM replaces CRC32: AES-GCM is an Authenticated Encryption algorithm. It outputs the ciphertext plus a 128-bit Authentication Tag. If even a single pixel of the QR code is maliciously altered or injected, the Auth Tag will fail to validate, and the receiver will instantly drop the frame.
 * Include a Nonce/Sequence Number: Pass an incrementing counter (e.g., Frame 1, Frame 2...) as the initialization vector (IV/Nonce). This prevents an attacker from recording a valid encrypted QR code and re-flashing it later to disrupt or hijack the session (Replay Attacks).
Conceptual Implementation using Web Crypto API
Because your project is pure JavaScript, you don't need to import heavy libraries like OpenSSL or CryptoJS. Modern browsers handle this natively.
Here is a conceptual look at how you could generate the keys and encrypt the frames within your existing architecture:
1. Generating the Handshake Keys (Both Devices)
// Generate ECDH Ephemeral Keys
const keyPair = await window.crypto.subtle.generateKey(
  { name: "ECDH", namedCurve: "P-256" },
  true, // extractable (so we can turn the public key into a QR code)
  ["deriveKey"]
);

// Export the Public Key to flash as a QR code
const exportedPublicKey = await window.crypto.subtle.exportKey("raw", keyPair.publicKey);
const publicKeyBase64 = btoa(String.fromCharCode(...new Uint8Array(exportedPublicKey)));
// TODO: Flash `publicKeyBase64` as your initial "Handshake QR"

2. Deriving the Shared Session Key (Once both public keys are scanned)
// Import the other device's public key from the scanned QR code
const importedOtherPublicKey = await window.crypto.subtle.importKey(
  "raw", 
  scannedPublicKeyUint8Array, 
  { name: "ECDH", namedCurve: "P-256" }, 
  false, 
  []
);

// Derive the AES-GCM symmetric session key
const sessionKey = await window.crypto.subtle.deriveKey(
  { name: "ECDH", public: importedOtherPublicKey },
  keyPair.privateKey,
  { name: "AES-GCM", length: 256 },
  false, // Not extractable (cannot be stolen from RAM easily)
  ["encrypt", "decrypt"]
);

3. Encrypting the File Chunks (Sender side)
Instead of slicing the file directly into raw data units, encrypt them frame-by-frame:
async function encryptFrame(chunkBytes, frameSequenceNumber) {
  // Use the sequence number/counter as part of the IV to prevent replay attacks
  const iv = new Uint8Array(12);
  new DataView(iv.buffer).setUint32(0, frameSequenceNumber); 

  const ciphertext = await window.crypto.subtle.encrypt(
    { name: "AES-GCM", iv: iv },
    sessionKey,
    chunkBytes
  );

  // Combine IV + Ciphertext (which includes the GCM Auth Tag at the end)
  const packet = new Uint8Array(iv.length + ciphertext.byteLength);
  packet.set(iv, 0);
  packet.set(new Uint8Array(ciphertext), iv.length);

  // Convert to Base64 to give to your QR generator
  return btoa(String.fromCharCode(...packet));
}

What it looks like in practice
If you implement this:
 * To the User: The experience is identical. They line up the cameras, the phones flash a couple of quick initialization frames to trade public keys (takes a fraction of a second), and then the file transfer starts.
 * To an Eavesdropper: The moment the handshake finishes, the QR codes flashing on the screens transition from recognizable data patterns to pure, cryptographic pseudo-random noise. If they record the video, they cannot decrypt it. If they try to alter the light waves to manipulate the data, the receiver's Web Crypto API will throw an authentication error and reject the frame.
This would elevate your project from a cool experiment in transport protocols to a legitimately viable, hyper-secure tool for moving data into or out of high-security, air-gapped environments.


follow up:
That sounds like a great plan. Let’s give that a shot.
