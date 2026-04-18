import { Router } from 'express';
import { body, validationResult } from 'express-validator';
import { getEmbeddings, generateChat } from '../services/localAi';

const router = Router();

// POST /api/rag/embed
router.post(
  '/embed',
  body('text').isString().notEmpty(),
  async (req, res) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) return res.status(422).json({ errors: errors.array() });

    try {
      const vector = await getEmbeddings(req.body.text);
      return res.json({ embedding: vector });
    } catch (e: any) {
      console.error('[RAG] Embed Error:', e);
      return res.status(500).json({ error: 'Failed to generate local embeddings' });
    }
  }
);

// POST /api/rag/chat
router.post(
  '/chat',
  body('query').isString().notEmpty(),
  body('chunks').isArray(),
  async (req, res) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) return res.status(422).json({ errors: errors.array() });

    try {
      const { query, chunks } = req.body;
      const answer = await generateChat(query, chunks);
      return res.json({ text: answer });
    } catch (e: any) {
      console.error('[RAG] Chat Generation Error:', e);
      return res.status(500).json({ error: 'Failed to generate local chat response' });
    }
  }
);

export default router;
