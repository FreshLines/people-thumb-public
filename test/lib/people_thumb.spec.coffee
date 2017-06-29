config = require '../../config/config';

sinon = require 'sinon'
sinon_chai = require('sinon-chai')
chai = require('chai').use(require("sinon-chai"))
expect = chai.expect;
AWS = require 'aws-sdk-mock'
Promise = require 'bluebird'
fs = require('fs')
nock = require ('nock')
sizeOf = require 'image-size';
should = chai.should();



describe('People Thumb', () ->

  ImageFaceRecognition = require '../../app/services/image_face_recognition'
  ImageQueue = require '../../app/services/image_queue'
  mock_data_path = config.root + "/test/mock-data/lib/people_thumb"

  #  This function will run before every test to mock any api calls
  beforeEach( () ->
    this.timeout(15000);
    
    # We need to mock the sqs urls for both creation and deletion

    promise_1 = AWS.mock('SQS', 'receiveMessage', (params, callback) ->
      callback(null, JSON.parse(fs.readFileSync(mock_data_path + "/sqs_receiveMessage.json")) ) 
    )
  

    promise_2 = AWS.mock('SQS', 'deleteMessage', (params, callback) ->
      callback(null, JSON.parse(fs.readFileSync(mock_data_path + "/sqs_deleteMessage.json")) ) 
    )

    # Mock what comes from recognize AWS.Rekognition
    promise_3 = AWS.mock('Rekognition', 'detectFaces', (params, callback) ->
      callback(null, JSON.parse(fs.readFileSync(mock_data_path + "/rekognition_detectFaces.json")) );
    )

    promise_4 = AWS.mock('SQS', 'sendMessage', (params, callback) ->
      callback(null, JSON.parse(fs.readFileSync(mock_data_path + "/sqs_sendMessage.json")) ) 
    )

    promise_5 = AWS.mock('S3', 'putObject', (params, callback) ->
      callback(null, JSON.parse(fs.readFileSync(mock_data_path + "/s3_putObject.json")) ) 
    )


    #we need our tmp dir for our tests
    dir = "/tmp/face_recognition_images"
    if !fs.existsSync(dir)
      fs.mkdirSync(dir)

    # mock what gets returned from the s3 image https://s3.amazonaws.com/test-bucket/IMG_1134.JPG
    nock('https://s3.amazonaws.com')
    .get('/test-bucket/IMG_1134.JPG')
    .reply(200, fs.readFileSync(config.root + "/test/images/IMG_1134.JPG"));

    # What for all the promises to finish before continuing
    Promise.all([promise_1,promise_2,promise_3,promise_4,promise_5]).then( (values) ->
    )


  )


  describe('AWS Queue', ->


    # this pulls from the queue and calls process_image from within the dequeue method
    it('Dequeue should complete with success being true', () ->
      this.timeout(15000);

      # ImageQueue.prototype.restore();

      spy = sinon.spy(ImageQueue.prototype, "process_queue_message");  
      spy2 = sinon.spy(ImageFaceRecognition, "create_from_s3_url");
      spy3 = sinon.spy(ImageFaceRecognition.prototype, "center_on_faces_and_crop");
      spy4 = sinon.spy(ImageFaceRecognition, "upload_image");
      spy5 = sinon.spy(ImageQueue.prototype, "enqueue");  

      # TODO: Change the url below to be in the config.
      image_queue = new ImageQueue(config.input_queue)

      # Looking for feedback here
      # If you expect a promise and actually return via callback the error will not get caught
      # but no matter if the method resolves via callback or promise, 
      # wrapping it in a promise will handle any error
      new Promise (resolve,reject) ->
        results = image_queue.dequeue( (err,local_filename) ->

          console.log(err) if err

          spy.should.have.been.called;
          spy2.should.have.been.called;
          spy3.should.have.been.called;
          spy4.should.have.been.called;
          spy5.should.have.been.called;

          # expect(err).to.equal(null)
          expect(fs.existsSync(local_filename)).to.equal(true)

          dimensions = sizeOf(local_filename)

          expect(dimensions.height).to.equal(300)
          expect(dimensions.width).to.equal(300)

          spy.restore();
          spy2.restore();
          spy3.restore();
          spy4.restore();
          spy5.restore();
          
          resolve(true)
          
        )


    )
  )
)
