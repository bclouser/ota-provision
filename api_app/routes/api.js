var express = require('express');
var router = express.Router();
const request = require('request');
const { execFile } = require('child_process')



/*** Currently we are wrapping Andys API... His is already a wrapper so we are being lazy ***/

/* GET devices. */
router.get('/devices', function(req, res, next) {
    console.log("Calling api")
    // req('http://www.google.com', function (error, response, body) {
    //   console.log('error:', error); // Print the error if one occurred
    //   console.log('statusCode:', response && response.statusCode); // Print the response status code if a response was received
    //   console.log('body:', body); // Print the HTML for the Google homepage.
    // });
  // req('http://10.12.1.77/devices', { json: true }, (err, res, body){
  //   if (err) {
  //       console.log("got an error!")
  //       return console.log(err);
  //   }
  //   console.log(body.url);
  //   console.log(body.explanation);
  //   res.send(body)
  // });
  const options = {
    url: 'http://10.12.1.77/devices/',
    headers: {
        'OTA-TOKEN':'foo'
    }
  }
  request(options, function(err, resp, body){
    if(err){
        console.log(err)
        res.send("error")
    }
    console.log("all good")
    res.json(body)
  })
});

router.get('/devices/:hardwareId', function(req, res, next) {
    const options = {
      url: 'http://10.12.1.77/devices/'+req.params.hardwareId+'/',
      headers: {
          'OTA-TOKEN':'foo'
      }
    }
    request(options, function(err, resp, body){
      if(err){
        console.log(err)
        res.send("error")
      }
      console.log("all good")
      res.json(body)
    });
});

router.get('/devices/:deviceId/updates', function(req, res, next) {
    const options = {
      url: 'http://10.12.1.77/devices/'+req.params.deviceId+'/updates/',
      headers: {
          'OTA-TOKEN':'foo'
      }
    }
    request(options, function(err, resp, body){
      if(err){
          console.log(err)
          res.send("error")
      }
      console.log("all good")
      res.json(body)
    });
});

/************************** Provisioning Endpoints Below ***************************/

var mock_ota_dir='/home/bclouser/workspace/toradex/ota/web/new-web/ota-ui/test_deleteme'

// Create new device. Respond with credentials, certs, and sota.toml
router.get('/device-provision/create/:deviceId', function(req, res, next) {

    console.log("Calling start.sh")

    execFile('scripts/start.sh', ['new_client'],
        {cwd:mock_ota_dir, env:{"SERVER_NAME":"ota-ce.toradex.int", "DEVICE_ID":req.params.deviceId, "SKIP_CLIENT":"true"}},
        (err, stdout, stderr) => {
            if (err) {
                throw error;
            }
            console.log(stdout)
            res.send(stdout)
        })
});

// Respond with the root.crt
router.get('/device-provision/server/root.crt', function(req, res, next) {
    res.sendFile(mock_ota_dir+'/scripts/start.sh')
})

// Respond with the client.pem
router.get('/device-provision/device/:hardwareId/client.pem', function(req, res, next) {
    res.sendFile(mock_ota_dir+'/generated/client.pem', function(err){
      if(err){
        next(err)
      }
    })
});

// Respond with the pkey.pem
router.get('/device-provision/device/:hardwareId/pkey.pem', function(req, res, next) {
    res.sendFile('path/to/device/pkey.pem')
});



/************************** Ota Demo Endpoints Below ***************************/

// We need a place for our mysql scripts to come from. So we just make an enpoint for them here
router.get('/ota-demo-provision/mysql/:scriptName', function(req, res, next) {
    res.sendFile('/workspace/kubernetes/ota-community-edition/scripts/sql/'+req.params.scriptName)
});



module.exports = router;
