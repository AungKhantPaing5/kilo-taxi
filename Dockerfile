FROM node:24-alpine
WORKDIR /app
ENV NODE_ENV=production DATA_DIR=/app/data PORT=8080
COPY --chown=node:node package.json server.mjs meter.mjs ./
COPY --chown=node:node public ./public
RUN mkdir -p /app/data && chown node:node /app/data
USER node
EXPOSE 8080
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s CMD node -e "fetch('http://127.0.0.1:8080/healthz').then(r=>process.exit(r.ok?0:1)).catch(()=>process.exit(1))"
CMD ["node","server.mjs"]
