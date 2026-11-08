/**
 * Handles routing for the home, chat, and admin
 *
 * - Redirects root requests to /home/, preserving query parameters.
 * - Redirects unknown application routes to /home/.
 * - Rewrites known routes to their application's index.html (where Vite then handles the sub-routes)
 */
function handler(event) {
  var request = event.request;
  var uri = request.uri;

  if (["PATCH", "PUT", "POST", "DELETE"].includes(request.method)) {
    return request;
  }

  // Redirect root requests to /home/
  if (uri == "" || uri == "/") {
    var finalLocation = "/home/"
    try{
        var queryParams = request.querystring || "{}"
        var queryKeys = Object.keys(queryParams)
        var urlParams = queryKeys.map((key)=>`${key}=${queryParams[key]["value"]}`)
        if (urlParams.length > 0){
            finalLocation = `/home/?${urlParams.join("&")}`
        }
    }catch(e){
        console.log("failed to parse and set query params")
    }

    return {
      statusCode: 302,
      statusDescription: "Found",
      headers: { location: { value: finalLocation } },
    };
  }

  // Identify the base route from the first URL segment
  var parts = uri.split("/").filter(e => e.length);
  var app = parts[0];

  // Redirect unknown routes to /home/
  if (!["home", "admin", "chat"].includes(app)) {
    return {
      statusCode: 302,
      statusDescription: "Found",
      headers: {
        location: { value: "/home/" }
      }
    };
  }

  // Rewrite SPA routes to their application's index.html at the base route (where Vite then handles the sub-routes)
  if (!uri.includes(".")) {
    request.uri = "/" + app + "/index.html";
  }

  return request;
}
