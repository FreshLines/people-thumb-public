require ('coffeescript/register');
var config = require('../config/config'),
    AWS = require('aws-sdk'),
    ImageFaceRecognition = require('../app/services/image_face_recognition'),
    Promise = require("bluebird");
    
ImageQueue = Promise.promisifyAll(require('../app/services/image_queue'));
    

console.log(config['env']);

// if we are in production we should use the IAM credentials from the server.
// Those should not need to be set.
// for development you will need to add your .aws/credentials file to the container
// docker cp ~/.aws/credentials development_web_1:/root/.aws/credentials
// Could also add an Add command to the dockerfile for development
if(config['env'] != 'production') {
    AWS.config.region = 'us-east-1';
    var credentials = new AWS.SharedIniFileCredentials({profile: 'default'});
    AWS.config.credentials = credentials;
}

// Create an SQS service object
var sqs = new AWS.SQS({apiVersion: '2012-11-05'});

var params = {};

sqs.listQueues(params, function(err, data) {
  if (err) {
    console.log("Error", err);
  } else {
    console.log(data);
    console.log("Success", data.QueueUrls);
  }
});


var params = {
  DelaySeconds: 10,
  MessageBody: "{\"source\": \"" + config.s3_input_file + "\", \"output\": \"" + config.s3_output_file + "\", \"outputQueue\": \"" + config.output_queue_name + "\"}",
  QueueUrl: config.input_queue
};

sqs.sendMessage(params, function(err, data) {
  if (err) {
    console.log("Error", err);
  } else {
    console.log("Send Success", data.MessageId);
  }
});