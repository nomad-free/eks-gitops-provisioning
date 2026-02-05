/* app/.eslintrc.js */
module.exports = {
  env: {
    commonjs: true,
    es2021: true,
    node: true,
    jest: true, // 테스트 코드(Jest)용 환경 변수 인식
  },
  extends: "eslint:recommended",
  overrides: [],
  parserOptions: {
    ecmaVersion: "latest",
  },
  rules: {
    // 1. console.log 허용 (서버 로깅용)
    "no-console": "off",
    // 2. 사용하지 않는 변수는 경고(warn)로 처리 (에러 X)
    "no-unused-vars": "warn",
  },
};
