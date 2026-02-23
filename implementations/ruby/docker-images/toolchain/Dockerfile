FROM ruby:3.4-slim-bookworm
COPY Gemfile* .
RUN gem install bundler && bundle install
WORKDIR /app
