import { pipeline } from '@xenova/transformers';

let embedder: any = null;
let generator: any = null;

export const LocalAiConfig = {
  embedModel: 'Xenova/all-MiniLM-L6-v2', // Outputs 384 dim
  generateModel: 'Xenova/TinyLlama-1.1B-Chat-v1.0' // Lightweight QA
};

export async function initLocalAi() {
  if (!embedder) {
    console.log(`[LocalAI] Loading embedding model: ${LocalAiConfig.embedModel}`);
    embedder = await pipeline('feature-extraction', LocalAiConfig.embedModel, {
      quantized: true, // Use int8 for fast offline CPU usage
    });
    console.log('[LocalAI] Embedding model loaded successfully.');
  }

  if (!generator) {
    console.log(`[LocalAI] Loading generation model: ${LocalAiConfig.generateModel}`);
    generator = await pipeline('text-generation', LocalAiConfig.generateModel, {
      quantized: true,
    });
    console.log('[LocalAI] Generation model loaded successfully.');
  }
}

export async function getEmbeddings(text: string): Promise<number[]> {
  await initLocalAi();
  // Generate embeddings: output shape is [1, num_tokens, dimension]
  const out = await embedder(text, { pooling: 'mean', normalize: true });
  return Array.from(out.data);
}

export async function generateChat(query: string, contextChunks: string[]): Promise<string> {
  await initLocalAi();
  
  const ctx = contextChunks.map((c, i) => `[${i + 1}] ${c}`).join('\n\n');
  const prompt = `<|system|>
You are a proactive engineering sidekick that strictly answers questions based securely on the provided offline textbook/note excerpts. Be concise and accurate.
<|user|>
STUDENT QUESTION: ${query}

CONTEXT:
${ctx}
<|assistant|>
`;
  const out = await generator(prompt, {
    max_new_tokens: 150,
    temperature: 0.1,
    repetition_penalty: 1.1,
    do_sample: false, // greedy
  });
  
  // Clean up output string to only return assistant's reply
  const generatedText = out[0].generated_text as string;
  const assistantPart = generatedText.split('<|assistant|>\n')[1] || generatedText;
  return assistantPart.trim();
}
