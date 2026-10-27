# Stage 1: Build Java application
FROM maven:3.9-eclipse-temurin-21 AS build

WORKDIR /build

COPY pom.xml .
COPY common/pom.xml common/pom.xml
COPY ec2-app/pom.xml ec2-app/pom.xml
COPY lambda-app/pom.xml lambda-app/pom.xml

COPY common/src common/src
COPY ec2-app/src ec2-app/src

RUN mvn -B -pl ec2-app -am -DskipTests package


# Stage 2: Minimal Java runtime
FROM eclipse-temurin:21-jre

WORKDIR /app

# Run application as non-root user
USER 10001:10001

# Copy executable JAR
COPY --from=build --chown=10001:10001 \
    /build/ec2-app/target/ec2-app-1.0-SNAPSHOT.jar \
    /app/application.jar

# Application configuration
ENV HOST=0.0.0.0
ENV PORT=8080
ENV AWS_REGION=eu-west-1
ENV TABLE_NAME=ATU-Three-Tier-messages

EXPOSE 8080

ENTRYPOINT ["java", "-jar", "/app/application.jar"]