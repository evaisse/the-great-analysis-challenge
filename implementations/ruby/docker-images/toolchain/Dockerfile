FROM ruby:3.4-bookworm
COPY Gemfile Gemfile.lock ./
RUN gem install bundler && bundle install
WORKDIR /app
