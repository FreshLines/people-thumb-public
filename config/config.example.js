var path = require('path'),
    rootPath = path.normalize(__dirname + '/..'),
    env = process.env.NODE_ENV || 'development';

var config = {
  development: {
    root: rootPath,
    app: {
      name: 'people-thumb'
    },
    port: process.env.PORT || 3000,
    input_queue: "https://sqs.us-east-1.amazonaws.com/q383938383/test-queue",
    queue_prefix: "https://sqs.us-east-1.amazonaws.com/q383938383/",
    s3_input_file: "https://s3.amazonaws.com/test-bucket/IMG_1134.JPG",
    s3_output_file: "s3://test-bucket/IMG_1134-scaled.JPG",
    output_queue_name: "test-output-queue"
  },

  test: {
    root: rootPath,
    app: {
      name: 'people-thumb'
    },
    port: process.env.PORT || 3000,
    input_queue: "https://sqs.us-east-1.amazonaws.com/q383938383/test-queue",
    queue_prefix: "https://sqs.us-east-1.amazonaws.com/q383938383/",
    s3_input_file: "https://s3.amazonaws.com/test-bucket/IMG_1134.JPG",
    s3_output_file: "s3://test-bucket/IMG_1134-scaled.JPG",
    output_queue_name: "test-output-queue"
  },

  production: {
    root: rootPath,
    app: {
      name: 'people-thumb'
    },
    port: process.env.PORT || 3000,
  }
};

module.exports = config[env];
