const config = require("../config");
const jwt = require("jsonwebtoken");

// 1. API Key 인증 (서버 간 통신용)
exports.verifyApiKey = (req, res, next) => {
  // [삭제] 테스트 환경 스킵 로직 제거 (테스트에서도 인증을 검증해야 함)
  // if (config.env === 'test') return next();  <-- 이 줄 삭제!

  const clientKey = req.headers["x-api-key"];
  if (!clientKey || clientKey !== config.security.apiKey) {
    return res
      .status(401)
      .json({ error: "Unauthorized", message: "Invalid API Key" });
  }
  next();
};

// ... (verifyJwt 등 나머지는 그대로 유지)
// 2. JWT 인증 (관리자/유저용)
exports.verifyJwt = (req, res, next) => {
  const authHeader = req.headers["authorization"];
  const token = authHeader && authHeader.split(" ")[1]; // "Bearer TOKEN"

  if (!token)
    return res
      .status(401)
      .json({ error: "Unauthorized", message: "Token required" });

  jwt.verify(token, config.security.jwtSecret, (err, user) => {
    if (err)
      return res
        .status(403)
        .json({ error: "Forbidden", message: "Invalid Token" });
    req.user = user;
    next();
  });
};
