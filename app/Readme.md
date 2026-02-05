개발자가 로컬 환경에서 **Exchange Settlement Service**를 처음부터 끝까지 테스트하는 **단계별 가이드**입니다.

새로 변경된 구조(MVC 패턴, DB 연결, 보안 적용)에 맞춰, **의존성 설치**부터 **DB 실행**, **자동화 테스트**, **API 수동 검증**까지의 순서입니다.

---

### 1단계: 프로젝트 준비 및 의존성 설치

가장 먼저 프로젝트 폴더로 이동하여 필요한 라이브러리(`express`, `pg`, `jsonwebtoken` 등)를 설치합니다.

```bash
# 1. app 폴더로 이동
cd app

# 2. 의존성 설치
npm install

```

---

### 2단계: 로컬 데이터베이스 실행 (Docker)

이 서비스는 시작할 때 DB 연결을 시도(`initTable`)하므로, 로컬에 PostgreSQL이 실행되어 있어야 합니다. Docker를 사용하면 가장 간편합니다.

```bash
# Docker로 PostgreSQL 실행 (비밀번호: mysecretpassword, DB명: exchange)
docker run --name local-postgres \
  -e POSTGRES_PASSWORD=mysecretpassword \
  -e POSTGRES_DB=exchange \
  -p 5432:5432 \
  -d postgres

```

> **참고:** Docker가 없다면 로컬에 설치된 PostgreSQL을 사용해도 되며, 접속 정보만 아래 환경변수 설정 단계에서 맞춰주면 됩니다.

---

### 3단계: 자동화 테스트 실행 (Unit Test)

서버를 직접 켜지 않고도 비즈니스 로직을 검증할 수 있는 `Jest` 테스트를 먼저 돌려봅니다. (Mocking을 사용하므로 DB가 없어도 통과해야 정상입니다.)

```bash
npm test

```

- **결과 확인:** `POST /settlements`, `JWT Auth` 등의 테스트 케이스가 모두 `PASS` 뜨는지 확인합니다.

---

### 4단계: 환경변수 설정 및 서버 실행

이제 실제 서버를 켜서 로컬 DB와 연결합니다. 코드(`src/config/index.js`)에서 요구하는 환경변수들을 설정하고 실행해야 합니다.

**Mac / Linux (터미널)**

```bash
# 1. 환경변수 설정 (한 줄씩 입력하거나 복사해서 붙여넣기)
export DB_HOST=localhost
export DB_PORT=5432
export DB_USER=postgres
export DB_PASSWORD=mysecretpassword
export DB_NAME=exchange
export API_KEY=local-dev-api-key
export JWT_SECRET=local-jwt-secret
export ENCRYPTION_KEY=12345678901234567890123456789012  # 32글자 필수

# 2. 서버 실행
npm start

```

_(Windows PowerShell의 경우 `export` 대신 `$env:DB_HOST="localhost"` 형식 사용)_

성공 시 로그:

> `🚀 Exchange Settlement Service running on port 3000`
> `Security: JWT & Encryption Enabled`
> `✅ Settlement Table Verified`

---

### 5단계: API 수동 테스트 (Curl)

서버가 켜져 있는 상태에서, **새 터미널**을 열고 `curl` 명령어로 주요 기능(인증, 암호화, 저장)을 테스트합니다.

#### 1. 헬스 체크 (DB 연결 확인)

```bash
curl http://localhost:3000/api/v1/health
# {"status":"healthy", "db":"connected", ...}

```

#### 2. 관리자 로그인 (JWT 토큰 발급)

조회 API를 쓰려면 토큰이 필요합니다.

```bash
curl -X POST http://localhost:3000/api/v1/login \
  -H "Content-Type: application/json" \
  -d '{"username": "admin"}'

# 응답의 "token" 값을 복사해두세요!
# 예: eyJhbGciOiJIUzI1NiIsInR5cCI...

```

#### 3. 청산 데이터 생성 (API Key 인증 + 암호화 저장)

`API_KEY`가 맞아야 저장되며, `memo` 필드는 암호화되어 DB에 들어갑니다.

```bash
curl -X POST http://localhost:3000/api/v1/settlements \
  -H "Content-Type: application/json" \
  -H "x-api-key: local-dev-api-key" \
  -d '{
    "market_pair": "KRW-BTC",
    "amount": 1.5,
    "price": 50000000,
    "memo": "Secret Big Deal"
  }'

```

#### 4. 청산 데이터 조회 (JWT 인증 + 복호화 확인)

위에서 발급받은 **JWT 토큰**을 헤더에 넣고 조회합니다.

```bash
# TOKEN 부분에 실제 토큰을 넣으세요
curl http://localhost:3000/api/v1/settlements \
  -H "Authorization: Bearer <TOKEN>"

```

- **확인 포인트:** 응답 데이터 중 `decrypted_memo`에 `"Secret Big Deal"`이 제대로 복호화되어 보이는지 확인합니다.

---

### 💡 요약

1. `npm install` (최초 1회)
2. `docker run ... postgres` (DB 준비)
3. `npm test` (로직 검증)
4. `export ...` & `npm start` (서버 구동)
5. `curl` (API 동작 확인)
