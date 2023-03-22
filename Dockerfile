FROM arm64v8/node AS deps

RUN apt-get -yqq install git
RUN git clone --depth 1 --single-branch --branch master https://github.com/mikecao/umami.git /app
WORKDIR /app
RUN yarn install --frozen-lockfile

###

FROM arm64v8/node AS builder

ARG DATABASE_TYPE
ARG BASE_PATH

RUN apt-get -yqq install git
RUN git clone --depth 1 --single-branch --branch master https://github.com/mikecao/umami.git /app

WORKDIR /app

COPY --from=deps /app/node_modules ./node_modules
COPY . .

ARG DATABASE_TYPE
ARG BASE_PATH

ENV DATABASE_TYPE $DATABASE_TYPE
ENV BASE_PATH $BASE_PATH

ENV NEXT_TELEMETRY_DISABLED 1

RUN yarn build-docker

# Production image, copy all the files and run next
FROM arm64v8/node AS runner 

ENV NODE_ENV production
ENV NEXT_TELEMETRY_DISABLED 1

RUN addgroup --system --gid 1001 nodejs
RUN adduser --system --uid 1001 nextjs

RUN yarn add npm-run-all dotenv prisma

# You only need to copy next.config.js if you are NOT using the default configuration
COPY --from=builder /app/next.config.js .
COPY --from=builder --chown=nextjs:nodejs /app/public ./public
COPY --from=builder /app/package.json ./package.json
COPY --from=builder /app/prisma ./prisma
COPY --from=builder /app/scripts ./scripts

# Automatically leverage output traces to reduce image size
# https://nextjs.org/docs/advanced-features/output-file-tracing
COPY --from=builder --chown=nextjs:nodejs /app/.next/standalone ./
COPY --from=builder --chown=nextjs:nodejs /app/.next/static ./.next/static

USER nextjs

EXPOSE 3000

ENV PORT 3000

CMD ["yarn", "start-docker"]

EXPOSE 3000
CMD ["yarn", "start"]
