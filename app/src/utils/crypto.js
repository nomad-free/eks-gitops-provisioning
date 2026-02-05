const crypto = require("crypto");
const config = require("../config");

// AES-256-CBC 암호화 설정
const ALGORITHM = "aes-256-cbc";
const IV_LENGTH = 16;
// 키 길이가 32바이트가 안되면 강제로 맞춤 (테스트용 안전장치)
const KEY = crypto.scryptSync(
  config.security.encryptionKey || "secret",
  "salt",
  32,
);

exports.encrypt = (text) => {
  if (!text) return null;
  try {
    const iv = crypto.randomBytes(IV_LENGTH);
    const cipher = crypto.createCipheriv(ALGORITHM, KEY, iv);
    let encrypted = cipher.update(text);
    encrypted = Buffer.concat([encrypted, cipher.final()]);
    return iv.toString("hex") + ":" + encrypted.toString("hex");
  } catch (e) {
    console.error("Encryption Error:", e.message);
    throw new Error("Encryption failed");
  }
};

exports.decrypt = (text) => {
  if (!text) return null;
  try {
    const textParts = text.split(":");
    const iv = Buffer.from(textParts.shift(), "hex");
    const encryptedText = Buffer.from(textParts.join(":"), "hex");
    const decipher = crypto.createDecipheriv(ALGORITHM, KEY, iv);
    let decrypted = decipher.update(encryptedText);
    decrypted = Buffer.concat([decrypted, decipher.final()]);
    return decrypted.toString();
  } catch (e) {
    console.error("Decryption Error:", e.message);
    return "[Decryption Failed]";
  }
};
