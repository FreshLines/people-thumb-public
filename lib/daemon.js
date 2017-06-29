const cluster = require('cluster');
require ('coffeescript/register');
var config = require('../config/config'),
    AWS = require('aws-sdk'),
    Promise = require("bluebird"),
    ImageQueue = Promise.promisifyAll(require('../app/services/image_queue'));
// const http = require('http');
const numCPUs = require('os').cpus().length;

if (cluster.isMaster) {
  console.log(`Master ${process.pid} is running`);

  // Fork workers.
  for (let i = 0; i < numCPUs; i++) {
    worker = cluster.fork();
  }

  cluster.on('exit', (worker, code, signal) => {
    console.log(`worker ${worker.process.pid} died`);
    cluster.fork();
  });
} else {

  var running = false
    
  function sleep(ms) {
    return new Promise(resolve => setTimeout(function() { dequeue(); }, ms));
  }

  async function dequeue() {
    if(!running) {
      try {
        running = true;
        image_queue = new ImageQueue(config.input_queue);
        image_queue.dequeue(function(err,local_filename) {
          //do nothing
          if(err) {
            console.log(process.pid + ' ', err);
          } else {
            console.log(process.pid + ' ', 'successfully proccessed image ' + local_filename)  
          }
          running = false;
        });
      } catch (err) {
        console.log(process.pid + ' ', err)
        running = false;
      }
    } else {
      console.log(process.pid + ' ', 'not executing');  
    }
    //uncomment this if you want to force an error in the worker to make sure it's handling the error properly
    // myError = new Error('stopping on purpose');
    // throw myError
    await sleep(5000);
  }
  dequeue().catch(function(e) {
    console.log(e.stack);
    //best practice is to shut down the process due to memory leaks
    process.exit(1)
  });
  
  console.log(`Worker ${process.pid} started`);
}

//Global catches for the workers. 

//If you don't catch this and you don't handle the rejection the worker runs forever, I would rather have it finish if someone screws up.
//deprecated as down the road it will stop the process but for now, we need this.
process.on('unhandledRejection', (err) => {
  console.error((new Date).toUTCString() + ' unhandledRejection:', err.message)
  console.error(err.stack)
  process.exit(1)
});

