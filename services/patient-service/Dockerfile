FROM node:18-alpine

# Create app directory
WORKDIR /usr/src/app

# Install app dependencies
COPY package*.json ./

# Configure npm to bypass SSL verification
RUN npm config set strict-ssl false
RUN npm config set registry http://registry.npmjs.org/

RUN if [ -f package-lock.json ]; then \
      npm ci --omit=dev --no-audit --no-fund && npm cache clean --force; \
    else \
      npm install --only=production --no-audit --no-fund --timeout=300000 && npm cache clean --force; \
    fi

# Create non-root user
RUN addgroup -g 1001 -S nodejs
RUN adduser -S nextjs -u 1001

# Copy app source
COPY --chown=nextjs:nodejs . .

# Switch to non-root user
USER nextjs

# Expose port
EXPOSE 3001

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD node healthcheck.js || exit 1

# Start the application
CMD ["node", "app.js"]