# Use an official Node.js runtime as a parent image
FROM node:18-slim

# Set the working directory in the container
WORKDIR /usr/src/app

# Install trusted root CAs for outbound HTTPS requests from Go binaries
RUN apt-get update && apt-get install -y ca-certificates

# Copy package.json and package-lock.json
COPY package*.json ./

# Install app dependencies
RUN npm ci --only=production

# Copy source code and binaries
COPY src/ ./src/
COPY bin/ ./bin/

# The provided binaries might need execute permissions.
RUN chmod +x /usr/src/app/bin/*

# Your app runs on port 3000
EXPOSE 3000

# Define the command to run your app
CMD [ "node", "src/000.js" ]