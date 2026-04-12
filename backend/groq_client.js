const axios = require('axios');
const FormData = require('form-data');

const GROQ_API_KEY = process.env.GROQ_API_KEY;

if (!GROQ_API_KEY) {
  throw new Error('[groq_client] GROQ_API_KEY is not defined in environment');
}

const client = axios.create({
  baseURL: 'https://api.groq.com/openai/v1',
  headers: {
    Authorization: `Bearer ${GROQ_API_KEY}`,
    'Content-Type': 'application/json',
  },
  timeout: 30000,
});

/**
 * Обычный чат с текстом
 * @param {string} prompt
 * @returns {Promise<string>}
 */
async function createChatCompletion(prompt) {
  const response = await client.post('/chat/completions', {
    model: 'llama-3.3-70b-versatile',
    messages: [
      {
        role: 'system',
        content: 'Ты — нейро-ассистент NEO-GENESIS. Отвечай кратко и уверенно.',
      },
      { role: 'user', content: prompt },
    ],
    temperature: 0.85,
    max_tokens: 512,
  });
  return response.data;
}

/**
 * Анализ изображения (Vision)
 * imageBase64 — чистый base64 строкой без data:image/... префикса
 * @param {string} imageBase64
 * @returns {Promise<string>}
 */
async function analyzeVision(imageBase64) {
  // Groq Vision использует тот же /chat/completions endpoint,
  // но с content типа array (text + image_url)
  const response = await client.post('/chat/completions', {
    model: 'meta-llama/llama-4-scout-17b-16e-instruct',
    messages: [
      {
        role: 'user',
        content: [
          {
            type: 'text',
            text: 'Что сейчас на экране? Кратко опиши и найди интерактивные элементы.',
          },
          {
            type: 'image_url',
            image_url: {
              url: `data:image/jpeg;base64,${imageBase64}`,
            },
          },
        ],
      },
    ],
    max_tokens: 256,
    temperature: 0.5,
  });

  const choices = response.data?.choices;
  if (!choices || choices.length === 0) return 'No vision response';
  return choices[0]?.message?.content ?? 'No vision response';
}

/**
 * Транскрипция аудио через Whisper
 * audioBuffer — Buffer с аудио данными (wav/mp3)
 * @param {Buffer} audioBuffer
 * @param {string} [filename='audio.wav']
 * @returns {Promise<string>}
 */
async function transcribeAudio(audioBuffer, filename = 'audio.wav') {
  // Groq Whisper принимает multipart/form-data, НЕ JSON base64
  const form = new FormData();
  form.append('file', audioBuffer, {
    filename,
    contentType: filename.endsWith('.mp3') ? 'audio/mpeg' : 'audio/wav',
  });
  form.append('model', 'whisper-large-v3');
  form.append('language', 'ru');
  form.append('response_format', 'json');

  const response = await client.post('/audio/transcriptions', form, {
    headers: {
      ...form.getHeaders(),
      // Authorization уже в client defaults
    },
  });

  return response.data?.text ?? '';
}

module.exports = { createChatCompletion, analyzeVision, transcribeAudio };
