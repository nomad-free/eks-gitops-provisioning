const pool = require("../config/db");

exports.initTable = async () => {
  const query = `
    CREATE TABLE IF NOT EXISTS settlements (
      id SERIAL PRIMARY KEY,
      market_pair VARCHAR(20) NOT NULL,
      amount NUMERIC(20, 8) NOT NULL,
      price NUMERIC(20, 2) NOT NULL,
      sensitive_memo TEXT, -- 암호화되어 저장될 필드
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    );
  `;
  const client = await pool.connect();
  try {
    await client.query(query);
    console.log("✅ Settlement Table Verified");
  } finally {
    client.release();
  }
};

exports.create = async (data) => {
  const query = `
    INSERT INTO settlements(market_pair, amount, price, sensitive_memo) 
    VALUES($1, $2, $3, $4) RETURNING *
  `;
  const values = [
    data.market_pair,
    data.amount,
    data.price,
    data.sensitive_memo,
  ];
  const res = await pool.query(query, values);
  return res.rows[0];
};

exports.findLatest = async (limit = 10) => {
  const res = await pool.query(
    "SELECT * FROM settlements ORDER BY created_at DESC LIMIT $1",
    [limit],
  );
  return res.rows;
};

exports.ping = async () => {
  await pool.query("SELECT 1");
};
