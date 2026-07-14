FROM node:24-alpine AS frontend-builder

WORKDIR /app/frontend

COPY frontend/package*.json ./
RUN npm ci

# Keep react-admin 5 on its compatible MUI major without modifying upstream manifests.
RUN npm install --no-save --package-lock=false \
    @mui/material@7.3.11 \
    @mui/icons-material@7.3.11

COPY frontend/ ./
RUN npm run build


FROM eclipse-temurin:21-jdk-alpine AS backend-builder

WORKDIR /app

COPY gradle ./gradle
COPY gradlew settings.gradle.kts build.gradle.kts versions.properties ./
RUN ./gradlew dependencies --no-daemon > /dev/null

COPY src ./src
COPY public ./public
COPY --from=frontend-builder /app/frontend/dist ./src/main/resources/static

RUN ./gradlew test --no-daemon
RUN ./gradlew bootJar --no-daemon


FROM eclipse-temurin:21-jre-alpine AS final

WORKDIR /app

RUN addgroup -S app && adduser -S app -G app

COPY --from=backend-builder /app/build/libs/*.jar app.jar

USER app

EXPOSE 8080
EXPOSE 9090

ENTRYPOINT ["sh", "-c", "java $JAVA_OPTS -jar /app/app.jar"]
