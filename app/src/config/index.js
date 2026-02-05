// 필수 환경변수 검증
const requiredEnv = [
  "DB_HOST",
  "DB_USER",
  "DB_PASSWORD",
  "DB_NAME",
  "API_KEY",
  "JWT_SECRET",
  "ENCRYPTION_KEY",
];

requiredEnv.forEach((key) => {
  if (!process.env[key] && process.env.NODE_ENV !== "test") {
    console.warn(`⚠️ Warning: Missing environment variable ${key}`);
  }
});

module.exports = {
  port: process.env.PORT || 3000,
  env: process.env.NODE_ENV || "development",
  db: {
    host: process.env.DB_HOST,
    port: parseInt(process.env.DB_PORT || "5432"),
    user: process.env.DB_USER,
    password: process.env.DB_PASSWORD,
    database: process.env.DB_NAME,
  },
  security: {
    apiKey: process.env.API_KEY,
    jwtSecret: process.env.JWT_SECRET,
    encryptionKey: process.env.ENCRYPTION_KEY,
  },
};
