FROM node:20-alpine AS build

WORKDIR /app

COPY package*.json .

RUN npm ci --only=production

RUN npm cache clean --force

COPY . .


FROM node:20-alpine

RUN addgroup js && adduser -G js -S nodejs

WORKDIR /app

COPY --from=build /app /app

USER nodejs

EXPOSE 3500

CMD ["node", "server.js"]
