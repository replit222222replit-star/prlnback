const express = require('express');
const router = express.Router();
const { requestCode, getSessionStatus } = require('../auth_store');

// POST /auth/request-code
// Приложение запрашивает одноразовый код
router.post('/request-code', (req, res) => {
  const { sessionId, code } = requestCode();
  res.json({ success: true, sessionId, code });
});

// GET /auth/status/:sessionId
// Приложение поллит этот endpoint каждые 2 сек
router.get('/status/:sessionId', (req, res) => {
  const result = getSessionStatus(req.params.sessionId);
  res.json(result);
});

module.exports = router;
