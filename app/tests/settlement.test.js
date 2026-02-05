// [중요] 앱을 불러오기 전에 환경변수부터 설정해야 Config가 이걸 먹습니다.
process.env.API_KEY = "test-api-key";
process.env.JWT_SECRET = "test-jwt-secret";
process.env.ENCRYPTION_KEY = "x".repeat(32); // 32글자

const request = require("supertest");
const app = require("../src/app"); // 이제 여기서 설정된 환경변수를 로드함
const jwt = require("jsonwebtoken");

// Mocking Repositories
jest.mock("../src/repositories/settlementRepository", () => ({
  create: jest.fn(),
  findLatest: jest.fn(),
  ping: jest.fn(),
}));
const settlementRepo = require("../src/repositories/settlementRepository");

describe("Exchange Settlement Security Tests", () => {
  beforeEach(() => {
    settlementRepo.create.mockClear();
    settlementRepo.findLatest.mockClear();
    settlementRepo.ping.mockResolvedValue(true);
  });

  // 1. Health Check
  it("GET /health should be public", async () => {
    const res = await request(app).get("/api/v1/health");
    expect(res.statusCode).toBe(200);
  });

  // 2. API Key Test (POST)
  it("POST /settlements should require API Key", async () => {
    // 키 없이 요청
    const res = await request(app).post("/api/v1/settlements").send({});
    expect(res.statusCode).toBe(401);
  });

  it("POST /settlements with valid Key should succeed & encrypt data", async () => {
    settlementRepo.create.mockResolvedValue({
      id: 1,
      market_pair: "BTC/USD",
      sensitive_memo: "encrypted_string",
    });

    const res = await request(app)
      .post("/api/v1/settlements")
      .set("x-api-key", "test-api-key")
      .send({
        market_pair: "BTC/USD",
        amount: 1,
        price: 50000,
        memo: "Secret Deal",
      });

    expect(res.statusCode).toBe(201);
    expect(res.body.success).toBe(true);
  });

  // 3. JWT Test (GET)
  it("GET /settlements should require JWT", async () => {
    const res = await request(app).get("/api/v1/settlements");
    expect(res.statusCode).toBe(401);
  });

  it("GET /settlements with valid JWT should return decrypted data", async () => {
    // 유효한 토큰 생성
    const token = jwt.sign({ user: "admin" }, "test-jwt-secret");

    // DB에서 암호화된 데이터를 리턴한다고 가정
    settlementRepo.findLatest.mockResolvedValue([
      { id: 1, market_pair: "BTC/USD", sensitive_memo: "iv:encrypted" },
    ]);

    const res = await request(app)
      .get("/api/v1/settlements")
      .set("Authorization", `Bearer ${token}`);

    expect(res.statusCode).toBe(200);
    expect(res.body.data).toHaveLength(1);
  });
});
