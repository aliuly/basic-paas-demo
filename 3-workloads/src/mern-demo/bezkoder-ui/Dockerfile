# Stage 1 — build React app
FROM node:16-alpine AS build-stage

WORKDIR /bezkoder-ui
COPY package.json .
RUN npm install
COPY . .

# Default to a relative path so the same image works behind any hostname.
# Override at build time only if you need an absolute URL.
ARG REACT_APP_API_BASE_URL=/api
ENV REACT_APP_API_BASE_URL=$REACT_APP_API_BASE_URL

RUN npm run build

# Stage 2 — serve static build with nginx
FROM nginx:alpine

COPY --from=build-stage /bezkoder-ui/build /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
