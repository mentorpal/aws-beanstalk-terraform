/**
 * Rewrites origin (s3 bucket) requests to index.html for all client apps (home, chat, admin).
 * 
 * @param {*} event 
 * @returns 
 */
 function handler(event) {
  var request = event.request;
  var uri = request.uri;

  if (["PATCH", "PUT", "POST", "DELETE"].includes(request.method)) {
    return request;
  }

  if (uri == "" || uri == "/") {
    var finalLocation = "/home/"
    try{
        //   uri may not have the url
        var queryParams = request.querystring || "{}"
        var queryKeys = Object.keys(queryParams)
        var urlParams = queryKeys.map((key)=>`${key}=${queryParams[key]["value"]}`)
        if (urlParams.length > 0){
            finalLocation = `/home/?${urlParams.join("&")}`
        }
    }catch(e){
        console.log("failed to parse and set query params")
    }

    var response = {
      statusCode: 302,
      statusDescription: "Found",
      headers: { location: { value: finalLocation } },
    };
    
    return response;
  }

  if (!uri.includes(".")) {
    request.uri = "/" + uri.split("/").filter(e=>e.length).join("/") +"/index.html";
  }

  return request;
}
