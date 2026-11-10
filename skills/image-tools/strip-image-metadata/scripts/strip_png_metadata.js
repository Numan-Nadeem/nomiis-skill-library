// Rebuilds a PNG keeping only rendering-critical chunks, discarding all
// ancillary/metadata chunks (including C2PA/Content Credentials manifests,
// which are often smuggled into a non-standard chunk type such as `caBX`,
// as well as EXIF, XMP, text chunks, etc).
//
// Usage: node strip_png_metadata.js <input.png> <output.png>

const fs = require("fs");

function stripPng(inputPath, outputPath) {
  const data = fs.readFileSync(inputPath);
  const expectedSig = Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]);
  if (!data.subarray(0, 8).equals(expectedSig)) {
    throw new Error("Not a valid PNG file");
  }

  // Only chunks required to decode/render the image.
  const keepTypes = new Set(["IHDR", "PLTE", "tRNS", "IDAT", "IEND"]);

  const chunks = [];
  const kept = [];
  const removed = [];
  let pos = 8;

  while (pos < data.length) {
    const length = data.readUInt32BE(pos);
    const type = data.subarray(pos + 4, pos + 8).toString("ascii");
    const chunkTotalLen = 4 + 4 + length + 4; // length + type + data + crc

    if (keepTypes.has(type)) {
      chunks.push(data.subarray(pos, pos + chunkTotalLen));
      kept.push([type, length]);
    } else {
      removed.push([type, length]);
    }

    pos += chunkTotalLen;
  }

  const out = Buffer.concat([expectedSig, ...chunks]);
  fs.writeFileSync(outputPath, out);

  console.log("Kept chunks:");
  for (const [t, l] of kept) console.log(`  ${t}: ${l} bytes`);
  console.log("\nRemoved chunks:");
  for (const [t, l] of removed) console.log(`  ${t}: ${l} bytes`);
  console.log(`\nOriginal size: ${data.length} bytes`);
  console.log(`New size: ${out.length} bytes`);
}

const [, , inputPath, outputPath] = process.argv;
if (!inputPath || !outputPath) {
  console.error("Usage: node strip_png_metadata.js <input.png> <output.png>");
  process.exit(1);
}
stripPng(inputPath, outputPath);
