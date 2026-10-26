package ie.atu.lab;

/**
 * Shared constants for Lambda, EC2 HTTP API and DynamoDB integration.
 */
public final class AppConstants {

    private AppConstants() {
    }

    public static final class Http {

        public static final String GET = "GET";
        public static final String POST = "POST";

        public static final String CONTENT_TYPE = "Content-Type";
        public static final String ALLOW = "Allow";
        public static final String CACHE_CONTROL = "Cache-Control";

        public static final String APPLICATION_JSON = "application/json";
        public static final String APPLICATION_JSON_UTF8 =
                "application/json; charset=UTF-8";

        public static final String NO_STORE = "no-store";
        public static final String ALLOWED_MESSAGE_METHODS = "GET, POST";

        public static final int OK = 200;
        public static final int CREATED = 201;
        public static final int BAD_REQUEST = 400;
        public static final int NOT_FOUND = 404;
        public static final int METHOD_NOT_ALLOWED = 405;
        public static final int REQUEST_TOO_LARGE = 413;
        public static final int UNSUPPORTED_MEDIA_TYPE = 415;
        public static final int INTERNAL_SERVER_ERROR = 500;

        private Http() {
        }
    }

    public static final class Routes {

        public static final String HEALTH = "/health";
        public static final String MESSAGE = "/message";

        private Routes() {
        }
    }

    public static final class Fields {

        public static final String TABLE_NAME = "TABLE_NAME";

        public static final String ID = "id";
        public static final String MESSAGE = "message";
        public static final String CREATED_AT = "createdAt";

        public static final String MESSAGES = "messages";
        public static final String COUNT = "count";
        public static final String ERROR = "error";

        public static final String STATUS = "status";
        public static final String SERVICE = "service";

        public static final String STATUS_CODE = "statusCode";
        public static final String HEADERS = "headers";
        public static final String BODY = "body";

        public static final String IS_BASE64_ENCODED = "isBase64Encoded";
        public static final String REQUEST_CONTEXT = "requestContext";
        public static final String HTTP = "http";
        public static final String METHOD = "method";

        private Fields() {
        }
    }

    public static final class Defaults {

        public static final String HOST_ENV = "HOST";
        public static final String PORT_ENV = "PORT";
        public static final String AWS_REGION_ENV = "AWS_REGION";

        public static final String HOST = "127.0.0.1";
        public static final String PORT = "8080";

        public static final String AWS_REGION = "eu-west-1";
        public static final String TABLE_NAME =
                "ATU-Three-Tier-messages";

        public static final String SERVICE_NAME = "ec2-app";
        public static final String HEALTH_STATUS = "UP";

        private Defaults() {
        }
    }

    public static final class Errors {

        public static final String MISSING_TABLE_NAME =
                "TABLE_NAME environment variable is not configured";

        public static final String SERIALIZATION_FAILED =
                "Failed to serialize API response";

        public static final String NOT_FOUND =
                "Not found";

        public static final String METHOD_NOT_ALLOWED =
                "Method not allowed";

        public static final String INTERNAL_SERVER_ERROR =
                "Internal server error";

        public static final String BASE64_NOT_SUPPORTED =
                "Base64 request body is not supported";

        public static final String BODY_REQUIRED =
                "Request body is required";

        public static final String INVALID_JSON =
                "Invalid JSON request body";

        public static final String JSON_OBJECT_REQUIRED =
                "JSON object is required";

        public static final String MESSAGE_MUST_BE_STRING =
                "Message must be a string";

        public static final String MESSAGE_LENGTH =
                "Message must contain between 1 and 500 characters";

        public static final String JSON_CONTENT_TYPE_REQUIRED =
                "JSON content type required";

        public static final String REQUEST_TOO_LARGE =
                "Request too large";

        public static final String INVALID_HTTP_JSON =
                "Invalid JSON";

        private Errors() {
        }
    }

    public static final class Logs {

        public static final String REQUEST_RECEIVED =
                "Message Board request received";

        public static final String REQUEST_FAILED =
                "Request failed: ";

        public static final String HTTP_REQUEST_FAILED =
                "Message request failed: ";

        public static final String SCAN_COMPLETE =
                "DynamoDB scan completed. Items returned: ";

        public static final String MESSAGE_SAVED =
                "Message saved to DynamoDB";

        public static final String HTTP_SERVER_STARTED =
                "Java HTTP Server started at ";

        private Logs() {
        }
    }

    public static final class Limits {

        public static final int SCAN_PAGE_SIZE = 20;
        public static final int MAX_MESSAGE_LENGTH = 500;
        public static final int MAX_HTTP_BODY_BYTES = 4096;

        private Limits() {
        }
    }
}