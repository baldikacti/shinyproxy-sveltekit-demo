# syntax=docker/dockerfile:1.7
ARG NODE_VERSION=22

FROM --platform=$BUILDPLATFORM node:${NODE_VERSION}-alpine AS builder

WORKDIR /app

COPY package.json package-lock.json ./
RUN npm ci

COPY . .

# Built-in placeholder for `paths.base`; docker-entrypoint.sh swaps it for the sub-path ShinyProxy
# assigns to the session. Keep it in sync with BASE_PATH_PLACEHOLDER in the runtime stage.
ARG BASE_PATH_PLACEHOLDER=/__SHINYPROXY_PUBLIC_PATH__
ENV BASE_PATH=${BASE_PATH_PLACEHOLDER}
RUN npm run build


FROM node:${NODE_VERSION}-alpine AS runtime

WORKDIR /app

ARG BASE_PATH_PLACEHOLDER=/__SHINYPROXY_PUBLIC_PATH__
ENV BASE_PATH_PLACEHOLDER=${BASE_PATH_PLACEHOLDER} \
    NODE_ENV=production \
    HOST=0.0.0.0 \
    PORT=3000 \
    BODY_SIZE_LIMIT=10M

# adapter-node rejects cross-origin form posts (Sverdle uses them) unless it can work out its own
# origin. Behind ShinyProxy that has to come from the forwarded headers - or from ORIGIN, which you
# can set at deploy time to the public ShinyProxy URL.
ENV PROTOCOL_HEADER=x-forwarded-proto \
    HOST_HEADER=x-forwarded-host \
    ADDRESS_HEADER=x-forwarded-for \
    XFF_DEPTH=1

COPY --from=builder --chown=node:node /app/build ./build
COPY --chmod=755 docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh

USER node
EXPOSE 3000

ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["node", "build/index.js"]
