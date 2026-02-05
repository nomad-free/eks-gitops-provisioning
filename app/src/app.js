const express = require("express");
const routes = require("./routes");
const app = express();

app.use(express.json());

app.use((req, res, next) => {
  if (process.env.NODE_ENV !== "test") {
    console.log(`[${new Date().toISOString()}] ${req.method} ${req.url}`);
  }
  next();
});

app.use("/api/v1", routes);

app.use((req, res) => {
  res.status(404).json({ error: "Endpoint not found" });
});

module.exports = app;
