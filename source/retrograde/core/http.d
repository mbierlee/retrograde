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
import std.string : split, strip, startsWith, endsWith;

/** 
 * A context for performing an HTTP request.
 */
class HttpRequest {
    RequestMethod method;
    string url;
    string[string] headers;
    string bodyContent;
}

class HttpResponse {
    HttpStatusCode statusCode;
    string bodyContent;
    MediaType contentType;
    string[string] headers;
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

MediaType toMediaType(string input) {
    auto parts = input.split("/");
    if (parts.length != 2) {
        throw new Exception("Invalid media type: " ~ input);
    }

    auto type = parts[0].strip();
    auto subtype = parts[1].strip();
    foreach (member; __traits(allMembers, MediaType)) {
        string mediaTypeValue = mixin("MediaType." ~ member);
        if (mediaTypeValue == input || (mediaTypeValue.startsWith(type ~ "/")
                && mediaTypeValue.endsWith("/" ~ subtype))) {
            return mixin("MediaType." ~ member);
        }
    }

    throw new Exception("Unknown media type: " ~ input);
}

struct StatusCode {
    uint code;
    string message;
}

string toString(StatusCode status) {
    return status.code.to!string ~ " " ~ status.message;
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

HttpStatusCode toHttpStatusCode(uint code) {
    static foreach (member; __traits(allMembers, HttpStatusCode)) {
        if (code == mixin("HttpStatusCode." ~ member ~ ".code")) {
            return mixin("HttpStatusCode." ~ member);
        }
    }

    throw new Exception("Unknown HTTP status code: " ~ code.to!string);
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
    string url,
    string body = "",
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
    string url,
    string body = "",
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

version (unittest) {
    HttpResponse perform(HttpRequest request) {
        auto responseBody = request.bodyContent.length > 0 ? request.bodyContent : "Hello World!";
        auto response = new HttpResponse();
        response.statusCode = HttpStatusCode.ok;
        response.bodyContent = responseBody;
        response.contentType = MediaType.textPlain;
        response.headers["Content-Type"] = MediaType.textPlain;
        return response;
    }

    @("Simple GET request") unittest {
        auto request = new HttpRequest().get("http://example.com");
        auto response = request.perform();

        assert(request.method == RequestMethod.get);
        assert(request.url == "http://example.com");
        assert(request.headers.length == 0);
        assert(request.bodyContent == "");

        assert(response.statusCode == HttpStatusCode.ok);
        assert(response.bodyContent == "Hello World!");
        assert(response.contentType == MediaType.textPlain);
        assert(response.headers.length > 0);
        assert(response.headers["Content-Type"] == MediaType.textPlain);
        assert(!response.statusCode.isHttpError);
    }

    @("A POST request")
    unittest {
        auto request = new HttpRequest().post("http://example.com", "I am a postman!");
        auto response = request.perform();

        assert(request.method == RequestMethod.post);
        assert(request.url == "http://example.com");
        assert(request.headers.length == 1);
        assert(request.headers["Content-Type"] == MediaType.textPlain);
        assert(request.bodyContent == "I am a postman!");

        assert(response.statusCode == HttpStatusCode.ok);
        assert(response.bodyContent == "I am a postman!");
        assert(response.contentType == MediaType.textPlain);
        assert(response.headers.length > 0);
        assert(response.headers["Content-Type"] == MediaType.textPlain);
        assert(!response.statusCode.isHttpError);
    }

    @("A PUT request")
    unittest {
        auto request = new HttpRequest().put("http://example.com", "I am a putter!");
        auto response = request.perform();

        assert(request.method == RequestMethod.put);
        assert(request.url == "http://example.com");
        assert(request.headers.length == 1);
        assert(request.headers["Content-Type"] == MediaType.textPlain);
        assert(request.bodyContent == "I am a putter!");

        assert(response.statusCode == HttpStatusCode.ok);
        assert(response.bodyContent == "I am a putter!");
        assert(response.contentType == MediaType.textPlain);
        assert(response.headers.length > 0);
        assert(response.headers["Content-Type"] == MediaType.textPlain);
        assert(!response.statusCode.isHttpError);
    }

    @("A DELETE request")
    unittest {
        auto request = new HttpRequest().del("http://example.com");
        auto response = request.perform();

        assert(request.method == RequestMethod.del);
        assert(request.url == "http://example.com");
        assert(request.headers.length == 0);
        assert(request.bodyContent == "");

        assert(response.statusCode == HttpStatusCode.ok);
        assert(response.bodyContent == "Hello World!");
        assert(response.contentType == MediaType.textPlain);
        assert(response.headers.length > 0);
        assert(response.headers["Content-Type"] == MediaType.textPlain);
        assert(!response.statusCode.isHttpError);
    }

    @("To HTTP status code using toHttpStatusCode")
    unittest {
        assert(toHttpStatusCode(200) == HttpStatusCode.ok);
        assert(toHttpStatusCode(201) == HttpStatusCode.created);
        assert(toHttpStatusCode(202) == HttpStatusCode.accepted);
        assert(toHttpStatusCode(203) == HttpStatusCode.nonAuthoritativeInformation);
        assert(toHttpStatusCode(204) == HttpStatusCode.noContent);
        assert(toHttpStatusCode(205) == HttpStatusCode.resetContent);
        assert(toHttpStatusCode(206) == HttpStatusCode.partialContent);
        assert(toHttpStatusCode(300) == HttpStatusCode.multipleChoices);
        assert(toHttpStatusCode(301) == HttpStatusCode.movedPermanently);
        assert(toHttpStatusCode(302) == HttpStatusCode.found);
        assert(toHttpStatusCode(303) == HttpStatusCode.seeOther);
        assert(toHttpStatusCode(304) == HttpStatusCode.notModified);
        assert(toHttpStatusCode(305) == HttpStatusCode.useProxy);
        assert(toHttpStatusCode(307) == HttpStatusCode.temporaryRedirect);
        assert(toHttpStatusCode(400) == HttpStatusCode.badRequest);
        assert(toHttpStatusCode(401) == HttpStatusCode.unauthorized);
        assert(toHttpStatusCode(402) == HttpStatusCode.paymentRequired);
        assert(toHttpStatusCode(403) == HttpStatusCode.forbidden);
        assert(toHttpStatusCode(404) == HttpStatusCode.notFound);
        assert(toHttpStatusCode(405) == HttpStatusCode.methodNotAllowed);
        assert(toHttpStatusCode(406) == HttpStatusCode.notAcceptable);
        assert(toHttpStatusCode(407) == HttpStatusCode.proxyAuthenticationRequired);
        assert(toHttpStatusCode(408) == HttpStatusCode.requestTimeout);
        assert(toHttpStatusCode(409) == HttpStatusCode.conflict);
        assert(toHttpStatusCode(410) == HttpStatusCode.gone);
        assert(toHttpStatusCode(411) == HttpStatusCode.lengthRequired);
        assert(toHttpStatusCode(412) == HttpStatusCode.preconditionFailed);
        assert(toHttpStatusCode(413) == HttpStatusCode.payloadTooLarge);
        assert(toHttpStatusCode(414) == HttpStatusCode.uriTooLong);
        assert(toHttpStatusCode(415) == HttpStatusCode.unsupportedMediaType);
        assert(toHttpStatusCode(416) == HttpStatusCode.rangeNotSatisfiable);
        assert(toHttpStatusCode(417) == HttpStatusCode.expectationFailed);
        assert(toHttpStatusCode(500) == HttpStatusCode.internalServerError);
        assert(toHttpStatusCode(501) == HttpStatusCode.notImplemented);
        assert(toHttpStatusCode(502) == HttpStatusCode.badGateway);
        assert(toHttpStatusCode(503) == HttpStatusCode.serviceUnavailable);
        assert(toHttpStatusCode(504) == HttpStatusCode.gatewayTimeout);
    }

    @("To MediaType using toMediaType")
    unittest {
        assert(toMediaType("text/plain") == MediaType.textPlain);
        assert(toMediaType("text/html") == MediaType.textHtml);
        assert(toMediaType("text/css") == MediaType.textCss);
        assert(toMediaType("text/javascript") == MediaType.textJavascript);
        assert(toMediaType("application/json") == MediaType.applicationJson);
        assert(toMediaType("application/xml") == MediaType.applicationXml);
        assert(toMediaType("application/x-www-form-urlencoded") == MediaType.applicationForm);
        assert(toMediaType("multipart/form-data") == MediaType.multipartForm);
        assert(toMediaType("image/png") == MediaType.imagePng);
        assert(toMediaType("image/jpeg") == MediaType.imageJpeg);
        assert(toMediaType("image/gif") == MediaType.imageGif);
        assert(toMediaType("image/svg+xml") == MediaType.imageSvg);
        assert(toMediaType("audio/mpeg") == MediaType.audioMpeg);
        assert(toMediaType("audio/ogg") == MediaType.audioOgg);
        assert(toMediaType("audio/wav") == MediaType.audioWav);
        assert(toMediaType("video/mp4") == MediaType.videoMp4);
        assert(toMediaType("video/ogg") == MediaType.videoOgg);
        assert(toMediaType("video/webm") == MediaType.videoWebm);
    }
}
