/**
 * Retrograde Engine
 *
 * Authors:
 *  Mike Bierlee, m.bierlee@lostmoment.com
 * Copyright: 2014-2023 Mike Bierlee
 * License:
 *  This software is licensed under the terms of the MIT license.
 *  The full terms of the license can be found in the LICENSE.txt file.
 */

module retrograde.http.client.vibe;

public import retrograde.core.http;

version (Have_vibe_d_http) {
    import vibe.http.client : requestHTTP, HTTPClientRequest, HTTPClientResponse, HTTPMethod;
    import vibe.data.json : Json;
    import vibe.http.common : HTTPMethod;

    import vibe.stream.operations : readAllUTF8;

    import std.string : representation;
    import std.exception : enforce;

    HttpResponse perform(HttpRequest request) {
        scope void requester(scope HTTPClientRequest vibeRequest) {
            vibeRequest.method = request.method.toVibe;

            foreach (string name, string value; request.headers) {
                vibeRequest.headers[name] = value;
            }

            if (request.bodyContent.length > 0) {
                vibeRequest.writeBody(request.bodyContent.representation, request
                        .headers["Content-Type"]);
            }
        }

        auto response = new HttpResponse();
        scope void responder(scope HTTPClientResponse vibeResponse) {
            string[string] headers;
            foreach (string name, string value; vibeResponse.headers.byKeyValue) {
                headers[name] = value;
            }

            response.statusCode = vibeResponse.statusCode.toHttpStatusCode;
            response.bodyContent = vibeResponse.bodyReader.readAllUTF8();
            response.contentType = vibeResponse.contentType.toMediaType;
            response.headers = headers;
        }

        requestHTTP(
            request.url,
            &requester,
            &responder
        );

        return response;
    }

    private HTTPMethod toVibe(RequestMethod method) {
        switch (method) {
        case RequestMethod.get:
            return HTTPMethod.GET;
        case RequestMethod.post:
            return HTTPMethod.POST;
        case RequestMethod.put:
            return HTTPMethod.PUT;
        case RequestMethod.del:
            return HTTPMethod.DELETE;
        case RequestMethod.head:
            return HTTPMethod.HEAD;
        case RequestMethod.options:
            return HTTPMethod.OPTIONS;
        case RequestMethod.patch:
            return HTTPMethod.PATCH;
        case RequestMethod.trace:
            return HTTPMethod.TRACE;
        case RequestMethod.connect:
            return HTTPMethod.CONNECT;
        default:
            throw new Exception("Unknown request method");
        }
    }

} else {
    HttpResponse perform(HttpRequest request) {
        throw new Exception("vibe.d http client not available. Please add dependency 'vibe-d:http' to your dub.json file. See https://code.dlang.org/packages/vibe-d for more information.");
    }
}
