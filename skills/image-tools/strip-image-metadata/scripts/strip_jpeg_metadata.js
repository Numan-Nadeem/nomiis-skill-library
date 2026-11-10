// Rebuilds a JPEG keeping only rendering-critical marker segments, discarding
// metadata segments (EXIF, XMP, IPTC/Photoshop, C2PA/JUMBF, comments, etc).
//
// C2PA data typically lives in APP11 (0xEB). EXIF/XMP live in APP1 (0xE1).
// IPTC/Photoshop data lives in APP13 (0xED). This script strips all APPn
// markers except APP0 (JFIF header) and APP2 (commonly an ICC color profile,
// kept so colors don't shift), plus strips COM (0xFE).
//
// Once the first Start-Of-Scan (SOS, 0xDA) marker is reached, everything
// from there to end-of-file is copied through untouched, since that's
// entropy-coded image data (and, for progressive JPEGs, further scan/marker
// segments that are unsafe to reparse generically). This covers the vast
// majority of real-world JPEGs. For unusual files, prefer `exiftool` instead.
//
// Usage: node strip_jpeg_metadata.js <input.jpg> <output.jpg>

const fs = require("fs");

function stripJpeg(inputPath, outputPath) {
  const data = fs.readFileSync(inputPath);
  if (!(data[0] === 0xff && data[1] === 0xd8)) {
    throw new Error("Not a valid JPEG file (missing SOI marker)");
  }

  // Markers with no length/data payload that can appear before SOS.
  const STANDALONE = new Set([0x01, ...range(0xd0, 0xd7)]); // TEM, RST0-7
  const APPN_KEEP = new Set([0xe0, 0xe2]); // JFIF (APP0), ICC profile (APP2)

  function range(a, b) {
    const arr = [];
    for (let i = a; i <= b; i++) arr.push(i);
    return arr;
  }

  const out = [Buffer.from([0xff, 0xd8])]; // SOI
  const kept = [];
  const removed = [];
  let pos = 2;

  while (pos < data.length) {
    if (data[pos] !== 0xff) {
      throw new Error(`Expected marker at offset ${pos}, found 0x${data[pos].toString(16)}`);
    }
    // Skip any fill bytes (0xFF padding) before the real marker code.
    let markerPos = pos;
    while (data[markerPos + 1] === 0xff) markerPos++;
    const marker = data[markerPos + 1];
    const segStart = pos;

    if (marker === 0xd9) {
      // EOI with nothing after (rare before SOS) - keep and stop.
      out.push(data.subarray(segStart, segStart + 2));
      kept.push(["EOI", 0]);
      pos += 2;
      continue;
    }

    if (STANDALONE.has(marker)) {
      out.push(data.subarray(segStart, markerPos + 2));
      kept.push([`0xFF${marker.toString(16).toUpperCase()}`, 0]);
      pos = markerPos + 2;
      continue;
    }

    const length = data.readUInt16BE(markerPos + 2);
    const segTotalLen = (markerPos - segStart) + 2 + length;
    const isAppn = marker >= 0xe0 && marker <= 0xef;
    const isCom = marker === 0xfe;

    if ((isAppn && !APPN_KEEP.has(marker)) || isCom) {
      removed.push([`0xFF${marker.toString(16).toUpperCase()}`, length]);
    } else {
      out.push(data.subarray(segStart, segStart + segTotalLen));
      kept.push([`0xFF${marker.toString(16).toUpperCase()}`, length]);
    }

    pos = segStart + segTotalLen;

    if (marker === 0xda) {
      // Start of Scan: copy all remaining bytes (entropy-coded data,
      // possible further scans/markers for progressive JPEGs) untouched.
      out.push(data.subarray(pos));
      kept.push(["<scan data + remainder>", data.length - pos]);
      pos = data.length;
      break;
    }
  }

  const result = Buffer.concat(out);
  fs.writeFileSync(outputPath, result);

  console.log("Kept segments:");
  for (const [t, l] of kept) console.log(`  ${t}: ${l} bytes`);
  console.log("\nRemoved segments:");
  for (const [t, l] of removed) console.log(`  ${t}: ${l} bytes`);
  console.log(`\nOriginal size: ${data.length} bytes`);
  console.log(`New size: ${result.length} bytes`);
}

const [, , inputPath, outputPath] = process.argv;
if (!inputPath || !outputPath) {
  console.error("Usage: node strip_jpeg_metadata.js <input.jpg> <output.jpg>");
  process.exit(1);
}
stripJpeg(inputPath, outputPath);
