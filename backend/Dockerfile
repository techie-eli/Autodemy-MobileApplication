FROM node:18

# Create app directory
WORKDIR /usr/src/app

# Install app dependencies
COPY package*.json ./
RUN npm install --production

# Bundle app source
COPY . .

# Ensure the uploads directory exists
RUN mkdir -p uploads

# Cloud Run expects the app to listen on the port provided by the PORT environment variable (usually 8080)
# We set a default just in case
ENV PORT 8080
EXPOSE 8080

CMD [ "node", "server.js" ]
