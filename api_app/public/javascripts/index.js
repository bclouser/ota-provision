$(document).ready(function(){
    console.log("hello world")
    // $.ajax({
    //     type: 'GET',
    //     url: 'http://10.12.1.77/devices',
    //     headers: {
    //         "OTA-TOKEN":"foo"
    //     },
    //     success: function(data){
    //         console.log("got a response")
    //         console.log(data)
    //     },
    //     error: function(){
    //         console.log("got an error")
    //     }
    // })

    $.get('api/devices', function(devices_data){
        console.log("Got back some data")
        console.log(devices_data)
        var device_resp = JSON.parse(devices_data)
        console.log("there is " + device_resp.length + " items in this list")
        var table_content=""
        for(var i = 0; i < device_resp.length; i++){
            //console.log("Devices Data:")
            //console.log(device_resp[i])
            // Get the packages (if any) available for this device.
            $.ajax({
                url:'api/devices/'+device_resp[i].deviceId+'/updates',
                dev_data: device_resp[i],
                success: function(pkgs_data){
                    console.log("devices data:")
                    console.log(this.dev_data)
                    console.log("Packages Data:")
                    console.log(pkgs_data)
                    table_content+="<tr><th>"+this.dev_data.deviceName+"</th></tr>"
                    table_content+="<tr><div class=\"devices-container\">"
                    table_content+="<table>"
                    table_content+="<tr><td>deviceId</td><td>"+this.dev_data.deviceId+"</td></tr>"
                    table_content+="<tr><td>deviceStatus</td><td>"+this.dev_data.deviceStatus+"</td></tr>"
                    table_content+="<tr><td>lastSeen</td><td>"+this.dev_data.lastSeen+"</td></tr>"
                    table_content+="<tr><td>uuid</td><td>"+this.dev_data.uuid+"</td></tr>"
                    table_content+="<tr><td><table><th>Image</th>"
                    table_content+="<tr><td>hardwareId</td><td>"+this.dev_data.deviceImage.hardwareId+"</td></tr>"
                    table_content+="<tr><td>id</td><td>"+this.dev_data.deviceImage.id+"</td></tr>"
                    table_content+="</table></table>"
                    table_content+="<div class=\"packages-container\">"
                    table_content+="<ul class=\"available-packages\">"
                    table_content+="</ul>"
                    table_content+="</tr></div>"
                    $("#devices").html(table_content)
                },
                error: function(error){
                    console.log("Failed to get updates")
                }
            })
        }
    })
    
});