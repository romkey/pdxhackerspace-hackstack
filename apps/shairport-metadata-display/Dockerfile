FROM node:23-alpine

# Set the working directory in the container
WORKDIR /app

RUN apk add --update --no-cache git file imagemagick

RUN git clone https://github.com/AlainGourves/shairport-metadata-display .
RUN mkdir /app/public/img

#COPY package*.json ./

# Install Node.js dependencies
RUN npm install --omit=dev

# Copy the application source code to the container
COPY . .

# Expose the port if the application uses one (adjust as needed)
EXPOSE 8080

# Set the default command to run the application
CMD [ "npm", "start" ]
