import Blob "mo:core/Blob";
import Text "mo:core/Text";
import Runtime "mo:core/Runtime";
import Time "mo:core/Time";

module {
  // Inline types matching the IC management canister HTTP interface
  // (avoids needing ic:aaaaa-aa DID file at build time)
  public type HttpHeader = {
    name : Text;
    value : Text;
  };

  public type HttpResponse = {
    status : Nat;
    headers : [HttpHeader];
    body : Blob;
  };

  public type TransformationInput = {
    context : Blob;
    response : HttpResponse;
  };

  public type TransformationOutput = HttpResponse;

  public type Transform = query TransformationInput -> async TransformationOutput;

  public type Header = {
    name : Text;
    value : Text;
  };

  type TransformArg = {
    function : Transform;
    context : Blob;
  };

  type HttpRequestArgs = {
    url : Text;
    max_response_bytes : ?Nat64;
    headers : [HttpHeader];
    body : ?Blob;
    method : { #get; #head; #post };
    transform : ?TransformArg;
    is_replicated : ?Bool;
  };

  // Reference the IC management canister by principal without needing DID file
  let IC = actor "aaaaa-aa" : actor {
    http_request : shared HttpRequestArgs -> async HttpResponse;
  };

  let httpRequestCycles = 231_000_000_000;

  public func transform(input : TransformationInput) : TransformationOutput {
    {
      input.response with headers = [];
    };
  };

  public func httpGetRequest(url : Text, extraHeaders : [Header], transform : Transform) : async Text {
    let headers : [HttpHeader] = extraHeaders.concat([{
      name = "User-Agent";
      value = "caffeine.ai";
    }]);
    let http_request : HttpRequestArgs = {
      url;
      max_response_bytes = null;
      headers;
      body = null;
      method = #get;
      transform = ?{
        function = transform;
        context = Blob.fromArray([]);
      };
      is_replicated = ?false;
    };
    let httpResponse = await (with cycles = httpRequestCycles) IC.http_request(http_request);
    switch (httpResponse.body.decodeUtf8()) {
      case (null) { Runtime.trap("empty HTTP response") };
      case (?decodedResponse) { decodedResponse };
    };
  };

  public func httpPostRequest(url : Text, extraHeaders : [Header], body : Text, transform : Transform) : async Text {
    let headers : [HttpHeader] = extraHeaders.concat([
      { name = "User-Agent"; value = "caffeine.ai" },
      { name = "Idempotency-Key"; value = "Time-" # Time.now().toText() },
    ]);
    let requestBody = body.encodeUtf8();
    let httpRequest : HttpRequestArgs = {
      url;
      max_response_bytes = null;
      headers;
      body = ?requestBody;
      method = #post;
      transform = ?{
        function = transform;
        context = Blob.fromArray([]);
      };
      is_replicated = ?false;
    };
    let httpResponse = await (with cycles = httpRequestCycles) IC.http_request(httpRequest);
    switch (httpResponse.body.decodeUtf8()) {
      case (null) { Runtime.trap("empty HTTP response") };
      case (?decodedResponse) { decodedResponse };
    };
  };
};
