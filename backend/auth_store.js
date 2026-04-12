const jwt = require('jsonwebtoken');
const crypto = require('crypto');

const JWT_SECRET = process.env.JWT_SECRET || 'neo-genesis-secret';
const CODE_TTL_MS = 5 * 60 * 1000; // 5 минут

const ALLOWED_TELEGRAM_IDS = process.env.ALLOWED_TELEGRAM_IDS
  ? process.env.ALLOWED_TELEGRAM_IDS.split(',').map((id) => id.trim())
  : [];

// sessionId -> { code, status, telegramId, token, expiresAt }
const sessions = {};

function requestCode() {
  const sessionId = crypto.randomUUID();
  const code = Math.floor(100000 + Math.random() * 900000).toString();
  const expiresAt = Date.now() + CODE_TTL_MS;

  sessions[sessionId] = {
    code,
    status: 'pending',
    telegramId: null,
    token: null,
    expiresAt,
  };

  // Автоудаление через 5 минут
  setTimeout(() => {
    delete sessions[sessionId];
  }, CODE_TTL_MS);

  console.log(`[auth_store] New code=${code} sessionId=${sessionId}`);
  return { sessionId, code };
}

function verifyCode(code, telegramId) {
  const telegramIdStr = String(telegramId).trim();

  // Проверка whitelist
  if (
    ALLOWED_TELEGRAM_IDS.length > 0 &&
    !ALLOWED_TELEGRAM_IDS.includes(telegramIdStr)
  ) {
    console.warn(`[auth_store] Rejected telegramId=${telegramIdStr}`);
    return { success: false, message: 'Твой Telegram ID не в whitelist.' };
  }

  // Найти сессию по коду
  const entry = Object.entries(sessions).find(
    ([, s]) => s.code === code && s.status === 'pending'
  );

  if (!entry) {
    return { success: false, message: 'Неверный или истёкший код.' };
  }

  const [sessionId, session] = entry;

  if (Date.now() > session.expiresAt) {
    delete sessions[sessionId];
    return { success: false, message: 'Код истёк. Запроси новый в приложении.' };
  }

  const token = jwt.sign({ telegramId: telegramIdStr }, JWT_SECRET, {
    expiresIn: '24h',
  });

  session.status = 'authenticated';
  session.telegramId = telegramIdStr;
  session.token = token;

  console.log(`[auth_store] Authenticated telegramId=${telegramIdStr}`);
  return { success: true };
}

function getSessionStatus(sessionId) {
  const session = sessions[sessionId];
  if (!session) return { status: 'expired' };

  if (Date.now() > session.expiresAt && session.status === 'pending') {
    delete sessions[sessionId];
    return { status: 'expired' };
  }

  return {
    status: session.status,
    token: session.status === 'authenticated' ? session.token : null,
    telegramId: session.telegramId,
  };
}

module.exports = { requestCode, verifyCode, getSessionStatus };
