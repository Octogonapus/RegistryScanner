FROM node:18-alpine AS builder
RUN mkdir /app
COPY src /app/src
COPY .npmrc /app/.npmrc
COPY package-lock.json /app/package-lock.json
COPY package.json /app/package.json
COPY postcss.config.cjs /app/postcss.config.cjs
COPY svelte.config.js /app/svelte.config.js
COPY tailwind.config.cjs /app/tailwind.config.cjs
COPY tsconfig.json /app/tsconfig.json
COPY vite.config.ts /app/vite.config.ts
WORKDIR /app
RUN npm ci && npm run build

FROM node:18-alpine
RUN apk add --no-cache tzdata
RUN mkdir /app
COPY --from=builder /app/build /app/build
COPY --from=builder /app/package.json /app/package-lock.json /app/
WORKDIR /app
RUN npm ci
CMD ["node", "build/index.js"]
