FROM node:20 AS base

# Build the project to generate the .wasp/build output
FROM base AS wasp-builder
WORKDIR /wasp
ADD . .
RUN curl -sSL https://get.wasp-lang.dev/installer.sh | sh
RUN /root/.local/bin/wasp build

# Build the server
FROM base AS server-builder
RUN apt update && apt install --yes build-essential python3 libtool autoconf automake && rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY --from=wasp-builder /wasp/.wasp/build/src ./src
COPY --from=wasp-builder /wasp/.wasp/build/package.json .
COPY --from=wasp-builder /wasp/.wasp/build/package-lock.json .
COPY --from=wasp-builder /wasp/.wasp/build/server .wasp/build/server
COPY --from=wasp-builder /wasp/.wasp/build/sdk .wasp/out/sdk
# Install npm packages, resulting in node_modules/.
RUN npm install && cd .wasp/build/server && npm install
COPY --from=wasp-builder /wasp/.wasp/build/db/schema.prisma .wasp/build/db/
RUN cd .wasp/build/server && npx prisma generate --schema='../db/schema.prisma'
# Building the server should come after Prisma generation.
RUN cd .wasp/build/server && npm run bundle

# Build the web app
FROM wasp-builder AS web-app-builder
ARG REACT_APP_API_URL
ENV REACT_APP_API_URL=$REACT_APP_API_URL
RUN npm ci
WORKDIR /wasp/.wasp/build/web-app
RUN npm ci && REACT_APP_API_URL=$REACT_APP_API_URL npm run build

# Run the server component
FROM base AS server-production
RUN apt update && apt install --yes python3 && rm -rf /var/lib/apt/lists/*
ENV NODE_ENV production
WORKDIR /app
COPY --from=server-builder /app/node_modules ./node_modules
COPY --from=server-builder /app/.wasp/out/sdk .wasp/out/sdk
COPY --from=server-builder /app/.wasp/build/server/node_modules .wasp/build/server/node_modules
COPY --from=server-builder /app/.wasp/build/server/bundle .wasp/build/server/bundle
COPY --from=server-builder /app/.wasp/build/server/package*.json .wasp/build/server/
COPY --from=server-builder /app/.wasp/build/server/scripts .wasp/build/server/scripts
COPY --from=wasp-builder /wasp/.wasp/build/db/ .wasp/build/db/
EXPOSE ${PORT}
WORKDIR /app/.wasp/build/server
ENTRYPOINT ["npm", "run", "start-production"]

# Run the web-app
FROM joseluisq/static-web-server AS web-app-production
ARG PORT
ENV SERVER_PORT=$PORT
COPY --from=web-app-builder /wasp/.wasp/build/web-app/build /public
