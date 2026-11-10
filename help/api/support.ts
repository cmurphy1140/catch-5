import { handleSupport } from '../support-core.mjs';

// Stream the raw body so oversized requests are rejected before JSON parsing.
export const config = { api: { bodyParser: false } };
export default async function handler(req: any, res: any) {
  res.setHeader('Cache-Control', 'no-store');
  const chunks: Buffer[] = [];
  let size = 0;
  try {
    for await (const chunk of req) {
      size += Buffer.byteLength(chunk);
      if (size > 48 * 1024) {
        res.status(413).json({ error: 'Question is too large.' });
        return;
      }
      chunks.push(Buffer.from(chunk));
    }
    const result = await handleSupport({ method: req.method, code: req.headers['x-support-code'], body: Buffer.concat(chunks).toString('utf8') });
    res.status(result.status).json(result.body);
  } catch {
    res.status(400).json({ error: 'Invalid support request.' });
  }
}
