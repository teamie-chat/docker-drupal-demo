## About

This image runs a Drupal site with the `t_chat` module enabled to demonstrate its features. The `Dockerfile` of this image can also be used to understand how the required environment for `t_chat` can be built.

## Installation

1. Pull this image from Docker Hub to your machine:

        docker pull amarnus/teamie-chat-demo

2. Run a container from this image:

        docker run -p "8080:80" -p "8888:8888" -d -v "/home/ubuntu/logs/apache:/var/log/apache"  amarnus/teamie-chat-demo

3. Navigate to `http://localhost:8080` and login with username `admin` and password `admin`. You can use the *Switch User* block on the right-hand side of the page to switch as a different user.
