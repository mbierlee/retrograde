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

module retrograde.core.http;

import std.base64 : Base64;
import std.conv : to;
import std.uri : encode;

alias ResponseHandler = void delegate(HttpStatusCode statusCode, string bodyContent, MediaType contentType, string[string] headers);

/** 
 * A context for performing an HTTP request.
 */
class HttpRequest {
    RequestMethod method;
    string url;
    string[string] headers;
    string bodyContent;
    ResponseHandler responseHandler;
}

enum RequestMethod : string {
    get = "GET",
    post = "POST",
    put = "PUT",
    /// delete
    del = "DELETE",
    head = "HEAD",
    options = "OPTIONS",
    patch = "PATCH",
    trace = "TRACE",
    connect = "CONNECT"
}

enum MediaType : string {
    applicationAtom = "application/atom+xml",
    applicationForm = "application/x-www-form-urlencoded",
    applicationFhirJson = "application/fhir+json",
    applicationFhirXml = "application/fhir+xml",
    applicationGzip = "application/gzip",
    applicationJson = "application/json",
    applicationMsword = "application/msword",
    applicationOctetStream = "application/octet-stream",
    applicationPdf = "application/pdf",
    applicationRss = "application/rss+xml",
    applicationVndMsExcel = "application/vnd.ms-excel",
    applicationVndMsPowerpoint = "application/vnd.ms-powerpoint",
    applicationVndOpenxmlformatsOfficedocumentPresentationmlPresentation = "application/vnd.openxmlformats-officedocument.presentationml.presentation",
    applicationVndOpenxmlformatsOfficedocumentSpreadsheetmlSheet = "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
    applicationVndOpenxmlformatsOfficedocumentWordprocessingmlDocument = "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
    applicationXml = "application/xml",
    applicationXhtml = "application/xhtml+xml",
    applicationZip = "application/zip",
    audioMpeg = "audio/mpeg",
    audioOgg = "audio/ogg",
    audioWav = "audio/wav",
    audioWebm = "audio/webm",
    imageGif = "image/gif",
    imageJpeg = "image/jpeg",
    imagePng = "image/png",
    imageSvg = "image/svg+xml",
    imageTiff = "image/tiff",
    imageWebp = "image/webp",
    multipartForm = "multipart/form-data",
    textCss = "text/css",
    textCsv = "text/csv",
    textHtml = "text/html",
    textJavascript = "text/javascript",
    textPlain = "text/plain",
    textXml = "text/xml",
    videoMp4 = "video/mp4",
    videoMpeg = "video/mpeg",
    videoOgg = "video/ogg",
    videoQuicktime = "video/quicktime",
    videoWebm = "video/webm",
    videoXMsvideo = "video/x-msvideo",
    videoXMsWmv = "video/x-ms-wmv"
}

struct StatusCode {
    uint code;
    string message;
}

enum HttpStatusCode : StatusCode {
    // 1xx Informational
    continue_ = StatusCode(100, "Continue"),
    switchingProtocols = StatusCode(101, "Switching Protocols"),
    processing = StatusCode(102, "Processing"),
    earlyHints = StatusCode(103, "Early Hints"),

    // 2xx Success
    ok = StatusCode(200, "OK"),
    created = StatusCode(201, "Created"),
    accepted = StatusCode(202, "Accepted"),
    nonAuthoritativeInformation = StatusCode(203, "Non-Authoritative Information"),
    noContent = StatusCode(204, "No Content"),
    resetContent = StatusCode(205, "Reset Content"),
    partialContent = StatusCode(206, "Partial Content"),
    multiStatus = StatusCode(207, "Multi-Status"),
    alreadyReported = StatusCode(208, "Already Reported"),
    imUsed = StatusCode(226, "IM Used"),

    // 3xx Redirection
    multipleChoices = StatusCode(300, "Multiple Choices"),
    movedPermanently = StatusCode(301, "Moved Permanently"),
    found = StatusCode(302, "Found"),
    seeOther = StatusCode(303, "See Other"),
    notModified = StatusCode(304, "Not Modified"),
    useProxy = StatusCode(305, "Use Proxy"),
    temporaryRedirect = StatusCode(307, "Temporary Redirect"),
    permanentRedirect = StatusCode(308, "Permanent Redirect"),

    // 4xx Client errors
    badRequest = StatusCode(400, "Bad Request"),
    unauthorized = StatusCode(401, "Unauthorized"),
    paymentRequired = StatusCode(402, "Payment Required"),
    forbidden = StatusCode(403, "Forbidden"),
    notFound = StatusCode(404, "Not Found"),
    methodNotAllowed = StatusCode(405, "Method Not Allowed"),
    notAcceptable = StatusCode(406, "Not Acceptable"),
    proxyAuthenticationRequired = StatusCode(407, "Proxy Authentication Required"),
    requestTimeout = StatusCode(408, "Request Timeout"),
    conflict = StatusCode(409, "Conflict"),
    gone = StatusCode(410, "Gone"),
    lengthRequired = StatusCode(411, "Length Required"),
    preconditionFailed = StatusCode(412, "Precondition Failed"),
    payloadTooLarge = StatusCode(413, "Payload Too Large"),
    uriTooLong = StatusCode(414, "URI Too Long"),
    unsupportedMediaType = StatusCode(415, "Unsupported Media Type"),
    rangeNotSatisfiable = StatusCode(416, "Range Not Satisfiable"),
    expectationFailed = StatusCode(417, "Expectation Failed"),
    imATeapot = StatusCode(418, "I'm a teapot"),
    misdirectedRequest = StatusCode(421, "Misdirected Request"),
    unprocessableEntity = StatusCode(422, "Unprocessable Entity"),
    locked = StatusCode(423, "Locked"),
    failedDependency = StatusCode(424, "Failed Dependency"),
    tooEarly = StatusCode(425, "Too Early"),
    upgradeRequired = StatusCode(426, "Upgrade Required"),
    preconditionRequired = StatusCode(428, "Precondition Required"),
    tooManyRequests = StatusCode(429, "Too Many Requests"),
    requestHeaderFieldsTooLarge = StatusCode(431, "Request Header Fields Too Large"),
    unavailableForLegalReasons = StatusCode(451, "Unavailable For Legal Reasons"),

    // 5xx Server errors
    internalServerError = StatusCode(500, "Internal Server Error"),
    notImplemented = StatusCode(501, "Not Implemented"),
    badGateway = StatusCode(502, "Bad Gateway"),
    serviceUnavailable = StatusCode(503, "Service Unavailable"),
    gatewayTimeout = StatusCode(504, "Gateway Timeout"),
    httpVersionNotSupported = StatusCode(505, "HTTP Version Not Supported"),
    variantAlsoNegotiates = StatusCode(506, "Variant Also Negotiates"),
    insufficientStorage = StatusCode(507, "Insufficient Storage"),
    loopDetected = StatusCode(508, "Loop Detected"),
    notExtended = StatusCode(510, "Not Extended"),
    networkAuthenticationRequired = StatusCode(511, "Network Authentication Required")
}

HttpStatusCode getHttpStatusCode(uint code) {
    switch (code) {
    case 100:
        return HttpStatusCode.continue_;
    case 101:
        return HttpStatusCode.switchingProtocols;
    case 102:
        return HttpStatusCode.processing;
    case 103:
        return HttpStatusCode.earlyHints;
    case 200:
        return HttpStatusCode.ok;
    case 201:
        return HttpStatusCode.created;
    case 202:
        return HttpStatusCode.accepted;
    case 203:
        return HttpStatusCode.nonAuthoritativeInformation;
    case 204:
        return HttpStatusCode.noContent;
    case 205:
        return HttpStatusCode.resetContent;
    case 206:
        return HttpStatusCode.partialContent;
    case 207:
        return HttpStatusCode.multiStatus;
    case 208:
        return HttpStatusCode.alreadyReported;
    case 226:
        return HttpStatusCode.imUsed;
    case 300:
        return HttpStatusCode.multipleChoices;
    case 301:
        return HttpStatusCode.movedPermanently;
    case 302:
        return HttpStatusCode.found;
    case 303:
        return HttpStatusCode.seeOther;
    case 304:
        return HttpStatusCode.notModified;
    case 305:
        return HttpStatusCode.useProxy;
    case 307:
        return HttpStatusCode.temporaryRedirect;
    case 308:
        return HttpStatusCode.permanentRedirect;
    case 400:
        return HttpStatusCode.badRequest;
    case 401:
        return HttpStatusCode.unauthorized;
    case 402:
        return HttpStatusCode.paymentRequired;
    case 403:
        return HttpStatusCode.forbidden;
    case 404:
        return HttpStatusCode.notFound;
    case 405:
        return HttpStatusCode.methodNotAllowed;
    case 406:
        return HttpStatusCode.notAcceptable;
    case 407:
        return HttpStatusCode.proxyAuthenticationRequired;
    case 408:
        return HttpStatusCode.requestTimeout;
    case 409:
        return HttpStatusCode.conflict;
    case 410:
        return HttpStatusCode.gone;
    case 411:
        return HttpStatusCode.lengthRequired;
    case 412:
        return HttpStatusCode.preconditionFailed;
    case 413:
        return HttpStatusCode.payloadTooLarge;
    case 414:
        return HttpStatusCode.uriTooLong;
    case 415:
        return HttpStatusCode.unsupportedMediaType;
    case 416:
        return HttpStatusCode.rangeNotSatisfiable;
    case 417:
        return HttpStatusCode.expectationFailed;
    case 418:
        return HttpStatusCode.imATeapot;
    case 421:
        return HttpStatusCode.misdirectedRequest;
    case 422:
        return HttpStatusCode.unprocessableEntity;
    case 423:
        return HttpStatusCode.locked;
    case 424:
        return HttpStatusCode.failedDependency;
    case 425:
        return HttpStatusCode.tooEarly;
    case 426:
        return HttpStatusCode.upgradeRequired;
    case 428:
        return HttpStatusCode.preconditionRequired;
    case 429:
        return HttpStatusCode.tooManyRequests;
    case 431:
        return HttpStatusCode.requestHeaderFieldsTooLarge;
    case 451:
        return HttpStatusCode.unavailableForLegalReasons;
    case 500:
        return HttpStatusCode.internalServerError;
    case 501:
        return HttpStatusCode.notImplemented;
    case 502:
        return HttpStatusCode.badGateway;
    case 503:
        return HttpStatusCode.serviceUnavailable;
    case 504:
        return HttpStatusCode.gatewayTimeout;
    case 505:
        return HttpStatusCode.httpVersionNotSupported;
    case 506:
        return HttpStatusCode.variantAlsoNegotiates;
    case 507:
        return HttpStatusCode.insufficientStorage;
    case 508:
        return HttpStatusCode.loopDetected;
    case 510:
        return HttpStatusCode.notExtended;
    case 511:
        return HttpStatusCode.networkAuthenticationRequired;
    default:
        throw new Exception("Invalid HTTP status code");
    }
}

/**
 * Returns true if the status code is in the 4xx or 5xx range.
 */
bool isHttpError(HttpStatusCode code) {
    return (code.code >= 400 && code.code < 600);
}

HttpRequest get(HttpRequest request, string url) {
    request.method = RequestMethod.get;
    request.url = url;
    return request;
}

HttpRequest post(
    HttpRequest request,
    string url, string body = "",
    MediaType contentType = MediaType.textPlain
) {
    request.method = RequestMethod.post;
    request.url = url;
    request.bodyContent = body;
    request.headers["Content-Type"] = contentType;
    return request;
}

HttpRequest put(
    HttpRequest request,
    string url, string body = "",
    MediaType contentType = MediaType.textPlain
) {
    request.method = RequestMethod.put;
    request.url = url;
    request.bodyContent = body;
    request.headers["Content-Type"] = contentType;
    return request;
}

HttpRequest del(HttpRequest request, string url) {
    request.method = RequestMethod.del;
    request.url = url;
    return request;
}

HttpRequest header(HttpRequest request, string key, string value) {
    request.headers[key] = value;
    return request;
}

HttpRequest basicAuth(HttpRequest request, string credentials) {
    request.headers["Authorization"] = "Basic " ~ credentials;
    return request;
}

HttpRequest basicAuth(HttpRequest request, string username, string password) {
    string authString = encode(username ~ ":" ~ password);
    ubyte[] authData = cast(ubyte[]) authString;
    string encodedAuthString = to!string(Base64.encode(authData));
    string authHeader = "Basic " ~ encodedAuthString;
    request.headers["Authorization"] = authHeader;
    return request;
}

HttpRequest bearerToken(HttpRequest request, string token) {
    request.headers["Authorization"] = "Bearer " ~ token;
    return request;
}

HttpRequest response(
    HttpRequest request,
    ResponseHandler handler
) {
    request.responseHandler = handler;
    return request;
}

version (unittest) {
    HttpRequest perform(HttpRequest request) {
        auto response = request.bodyContent.length > 0 ? request.bodyContent : "Hello World!";
        request.responseHandler(
            HttpStatusCode.ok,
            response,
            MediaType.textPlain,
            [
                "Content-Type": MediaType.textPlain
            ]
        );

        return request;
    }

    @("Simple GET request") unittest {
        bool handlerWasCalled = false;

        void handler(HttpStatusCode statusCode, string bodyContent, MediaType contentType, string[string] headers) {
            assert(statusCode == HttpStatusCode.ok);
            assert(bodyContent == "Hello World!");
            assert(contentType == MediaType.textPlain);
            assert(headers.length > 0);
            assert(headers["Content-Type"] == MediaType.textPlain);
            assert(!statusCode.isHttpError);
            handlerWasCalled = true;
        }

        auto request = new HttpRequest()
            .get("http://example.com")
            .response(&handler)
            .perform();

        assert(request.method == RequestMethod.get);
        assert(request.url == "http://example.com");
        assert(request.headers.length == 0);
        assert(request.bodyContent == "");
        assert(request.responseHandler is &handler);
        assert(handlerWasCalled);
    }

    @("A POST request")
    unittest {
        bool handlerWasCalled = false;

        void handler(HttpStatusCode statusCode, string bodyContent, MediaType contentType, string[string] headers) {
            assert(statusCode == HttpStatusCode.ok);
            assert(bodyContent == "I am a postman!");
            assert(contentType == MediaType.textPlain);
            assert(headers.length > 0);
            assert(headers["Content-Type"] == MediaType.textPlain);
            assert(!statusCode.isHttpError);
            handlerWasCalled = true;
        }

        auto request = new HttpRequest()
            .post("http://example.com", "I am a postman!")
            .response(&handler)
            .perform();

        assert(request.method == RequestMethod.post);
        assert(request.url == "http://example.com");
        assert(request.headers.length == 1);
        assert(request.headers["Content-Type"] == MediaType.textPlain);
        assert(request.bodyContent == "I am a postman!");
        assert(request.responseHandler is &handler);
        assert(handlerWasCalled);
    }

    @("A PUT request")
    unittest {
        bool handlerWasCalled = false;

        void handler(HttpStatusCode statusCode, string bodyContent, MediaType contentType, string[string] headers) {
            assert(statusCode == HttpStatusCode.ok);
            assert(bodyContent == "I am a putter!");
            assert(contentType == MediaType.textPlain);
            assert(headers.length > 0);
            assert(headers["Content-Type"] == MediaType.textPlain);
            assert(!statusCode.isHttpError);
            handlerWasCalled = true;
        }

        auto request = new HttpRequest()
            .put("http://example.com", "I am a putter!")
            .response(&handler)
            .perform();

        assert(request.method == RequestMethod.put);
        assert(request.url == "http://example.com");
        assert(request.headers.length == 1);
        assert(request.headers["Content-Type"] == MediaType.textPlain);
        assert(request.bodyContent == "I am a putter!");
        assert(request.responseHandler is &handler);
        assert(handlerWasCalled);
    }

    @("A DELETE request")
    unittest {
        bool handlerWasCalled = false;

        void handler(HttpStatusCode statusCode, string bodyContent, MediaType contentType, string[string] headers) {
            assert(statusCode == HttpStatusCode.ok);
            assert(bodyContent == "Hello World!");
            assert(contentType == MediaType.textPlain);
            assert(headers.length > 0);
            assert(headers["Content-Type"] == MediaType.textPlain);
            assert(!statusCode.isHttpError);
            handlerWasCalled = true;
        }

        auto request = new HttpRequest()
            .del("http://example.com")
            .response(&handler)
            .perform();

        assert(request.method == RequestMethod.del);
        assert(request.url == "http://example.com");
        assert(request.headers.length == 0);
        assert(request.bodyContent == "");
        assert(request.responseHandler is &handler);
        assert(handlerWasCalled);
    }
}
