import {getDocument, GlobalWorkerOptions} from './vendor/pdf.mjs';

GlobalWorkerOptions.workerSrc = new URL('./vendor/pdf.worker.mjs', import.meta.url).href;

export async function compressPdf(blob, onProgress) {
  const loading = getDocument({data: await blob.arrayBuffer(), stopAtErrors: true, enableXfa: false});
  const pages = [];
  try {
    const pdf = await loading.promise;
    const canvas = document.createElement('canvas');
    try {
      for (let index = 1; index <= pdf.numPages; index++) {
        onProgress(index, pdf.numPages);
        const page = await pdf.getPage(index);
        const original = page.getViewport({scale: 1});
        const scale = Math.min(2, 1800 / Math.max(original.width, original.height));
        const viewport = page.getViewport({scale});
        canvas.width = Math.max(1, Math.ceil(viewport.width));
        canvas.height = Math.max(1, Math.ceil(viewport.height));
        const canvasContext = canvas.getContext('2d', {alpha: false});
        await page.render({canvas, canvasContext, viewport}).promise;
        const jpeg = await new Promise(resolve => canvas.toBlob(resolve, 'image/jpeg', 0.8));
        if (jpeg?.type !== 'image/jpeg') throw new Error('Could not encode the scanned page.');
        pages.push({jpeg, width: canvas.width, height: canvas.height, original});
        page.cleanup();
      }
    } finally {
      canvas.width = canvas.height = 0;
    }
    return imagePdf(pages);
  } finally {
    await loading.destroy();
  }
}

// Each output page contains one JPEG. PDF offsets count bytes, including the JPEG data.
function imagePdf(pages) {
  const encoder = new TextEncoder();
  const parts = [];
  const offsets = [0];
  let size = 0;
  function write(part) {
    const data = typeof part === 'string' ? encoder.encode(part) : part;
    parts.push(data);
    size += data instanceof Blob ? data.size : data.byteLength;
  }
  function object(id, content, stream) {
    offsets[id] = size;
    write(`${id} 0 obj\n${content}\n`);
    if (stream) {
      write('stream\n');
      write(stream);
      write('\nendstream\n');
    }
    write('endobj\n');
  }

  write('%PDF-1.4\n');
  object(1, '<< /Type /Catalog /Pages 2 0 R >>');
  const children = pages.map((_, index) => `${3 + index * 3} 0 R`).join(' ');
  object(2, `<< /Type /Pages /Count ${pages.length} /Kids [${children}] >>`);
  pages.forEach(({jpeg, width, height, original}, index) => {
    const id = 3 + index * 3;
    const w = original.width.toFixed(3);
    const h = original.height.toFixed(3);
    object(id, `<< /Type /Page /Parent 2 0 R /MediaBox [0 0 ${w} ${h}] /Resources << /XObject << /Scan ${id + 1} 0 R >> >> /Contents ${id + 2} 0 R >>`);
    object(id + 1, `<< /Type /XObject /Subtype /Image /Width ${width} /Height ${height} /ColorSpace /DeviceRGB /BitsPerComponent 8 /Filter /DCTDecode /Length ${jpeg.size} >>`, jpeg);
    const commands = encoder.encode(`q\n${w} 0 0 ${h} 0 0 cm\n/Scan Do\nQ\n`);
    object(id + 2, `<< /Length ${commands.byteLength} >>`, commands);
  });
  const xref = size;
  write(`xref\n0 ${offsets.length}\n0000000000 65535 f \n`);
  for (const offset of offsets.slice(1)) write(`${String(offset).padStart(10, '0')} 00000 n \n`);
  write(`trailer\n<< /Size ${offsets.length} /Root 1 0 R >>\nstartxref\n${xref}\n%%EOF\n`);
  return new Blob(parts, {type: 'application/pdf'});
}
