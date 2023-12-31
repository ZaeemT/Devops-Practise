FROM node

RUN apt-get update -y


WORKDIR /App

COPY . .

RUN npm install
RUN npm run build-react

EXPOSE 3000

CMD ["node", "index.js"]