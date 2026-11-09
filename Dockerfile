FROM node:22-alpine
WORKDIR /app
ARG SOURCE_COMMIT=unpublished
ENV SOURCE_COMMIT=$SOURCE_COMMIT
ENV DUODECK_VERSION=1.1.0
ENV NODE_ENV=production
ENV PORT=3000
COPY apps/web/public ./public
COPY apps/web/server.mjs ./server.mjs
COPY apps/web/package.json ./package.json
USER node
EXPOSE 3000
HEALTHCHECK --interval=30s --timeout=3s --start-period=15s --retries=3 CMD node -e "fetch('http://127.0.0.1:3000/api/health').then(r=>process.exit(r.ok?0:1)).catch(()=>process.exit(1))"
CMD ["node","server.mjs"]
