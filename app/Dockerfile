# 1. 의존성 설치 단계 (Dependencies)
FROM node:22-alpine AS deps
WORKDIR /app

# 패키지 파일만 복사하여 캐시 효율 극대화
COPY package*.json ./

# 프로덕션 의존성만 설치하고 캐시 정리
RUN npm ci --only=production && \
    npm cache clean --force

# 2. 실행 단계 (Production)
FROM node:22-alpine AS production

# 보안을 위한 비루트(Non-root) 사용자 설정
RUN addgroup -g 1001 -S nodejs && \
    adduser -S nodejs -u 1001 -G nodejs

WORKDIR /app

# 임시 폴더 생성 및 권한 설정
RUN mkdir -p /app/tmp && \
    chown -R nodejs:nodejs /app

# 의존성 단계에서 설치한 node_modules 복사
COPY --from=deps --chown=nodejs:nodejs /app/node_modules ./node_modules

# [수정됨] 소스 코드 복사
# server.js(진입점)와 src 폴더(로직)를 복사합니다.
COPY --chown=nodejs:nodejs package.json ./
COPY --chown=nodejs:nodejs server.js ./
COPY --chown=nodejs:nodejs src ./src

# 사용자 전환
USER nodejs

# 환경 변수 설정
ENV NODE_ENV=production
ENV PORT=3000

EXPOSE 3000

# [수정됨] 헬스체크
# 라우터 설정이 /api/v1/health 로 변경되었으므로 경로를 수정합니다.
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost:3000/api/v1/health || exit 1

# 빌드 메타데이터 (Arguments & Labels)
ARG BUILD_DATE
ARG GIT_SHA
ARG VERSION

LABEL org.opencontainers.image.created="${BUILD_DATE}" \
      org.opencontainers.image.revision="${GIT_SHA}" \
      org.opencontainers.image.version="${VERSION}" \
      org.opencontainers.image.title="exchange-settlement-service" \
      org.opencontainers.image.description="Backend service for exchange settlements"

# [수정됨] 실행 명령어
CMD ["node", "server.js"]