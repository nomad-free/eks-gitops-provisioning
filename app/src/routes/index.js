const router = require("express").Router();
const settlementController = require("../controllers/settlementController");
const { verifyApiKey, verifyJwt } = require("../middlewares/authMiddleware");
const settlementRepo = require("../repositories/settlementRepository");

// Public: Health Check
router.get("/health", async (req, res) => {
  try {
    await settlementRepo.ping();
    res.json({
      status: "healthy",
      db: "connected",
      service: "Exchange Settlement",
    });
  } catch (err) {
    res
      .status(500)
      .json({ status: "unhealthy", db: "disconnected", error: err.message });
  }
});

// Public: Login (JWT 발급 테스트)
router.post("/login", settlementController.login);

// Private: Settlements
// - POST: API Key 필요 (M2M)
// - GET: JWT Token 필요 (관리자 조회) -> 이렇게 분리하여 두 가지 인증 모두 테스트 가능
router.post(
  "/settlements",
  verifyApiKey,
  settlementController.createSettlement,
);
router.get("/settlements", verifyJwt, settlementController.getSettlements);

module.exports = router;
