# Open Agent Connector web console (Next.js) + Caddy front door, built from upstream commit 3cde269.
FROM caddy:2.11.9-alpine@sha256:003a97808e781aa9f7e75cc2f43d34d461099031faf5e20faefb9f61126836f0 AS caddy

FROM node:24.22.3-alpine@sha256:116b800c3754b440ee0aa3ed2f20f5bf3d99a554bfd9adeea09ea8017f6e85f5 AS builder
ARG OAC_COMMIT=3cde26911964ebbd4b7cb6206535b8629aa2a7ce
WORKDIR /src
RUN wget -qO- "https://codeload.github.com/Anil-matcha/open-agent-connector/tar.gz/${OAC_COMMIT}" \
      | tar xz --strip-components=2 "open-agent-connector-${OAC_COMMIT}/client"
# Exact dependency versions resolved from upstream's package.json on 2026-11-24 (upstream ships no lockfile).
COPY package-lock.json ./package-lock.json
# An empty public URL must mean "same origin" (Caddy serves the API on the same domain), not localhost.
RUN grep -q 'process.env.NEXT_PUBLIC_API_URL || "http://localhost:8000"' src/lib/api.ts \
 && sed -i 's#process.env.NEXT_PUBLIC_API_URL || "http://localhost:8000"#process.env.NEXT_PUBLIC_API_URL ?? ""#' src/lib/api.ts
RUN npm ci --no-audit --no-fund
# The browser's API base URL is baked in at build time. Build with a placeholder that the start
# script swaps for the deploy's public URL, so one image works on any domain.
ENV NEXT_PUBLIC_API_URL=__OAC_PUBLIC_ORIGIN__ \
    NEXT_TELEMETRY_DISABLED=1 \
    CIRCLE_NODE_TOTAL=2
RUN npm run build

FROM node:24.22.3-alpine@sha256:116b800c3754b440ee0aa3ed2f20f5bf3d99a554bfd9adeea09ea8017f6e85f5
ENV NODE_ENV=production NEXT_TELEMETRY_DISABLED=1
WORKDIR /opt/oac-web
COPY --from=builder /src/public ./public
COPY --from=builder /src/.next/standalone ./
COPY --from=builder /src/.next/static ./.next/static
COPY --from=caddy /usr/bin/caddy /usr/bin/caddy
COPY Caddyfile /etc/caddy/Caddyfile
COPY start.sh /usr/local/bin/oac-web
RUN chmod 755 /usr/local/bin/oac-web
ENV PORT=8080
EXPOSE 8080
CMD ["/usr/local/bin/oac-web"]
