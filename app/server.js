const app = require("./src/app");
const config = require("./src/config");
const { initTable } = require("./src/repositories/settlementRepository");

const startServer = async () => {
  try {
    await initTable();

    app.listen(config.port, () => {
      console.log(
        `🚀 Exchange Settlement Service running on port ${config.port}`,
      );
      console.log(`   Environment: ${config.env}`);
      console.log(`   Security: JWT & Encryption Enabled`);
    });
  } catch (err) {
    console.error("❌ Critical Error: Failed to initialize DB:", err);
    process.exit(1);
  }
};

startServer();
