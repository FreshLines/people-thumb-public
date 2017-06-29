require ('coffeescript/register');
var config = require('../config/config'),
    AWS = require('aws-sdk'),
    Promise = require("bluebird"),
    ImageQueue = Promise.promisifyAll(require('../app/services/image_queue'));
    
var running = false;

/*
*
* New Way to do sleep without blocking the main thead
*
*/  

function sleep(ms) {
  return new Promise(resolve => setTimeout(function() { dequeue(); }, ms));
}

async function dequeue() {
  if(!running) {
    try {
      running = true;
      console.log('executing');
      image_queue = new ImageQueue(config.input_queue);
      image_queue.dequeue(function(err,local_filename) {
        //do nothing
        if(err) {
          console.log(err);
        } else {
          console.log('successfully proccessed image ' + local_filename)  
        }
        running = false;
      });
      // setTimeout(function() { running = false; }, 8000);
    } catch (err) {
      console.log(err)
      running = false;
    }
  } else {
    console.log('not executing');  
  }
  await sleep(5000);
}

dequeue().catch(function(e) {
  console.log(e.stack);
  //best practice is to shut down the process due to memory leaks
  process.exit(1)
});


//Global catches for the workers. 

//If you don't catch this and you don't handle the rejection the worker runs forever, I would rather have it finish if someone screws up.
//deprecated as down the road it will stop the process but for now, we need this.
process.on('unhandledRejection', (err) => {
  console.error((new Date).toUTCString() + ' unhandledRejection:', err.message)
  console.error(err.stack)
  process.exit(1)
});
