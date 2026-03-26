FROM oven/bun:1-alpine

RUN apk add --no-cache jemalloc
ENV LD_PRELOAD=/usr/lib/libjemalloc.so.2

WORKDIR /usr/src/app

COPY package.json bun.lock ./
COPY patches ./patches

RUN bun install --frozen-lockfile --production

COPY . .

RUN mkdir -p logs media

EXPOSE 3025

CMD ["bun", "src/index.ts"]
