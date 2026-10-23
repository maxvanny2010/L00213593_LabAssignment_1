package ie.atu.lab;

/** Shared values for the Lambda HTTP API and DynamoDB integration. */
public final class AppConstants {

    private AppConstants() {
    }

    public static final class Http {
        public static final String GET = "GET";
        public static final String POST = "POST";
        public static final String CONTENT_TYPE = "Content-Type";
        public static final String APPLICATION_JSON = "application/json";
        public static final int OK = 200;
        public static final int CREATED = 201;
        public static final int BAD_REQUEST = 400;
        public static final int METHOD_NOT_ALLOWED = 405;
        public static final int INTERNAL_SERVER_ERROR = 500;

        private Http() {
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

    public static final class Errors {
        public static final String MISSING_TABLE_NAME =
                "TABLE_NAME environment variable is not configured";
        public static final String SERIALIZATION_FAILED =
                "Failed to serialize API response";
        public static final String METHOD_NOT_ALLOWED = "Method not allowed";
        public static final String INTERNAL_SERVER_ERROR = "Internal server error";
        public static final String BASE64_NOT_SUPPORTED = "Base64 request body is not supported";
        public static final String BODY_REQUIRED = "Request body is required";
        public static final String INVALID_JSON = "Invalid JSON request body";
        public static final String JSON_OBJECT_REQUIRED = "JSON object is required";
        public static final String MESSAGE_MUST_BE_STRING = "Message must be a string";
        public static final String MESSAGE_LENGTH =
                "Message must contain between 1 and 500 characters";

        private Errors() {
        }
    }

    public static final class Logs {
        public static final String REQUEST_RECEIVED = "Message Board request received";
        public static final String REQUEST_FAILED = "Request failed: ";
        public static final String SCAN_COMPLETE = "DynamoDB scan completed. Items returned: ";
        public static final String MESSAGE_SAVED = "Message saved to DynamoDB";

        private Logs() {
        }
    }

    public static final class Limits {
        public static final int SCAN_PAGE_SIZE = 20;
        public static final int MAX_MESSAGE_LENGTH = 500;

        private Limits() {
        }
    }
}
