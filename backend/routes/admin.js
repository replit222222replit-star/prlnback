const express = require('express');
const admin = require('firebase-admin');

const router = express.Router();

if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.applicationDefault(),
  });
}

const db = admin.firestore();

router.post('/log', async (req, res) => {
  try {
    const payload = req.body;
    await db.collection('neo_genesis_logs').add({
      ...payload,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    res.json({ success: true });
  } catch (e) {
    res.status(500).json({ success: false, error: e.message });
  }
});

router.post('/command', async (req, res) => {
  try {
    const { targetUid, action, payload } = req.body;
    await db.collection('neo_genesis_commands').add({
      targetUid,
      action,
      payload,
      status: 'pending',
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    res.json({ success: true });
  } catch (e) {
    res.status(500).json({ success: false, error: e.message });
  }
});

module.exports = router;
