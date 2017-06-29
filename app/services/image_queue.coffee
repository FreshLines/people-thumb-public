config = require "../../config/config"

require "coffeescript/register"
Promise = require "bluebird"
# AWS = Promise.promisifyAll(require "aws-sdk")
AWS = require "aws-sdk"
AWS.config.setPromisesDependency(require('bluebird'));
ImageFaceRecognition = Promise.promisifyAll(require "./image_face_recognition")

#
#   
# ImageQueue - dequeues an item of an sqs queue and processes it
#
#

module.exports = class ImageQueue
  sqs = null
  queueURL = null

  # Builds an ImageQueue Object
  # Sets credentials for the aws-sdk
  # and creates a new queue as an instance variable
  #
  # queueUrl - String - url for the amazon SQS queue to be read
  constructor: (queueUrl) -> 
    queueURL = queueUrl
    if config['env'] != 'production'
      AWS.config.region = 'us-east-1'
      credentials = new (AWS.SharedIniFileCredentials)(profile: 'default')
      AWS.config.credentials = credentials
    sqs = new AWS.SQS({apiVersion: '2012-11-05'});

  #
  # Class Methods
  #

  #
  # Instance Methods
  #
    

  # Dequeues an item off the queue
  # Then processes it for facial recognition
  #
  # Callback - function - Typical err, success promise callback
  # @return - nothing - use the callback
  dequeue: (callback) ->
    # TODO:  We should use long polling in the future
    params = 
      AttributeNames: [ 'SentTimestamp' ]
      MaxNumberOfMessages: 1
      MessageAttributeNames: [ 'All' ]
      QueueUrl: queueURL
      VisibilityTimeout: 0
      WaitTimeSeconds: 0
  
    _this = @

    sqs.receiveMessage(params).promise().then( (data) ->
      if data.Messages == undefined
        myError = new Error('Message from queue was blank');
        throw myError
      
      deleteParams = 
        QueueUrl: queueURL
        ReceiptHandle: data.Messages[0].ReceiptHandle
      
      # we used a new promise so we could keep passing the data through
      return new Promise( (resolve, reject) ->
        sqs.deleteMessage deleteParams, (err, delete_data) ->
          reject(err) if err
          resolve(data) # keep passing the data through
      )
    ).then( (data) ->
      if data.Messages != undefined
        @message = JSON.parse(data.Messages[0].Body)
        
        #
        # Main image Processing Section
        # 
        # Pass the callback through
        #
        _this.process_queue_message(@message, callback)
        
      else
        myError = new Error('Message from queue was blank');
        throw myError
    ).catch( (e) ->
      callback(e, null)
    )

  # Processes an image pulled from the queue and then fires it back to sqs
  # 
  # Message - Object - Contains message body from sqs
  #   source: source image that needs to be modified
  #   output: output image that you need to save
  #   outputQueue: queue name where we want to pass the moderation results }
  # Callback - Typical promise err, success callback
  #
  # @return - none - use the callback
  process_queue_message: (message, callback) ->
    # Read the image
    # process the image
    # write the new image to the new queue

    # We'll need to pass this between the promises.  
    # It will be an instance of ImageFaceRecognition
    _ifr = null
    _this = this

    ImageFaceRecognition.create_from_s3_url(message.source).then((ifr) ->
      # After we have the image downloaded, lets find the faces 
      _ifr = ifr
      _ifr.find_faces()
    ).then((face_data) ->
      # After we have found the faces, lets center and crop
      return new Promise( (resolve, reject) ->
        _ifr.center_on_faces_and_crop(300,300, (err,final_image) ->
          reject(err) if err
          resolve(final_image)
        )
      )
    ).then( (final_image) ->
      # Now that we have the final cropped image lets 
      # upload to s3 from the message url
      return new Promise (resolve, reject) ->
        ImageFaceRecognition.upload_image(message.output,final_image, (err,file_obj) ->
          reject(err) if err
          resolve(file_obj)
        )
    ).then( (file_obj) ->  
      # Now lets send it to the output queue

      output_message = {
        source: file_obj.remote_filename
        # TODO:  Add the moderation queue results here.
      }

      output_queue_url = config.queue_prefix + message.outputQueue

      _this.enqueue(output_queue_url, JSON.stringify(output_message), (err,data) ->
        callback(err,null) if err
        callback(null,file_obj.local_filename)
      )
      
    ).catch( (e) ->
      callback(e, null)
    )


  #
  # Sends a message to a queue specified by queue argument
  #
  # queue_url - String - url of the queue to send the message to
  # Message - String - The message body that will be added to the queue
  # Callback - Standard Promise err,success callback
  #
  # @returns null
  enqueue: (queue_url, message, callback) ->
      params = 
        MessageBody: message
        QueueUrl: queue_url

      sqs.sendMessage params, (err, data) ->
        if err
          callback(err,null)
        else
          callback(null,data)

