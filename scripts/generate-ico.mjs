// Generate .ico: white giraffe silhouette on fuchsia background
import sharp from 'sharp';
import pngToIco from 'png-to-ico';
import { writeFileSync, mkdirSync } from 'fs';
import { join, dirname } from 'path';
import { fileURLToPath } from 'url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const root = join(__dirname, '..');
const src = join(root, 'assets/branding/twiza-white.png');
const outDir = join(root, 'src-tauri/icons');
mkdirSync(outDir, { recursive: true });

const FUCHSIA = { r: 212, g: 0, b: 106 };
const sizes = [16, 24, 32, 48, 64, 128, 256];

async function makeIcon(size) {
  // Resize source to target, keeping aspect ratio
  const innerSize = Math.round(size * 0.75);
  
  // The source is dark on transparent. We want white where there's content.
  // Strategy: resize, extract alpha, use alpha as white mask on fuchsia bg
  const resized = await sharp(src)
    .resize(innerSize, innerSize, { fit: 'contain', background: { r: 0, g: 0, b: 0, alpha: 0 } })
    .ensureAlpha()
    .raw()
    .toBuffer({ resolveWithObject: true });
  
  const { data, info } = resized;
  const pixels = new Uint8Array(info.width * info.height * 4);
  
  // For each pixel: where alpha > 0, make it white; where alpha = 0, make it fuchsia
  for (let i = 0; i < info.width * info.height; i++) {
    const a = data[i * 4 + 3]; // alpha of original
    if (a > 20) {
      // Content pixel → white
      pixels[i * 4] = 255;
      pixels[i * 4 + 1] = 255;
      pixels[i * 4 + 2] = 255;
      pixels[i * 4 + 3] = 255;
    } else {
      // Transparent → fuchsia
      pixels[i * 4] = FUCHSIA.r;
      pixels[i * 4 + 1] = FUCHSIA.g;
      pixels[i * 4 + 2] = FUCHSIA.b;
      pixels[i * 4 + 3] = 255;
    }
  }
  
  const giraffeBuf = await sharp(Buffer.from(pixels), {
    raw: { width: info.width, height: info.height, channels: 4 }
  }).png().toBuffer();
  
  // Composite on fuchsia background
  return sharp({
    create: { width: size, height: size, channels: 4, background: { ...FUCHSIA, alpha: 255 } }
  })
  .composite([{ input: giraffeBuf, gravity: 'centre' }])
  .png()
  .toBuffer();
}

async function main() {
  const pngs = [];
  for (const size of sizes) {
    const buf = await makeIcon(size);
    pngs.push(buf);
    writeFileSync(join(outDir, `${size}x${size}.png`), buf);
    console.log(`✓ ${size}x${size}.png`);
  }
  
  for (const size of [512, 1024]) {
    const buf = await makeIcon(size);
    writeFileSync(join(outDir, `${size}x${size}.png`), buf);
    console.log(`✓ ${size}x${size}.png`);
  }
  
  writeFileSync(join(outDir, 'icon.png'), await makeIcon(256));
  
  const icoBuffer = await pngToIco(pngs);
  writeFileSync(join(outDir, 'icon.ico'), icoBuffer);
  console.log('✓ icon.ico');
  
  console.log('\nDone! All icons in src-tauri/icons/');
}

main().catch(console.error);
