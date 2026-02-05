const settlementRepo = require("../repositories/settlementRepository");
const { encrypt, decrypt } = require("../utils/crypto");

exports.processSettlement = async (data) => {
  if (data.amount <= 0 || data.price <= 0) {
    throw new Error("Invalid data: Amount and Price must be positive");
  }

  // [보안] 민감한 메모 필드는 암호화하여 저장
  const encryptedMemo = encrypt(data.memo || "No memo");

  const savedData = await settlementRepo.create({
    ...data,
    sensitive_memo: encryptedMemo,
  });

  // 응답 시에는 복호화된 값을 보여줌 (검증용)
  return {
    ...savedData,
    decrypted_memo: data.memo, // 원본 값 반환
  };
};

exports.getRecentSettlements = async () => {
  const rows = await settlementRepo.findLatest();
  // 조회 시 암호화된 필드를 복호화
  return rows.map((row) => ({
    ...row,
    decrypted_memo: decrypt(row.sensitive_memo),
  }));
};
