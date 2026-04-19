import { pipeline } from '@xenova/transformers';

let embedder: any = null;
let generator: any = null;

export const LocalAiConfig = {
  // 384-dim sentence embeddings — 22MB quantized, loads in ~2s
  embedModel: 'Xenova/all-MiniLM-L6-v2',
  // Encoder-decoder QA model — 77M params, ~100MB quantized, answers in 5-15s on CPU
  // Replaces TinyLlama-1.1B-Chat which took 3-10 minutes and always timed out.
  generateModel: 'Xenova/flan-t5-small',
};

export async function initLocalAi() {
  if (!embedder) {
    console.log(`[LocalAI] Loading embedding model: ${LocalAiConfig.embedModel}`);
    embedder = await pipeline('feature-extraction', LocalAiConfig.embedModel, {
      quantized: true,
    });
    console.log('[LocalAI] ✅ Embedding model loaded.');
  }

  if (!generator) {
    console.log(`[LocalAI] Loading generation model: ${LocalAiConfig.generateModel}`);
    // flan-t5 is a text2text-generation model (encoder-decoder), NOT text-generation
    generator = await pipeline('text2text-generation', LocalAiConfig.generateModel, {
      quantized: true,
    });
    console.log('[LocalAI] ✅ Generation model loaded.');
  }
}

export async function getEmbeddings(text: string): Promise<number[]> {
  await initLocalAi();
  // shape: [1, num_tokens, 384] → mean-pooled to [384]
  const out = await embedder(text, { pooling: 'mean', normalize: true });
  return Array.from(out.data) as number[];
}

export async function generateChat(query: string, contextChunks: string[]): Promise<string> {
  await initLocalAi();

  // flan-t5 works best with short, focused prompts.
  // Use top 3 chunks, trimmed to 250 chars each to keep total prompt < 1000 chars.
  const ctx = contextChunks
    .slice(0, 3)
    .map((c, i) => `[${i + 1}] ${c.length > 280 ? c.substring(0, 280) + '...' : c}`)
    .join('\n');

  // flan-t5 prompt format: simple instruction + context + question
  const prompt = `Answer the question using only the provided context. Be concise and specific.

Context:
${ctx}

Question: ${query}
Answer:`;

  const out = await generator(prompt, {
    max_new_tokens: 150,    // flan-t5-small generates 150 tokens in ~10s on CPU ✅
    num_beams: 2,           // light beam search for quality
    early_stopping: true,
    no_repeat_ngram_size: 3,
  });

  const answer = (out[0].generated_text as string).trim();
  return answer.length > 0 ? answer : 'I could not find a specific answer in your notes for that question.';
}
