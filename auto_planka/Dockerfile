FROM ruby:alpine

# throw errors if Gemfile has been modified since Gemfile.lock
# RUN bundle config --global frozen 1

WORKDIR /app

RUN apk add --update --no-cache \
    build-base \
    postgresql-dev \
    postgresql-client \
    tzdata \
    file

COPY ./app/Gemfile ./app/Gemfile.lock .
RUN bundle install

COPY ./app .

ENTRYPOINT bundle exec ./auto_planka.rb
