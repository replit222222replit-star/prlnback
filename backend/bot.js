const TelegramBot = require('node-telegram-bot-api');
const { verifyCode } = require('./auth_store');

const BOT_TOKEN = process.env.TELEGRAM_BOT_TOKEN;

if (!BOT_TOKEN) {
  throw new Error('[bot] TELEGRAM_BOT_TOKEN is not defined');
}

const bot = new TelegramBot(BOT_TOKEN, { polling: true });

console.log('[bot] Telegram bot started (polling)');

// /start
bot.onText(/\/start/, (msg) => {
  bot.sendMessage(
    msg.chat.id,
    `👾 *NEO-GENESIS Auth Bot*\n\nОтправь мне код из приложения:\n\`/auth 482931\``,
    { parse_mode: 'Markdown' }
  );
});

// /auth <код>
bot.onText(/\/auth (.+)/, (msg, match) => {
  const code = match[1].trim();
  const telegramId = String(msg.from.id);

  const result = verifyCode(code, telegramId);

  if (result.success) {
    bot.sendMessage(
      msg.chat.id,
      `✅ *Авторизация успешна!*\n\nВозвращайся в приложение — оно уже подключилось.`,
      { parse_mode: 'Markdown' }
    );
  } else {
    bot.sendMessage(
      msg.chat.id,
      `❌ *Ошибка:* ${result.message}`,
      { parse_mode: 'Markdown' }
    );
  }
});

// Неизвестная команда
bot.on('message', (msg) => {
  if (msg.text && !msg.text.startsWith('/')) {
    bot.sendMessage(
      msg.chat.id,
      `Отправь код командой:\n\`/auth 482931\``,
      { parse_mode: 'Markdown' }
    );
  }
});

bot.on('polling_error', (err) => {
  console.error('[bot] Polling error:', err.message);
});

module.exports = bot;
