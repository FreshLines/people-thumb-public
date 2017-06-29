AmazonS3URI = require "amazon-s3-uri";
AWS = require "aws-sdk";
request = require "request";
Promise = require "bluebird";
fs = require('fs');
sizeOf = require 'image-size';
imagemagick = Promise.promisifyAll(require 'imagemagick',  {multiArgs:true})
util = require 'util'

module.exports = class ImageFaceRecognition
  @local_image_path = "/tmp/face_recognition_images"
  
  #
  # s3_uri - String - full url to s3 image
  #
  constructor: (s3_uri) ->
    # get the faces with Rekognize
    @s3_uri = new AmazonS3URI(s3_uri);
    @face_details = []

  #
  # Class Methods
  # 

  # Takes an image from s3 and downloads the file locally
  #
  # Image_url - String - Full url to s3 image
  # @return - Promise - If successful returns a new ImageFaceRecognition Object
  #
  @create_from_s3_url: (image_url) ->
    return new Promise( (resolve, reject) ->
      ImageFaceRecognition.download_image( image_url, (err,local_filename) ->
        reject(err) if err
        ifr = new ImageFaceRecognition(image_url)
        ifr.local_filename = local_filename

        resolve(ifr)
      )
    )
    

  # Downloads an s3 image to a local directory
  #
  # uri - full url to s3 image
  # callback - typical err, success callback
  # On Success of callback - returns the path to the local filename
  #
  @download_image: (uri, callback) ->
    timestamp = new Date().getTime() / 1000
    extension = uri.split('.').pop();
    local_filename = @local_image_path + '/img_' + timestamp + '.' + extension

    request(uri).pipe(fs.createWriteStream(local_filename)).on('finish', ->
      callback(null,local_filename)
    ).on('error', (e) ->
      callback(e,local_filename)
    )

  # Uploads a local file to s3
  #
  # uri - full url to s3 image
  # callback - typical err, success callback
  # On Success of callback - returns the path to the local filename
  #
  @upload_image: (s3_uri, local_filename, callback) ->
    # timestamp = new Date().getTime() / 1000
    # extension = local_filename.split('.').pop();
    # local_filename = @local_image_path + '/img_' + timestamp + '.' + extension
    s3 = new AWS.S3();
    s3_data = new AmazonS3URI(s3_uri);

    fs.readFile local_filename, 'binary', (err, data) ->

      callback(err,null) if err
      
      params = 
        Body: data
        Bucket: s3_data.bucket
        Key: s3_data.key
        ACL: 'public-read'
        Metadata: 
          'Content-Type': 'image/jpeg'
      s3.putObject params, (err, data) ->
        callback(err,null) if err
        callback(null,{ remote_filename: s3_uri, local_filename: local_filename })

  #
  #
  # Instance Methods
  #
  #


  # Finds the largest multiple of height or width that can be used
  # We use this to crop the image to the largest size possible
  #
  # dimensions - Object with width and height attributes
  # scaled_width - width you want to scale the image to
  # scaled_height - height you want to scale the image to
  # @return - Integer - largest multiple that can still stay within the height and width
  #
  find_scale_for_height_and_width: (dimensions,scaled_width,scaled_height) ->
    # example we want our image to be 300 x 300
    # how many times can 300 go into the height and width
    scale_w = Math.floor(dimensions.width / scaled_width)
    scale_y = Math.floor(dimensions.height / scaled_height)
    scale = if scale_w < scale_y then scale_w else scale_y
    return scale



  # Finds the center point of the faces in the image
  #
  # TODO: Find the center point of multiple faces
  # Dimenions - Object with height and width attribues for the dimensions of the image
  # @return - center point object with x and y attributes
  #
  find_center_point_of_faces: (dimensions) ->
    center_point_x = center_point_y = null
    # if @face_details.length == 1
    # we have to multiply by the width and height because BoundingBox coordinates are percentages
    center_point_x = @face_details[0].BoundingBox.Left * dimensions.width +  (@face_details[0].BoundingBox.Width  * dimensions.width / 2)
    center_point_y = @face_details[0].BoundingBox.Top  * dimensions.height +  (@face_details[0].BoundingBox.Height  * dimensions.height / 2)
    return { x: center_point_x, y: center_point_y }
    


  # We want to find the largest bounds on the image and resize to 300x300
  #
  # center_point - Object with x and y attributes - center point of the faces
  # scale - Integer - largest multiple that can still stay within the height and width
  # Dimenions - Object with height and width attribues for the dimensions of the image
  # scaled_width - Integer the width we want to scale the image too
  # scaled_height - Integer the height we want to scale the image too
  # @return - Object with top, right, bottom, and left attributes
  #
  find_largest_crop_bounds: (center_point, scale, dimensions ,scaled_width, scaled_height) ->
    half_width = scaled_width / 2;
    half_height = scaled_height / 2;

    # Lets see if our center point + (half the image width * scale) goes off the edge
    right_edge = center_point.x + (half_width * scale)
    left_edge = center_point.x - (half_width * scale)
    if right_edge > dimensions.width
      diff = right_edge - dimenions.width
      right_edge = dimensions.width
      left_edge = left_edge + diff
    else if left_edge < 0
      diff = 0 - left_edge
      left_edge = 0
      right_edge = right_edge + diff

    # Now lets get the top and the bottom edges
    top_edge = center_point.y - (half_height * scale)
    bottom_edge = center_point.y + (half_height * scale)

    if bottom_edge > dimensions.height
      diff = bottom_edge - dimenions.height
      bottom_edge = dimensions.height
      top_edge = top_edge + diff
    else if top_edge < 0
      diff = 0 - top_edge
      top_edge = 0
      bottom_edge = bottom_edge + diff

    return { top: top_edge, right: right_edge, bottom: bottom_edge, left: left_edge }


  # Actually Crop the image and scale to the new height and width
  #
  # bounding_box - Object with top, right, bottom, left attributes
  # scaled_width - Integer the width we want to scale the image too
  # scaled_height - Integer the height we want to scale the image too
  # Callback when finished, On success should return finished file path with filename
  #
  crop_and_scale: (bounding_box,scaled_width,scaled_height, callback) ->
    local_filename = @local_filename
    extension = local_filename.split('.').pop();

    # Now lets crop the image with the new dimensions and then scale it down to scaled_width x scaled_height
    crop_width = bounding_box.right - bounding_box.left
    crop_height = bounding_box.bottom - bounding_box.top
    crop_string_definition = crop_width + 'x' + crop_height + '+' + bounding_box.left + '+' + bounding_box.top
    cropped_filename = local_filename + '-cropped.' + extension
    scaled_filename = local_filename + '-scaled.' + extension

    # TODO: change this to just user convertAsync
    new Promise( (resolve, reject) ->
      imagemagick.convert( [local_filename, '-crop', crop_string_definition , cropped_filename], (err, stdout) ->
        reject(err) if (err)
        resolve(cropped_filename)
      );
    ).then( (cropped_filename) ->
      return imagemagick.convertAsync( [cropped_filename, '-resize', scaled_width + 'x' + scaled_height , scaled_filename] )
    ).then( (stdout) ->
      #Just showing another chain on a promise for testing
      callback(null,scaled_filename)
    ).catch( (err) ->
      callback( err, null)
    )

  #
  # Once an image is downloaded we will ultimately want to center on the faces 
  # and then crop to the thumbnail size
  # 
  # Callback - Typical promise err, success callback
  center_on_faces_and_crop: (scaled_width,scaled_height,callback) ->
    local_filename = @local_filename
    extension = local_filename.split('.').pop();

    dimensions = sizeOf(local_filename)


    scale = @find_scale_for_height_and_width(dimensions,scaled_width,scaled_height)

    center_point = @find_center_point_of_faces(dimensions)

    new_bounding_box = @find_largest_crop_bounds(center_point,scale, dimensions, scaled_width, scaled_height)

    @crop_and_scale(new_bounding_box, scaled_width, scaled_height, callback)
      
    

  # use Amazon Rekognition to find all the faces and return the data array
  # 
  # @return - Promise
  # On Success returns the face_details object
  find_faces: () ->   

    params = Image: S3Object:
      Bucket: @s3_uri.bucket,
      Name: @s3_uri.key

    # TODO:  Maybe move this to an instance variable if we need to use it later
    rekognition = new AWS.Rekognition({apiVersion: '2016-06-27'});

    _this = this
    
    return new Promise( (resolve, reject) ->
      rekognition.detectFaces params, (err, data) ->
        if err
          reject err
        else
          _this.face_details = data.FaceDetails
          resolve(_this.face_details);
    )


    

  

