const settlementService = require("../services/settlementService");
const jwt = require("jsonwebtoken");
const config = require("../config");

// JWT 로그인 (테스트용 토큰 발급)
exports.login = (req, res) => {
  const { username } = req.body;
  if (!username) return res.status(400).json({ error: "Username required" });

  // 토큰 유효기간 1시간
  const token = jwt.sign(
    { username, role: "admin" },
    config.security.jwtSecret,
    { expiresIn: "1h" },
  );
  res.json({ success: true, token });
};

exports.createSettlement = async (req, res) => {
  try {
    const { market_pair, amount, price, memo } = req.body;
    if (!market_pair || !amount || !price) {
      return res.status(400).json({ error: "Missing required fields" });
    }

    const result = await settlementService.processSettlement({
      market_pair,
      amount,
      price,
      memo,
    });

    res.status(201).json({
      success: true,
      data: result,
      message: "Settlement processed (Data Encrypted)",
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

exports.getSettlements = async (req, res) => {
  try {
    const data = await settlementService.getRecentSettlements();
    res.json({ success: true, count: data.length, data });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};
