const { Pool } = require("pg");
const config = require("./index");

const pool = new Pool({
  ...config.db,
  connectionTimeoutMillis: 5000,
});

module.exports = pool;
