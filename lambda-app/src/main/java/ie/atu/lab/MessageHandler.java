package ie.atu.lab;

import com.amazonaws.services.lambda.runtime.Context;
import com.amazonaws.services.lambda.runtime.RequestHandler;
import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import software.amazon.awssdk.services.dynamodb.DynamoDbClient;

import java.util.List;
import java.util.Map;

public class MessageHandler implements RequestHandler<Map<String, Object>, Map<String, Object>> {

    private static final ObjectMapper JSON = new ObjectMapper();
    private static final DynamoDbClient DYNAMO_DB = DynamoDbClient.create();
    private static final MessageService SERVICE = new MessageService(
            new MessageRepository(DYNAMO_DB, System.getenv(AppConstants.Fields.TABLE_NAME))
    );

    @Override
    public Map<String, Object> handleRequest(Map<String, Object> event, Context context) {
        context.getLogger().log(AppConstants.Logs.REQUEST_RECEIVED);

        try {
            String method = requestMethod(event);
            return switch (method) {
                case AppConstants.Http.GET -> getMessages(context);
                case AppConstants.Http.POST -> createMessage(event, context);
                default -> ApiResponse.of(AppConstants.Http.METHOD_NOT_ALLOWED, Map.of(AppConstants.Fields.ERROR, AppConstants.Errors.METHOD_NOT_ALLOWED));
            };
        } catch (IllegalArgumentException e) {
            return ApiResponse.of(AppConstants.Http.BAD_REQUEST, Map.of(AppConstants.Fields.ERROR, e.getMessage()));
        } catch (Exception e) {
            context.getLogger().log(AppConstants.Logs.REQUEST_FAILED + e);
            return ApiResponse.of(AppConstants.Http.INTERNAL_SERVER_ERROR, Map.of(AppConstants.Fields.ERROR, AppConstants.Errors.INTERNAL_SERVER_ERROR));
        }
    }

    private Map<String, Object> getMessages(Context context) {
        List<Message> messages = SERVICE.getMessages();
        context.getLogger().log(AppConstants.Logs.SCAN_COMPLETE + messages.size());
        return ApiResponse.of(AppConstants.Http.OK, Map.of(AppConstants.Fields.MESSAGES, messages, AppConstants.Fields.COUNT, messages.size()));
    }

    private Map<String, Object> createMessage(Map<String, Object> event, Context context) {
        if (Boolean.TRUE.equals(event.get(AppConstants.Fields.IS_BASE64_ENCODED))) {
            throw new IllegalArgumentException(AppConstants.Errors.BASE64_NOT_SUPPORTED);
        }

        Object rawBody = event.get(AppConstants.Fields.BODY);
        if (!(rawBody instanceof String body) || body.isBlank()) {
            throw new IllegalArgumentException(AppConstants.Errors.BODY_REQUIRED);
        }

        JsonNode json;
        try {
            json = JSON.readTree(body);
        } catch (JsonProcessingException e) {
            throw new IllegalArgumentException(AppConstants.Errors.INVALID_JSON);
        }

        if (json == null || !json.isObject()) {
            throw new IllegalArgumentException(AppConstants.Errors.JSON_OBJECT_REQUIRED);
        }
        JsonNode messageNode = json.get(AppConstants.Fields.MESSAGE);
        if (messageNode == null || !messageNode.isTextual()) {
            throw new IllegalArgumentException(AppConstants.Errors.MESSAGE_MUST_BE_STRING);
        }

        Message message = SERVICE.createMessage(messageNode.asText());
        context.getLogger().log(AppConstants.Logs.MESSAGE_SAVED);
        return ApiResponse.of(AppConstants.Http.CREATED, message);
    }

    private String requestMethod(Map<String, Object> event) {
        if (event == null) {
            return "";
        }
        Object contextValue = event.get(AppConstants.Fields.REQUEST_CONTEXT);
        if (contextValue instanceof Map<?, ?> requestContext) {
            Object httpValue = requestContext.get(AppConstants.Fields.HTTP);
            if (httpValue instanceof Map<?, ?> http && http.get(AppConstants.Fields.METHOD) instanceof String method) {
                return method;
            }
        }
        return "";
    }
}
