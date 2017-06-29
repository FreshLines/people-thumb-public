# People Thumb

This demo reads an s3 url of an image from an amazon SQS queue.  It then downloads and processes the image to find the faces in the image using Amazon Rekognize.  Once the faces are found, it centers on the face and then crops the largest possible image and then scales it down to a 300 x 300 size image.  After cropping and scaling it uploads the image to s3 and sends the data to another queue for processing. Enjoy!


## Critical Files

* Look in the app/services folder for the two main processing wrappers
* Our daemons can be found in the lib folder
* Our integration test can be found in test/lib


## Coffeescript

We use examples of coffescript and javascript throughout.  Look for coffeescript in our app/services folder and test/lib folder.  The vanilla javascript can be found in the lib folder.

## Docker

We have a couple Docker files in this demo.  One for running a development environment and one for production.  Please look to the docker folders for those.

## Setup Development Environment

* git clone git@github.com:FreshLines/people-thumb-public.git

* cd people-thumb-public

* Copy the example docker compose file and change the local path in volumes to the root of your project

	* cp ./docker/development/docker-compose.yml.example ./docker/development/docker-compose.yml
    * vim ./docker/development/docker-compose.yml

* docker-compose --file ./docker/development/docker-compose.yml up
* Note: if on mac you may need to open the docker app and add your directory to the file sharing in preferences

* Lets add our credentials to the dockerfile
	* Note, you don't need to do this for the test
	* ALSO, DO NOT BUILD YOUR DOCKER IMAGE ONCE YOU HAVE ADDED THIS FILE
	* TODO:  Make this a shared folder in the image.
	* docker cp ~/.aws/credentials development_web_1:/root/.aws/credentials

* Need to make the tmp directory for the files to run
	* docker exec -it development_web_1 bash
	* mkdir /tmp/face_recognition_images
    * TODO: Add this in the Dockerfile

## Running test
* docker exec -it development_web_1 bash
* npm test

## Daemons!!

	For an example we made 3 daemons:
		
		1) A simpled daemon at lib/peoplethumb.js
		2) A Cluster with Monitor at lib/daemon.js
		3) A Cluster, with Domain and Monitor at lib/domain.js

## Running the Simple Daemon
* docker exec -it development_web_1 bash
* npm start
* You can add a message the queue with the enqueue.js file
	* node lib/enqueue.js
* You will need to modify the config in order to use your own queues and s3 buckets.  Please change the following values:
   * input_queue: - full url for the input queue
   * queue_prefix: - prefix to your companies set of queues.  Full url except the queue_name with trailing slash
   * s3_input_file: - The file you want to read from s3
   * s3_output_file: - The fil you want to write to s3
   * output_queue_name: - The queue name you want to write to once the image has been processed.

## Running the Cluster with Monitor at lib/daemon.js
* docker exec -it development_web_1 bash
* forever start -o out.log -e err.log lib/daemon.js
* You can add a message to the queue with the enqueue.js file
	* node lib/enqueue.js
* You will need to modify the config in order to use your own queues and s3 buckets.  Please change the following values:
   * input_queue: - full url for the input queue
   * queue_prefix: - prefix to your companies set of queues.  Full url except the queue_name with trailing slash
   * s3_input_file: - The file you want to read from s3
   * s3_output_file: - The fil you want to write to s3
   * output_queue_name: - The queue name you want to write to once the image has been processed.


## Running the Cluster with Damain and Monitor at lib/domain.js
* docker exec -it development_web_1 bash
* forever start -o out.log -e err.log lib/domain.js
* You can add a message the queue with the enqueue.js file
	* node lib/enqueue.js
* You will need to modify the config in order to use your own queues and s3 buckets.  Please change the following values:
   * input_queue: - full url for the input queue
   * queue_prefix: - prefix to your companies set of queues.  Full url except the queue_name with trailing slash
   * s3_input_file: - The file you want to read from s3
   * s3_output_file: - The fil you want to write to s3
   * output_queue_name: - The queue name you want to write to once the image has been processed.


## Building Production container
* cd <project-root-folder> 
* docker build -f docker/production/Dockerfile -t people-thumb:0.0.1 . 







