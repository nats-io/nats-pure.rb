# Example Rails application for NATS Ruby client

This is a simple Rails application that demonstrates how to use NATS Ruby client withing Rails application.

Files of interest:

 - [`config/initializers/nats.rb`](./config/initializers/nats.rb) — initialization of the NATS client early using lazy connection.
 - [`app/controllers/test_controller.rb`](./app/controllers/test_controller.rb) — example of the controller.
 - [`bin/nats-listener`](./bin/nats-listener()) — example of the separate standalone process.

Main client features shown in the example:

 - Thread-safety and fork handling: it is totally fine to use “global” NATS client instance without any connection pooling.
 - Rails development mode code reloading and resource handling: no more server restarts on changes and leaked database connections.

A (somewhat artificial) distributed workflow:

 - User fills the form and submits it.
 - The form is broadcasted via NATS using “global” NATS client instantiated in the web application server “master” process, but usable in worker processes.
 - Special long running process (listener) subscribes to the broadcasted messages and saves them to the database.
 - User will eventually see saved messages on the page with the form.

## Installation

This app has a Docker-first configuration based one the [Ruby on Whales post](https://evilmartians.com/chronicles/ruby-on-whales-docker-for-ruby-rails-development).

You need:

- Docker installed. For MacOS just use [official app](https://docs.docker.com/engine/installation/mac/).

- [Dip](https://github.com/bibendi/dip) installed.

Run the following command to build images and provision the application:

```sh
dip provision
```

## Running

You can start Rails server along with AnyCable by running:

```sh
dip up web listener
```

Then go to [http://localhost:3000/](http://localhost:3000/) and see the application in action.
