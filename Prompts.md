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
