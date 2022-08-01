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
    var response = {
      statusCode: 302,
      statusDescription: "Found",
      headers: { location: { value: "/home/" } },
    };

    return response;
  }

  // If the request is for a static file, return the file.
  // otherwise return the index.html file.
  // examples:
  //  - /home -> /home/index.html
  //  - /admin/file.js -> /admin/file.js
  //  - /admin/record?videoId=8283ad00 -> /admin/index.html
  if (!uri.includes(".")) {
    request.uri = "/" + uri.split("/").filter(e=>e.length)[0] +"/index.html";
  }
  
  return request;
}
