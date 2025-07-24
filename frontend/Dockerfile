# Build Stage
FROM node:24-alpine as builder
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run build

# Runtime Stage
FROM node:24-alpine AS runner
RUN apk add --no-cache curl
WORKDIR /app
ENV NODE_ENV=production

# Si usas imágenes o archivos estáticos públicos
COPY --from=builder /app/public ./public
COPY --from=builder /app/.next ./.next
COPY --from=builder /app/package*.json ./

RUN npm ci --omit=dev
EXPOSE 3000
CMD ["npm", "start"]