
package ie.atu.lab;

import com.amazonaws.services.lambda.runtime.Context;
import com.amazonaws.services.lambda.runtime.RequestHandler;
import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import software.amazon.awssdk.services.dynamodb.DynamoDbClient;
import software.amazon.awssdk.services.dynamodb.model.AttributeValue;
import software.amazon.awssdk.services.dynamodb.model.ScanRequest;
import software.amazon.awssdk.services.dynamodb.model.ScanResponse;

import java.util.List;
import java.util.Map;

public class MessageHandler implements RequestHandler<Map<String, Object>, Map<String, Object>> {

    private static final DynamoDbClient dynamoDb = DynamoDbClient.create();
    private static final ObjectMapper objectMapper = new ObjectMapper();

    @Override
    public Map<String, Object> handleRequest(Map<String, Object> event, Context context) {

        context.getLogger().log("Message Board request received");

        String tableName = System.getenv("TABLE_NAME");

        if (tableName == null || tableName.isBlank()) {
            throw new IllegalStateException("TABLE_NAME environment variable is not configured");
        }

        ScanRequest request = ScanRequest.builder()
                .tableName(tableName)
                .limit(20)
                .build();

        ScanResponse response = dynamoDb.scan(request);

        context.getLogger().log(
                "DynamoDB scan completed. Items returned: " + response.count()
        );

        List<Map<String, String>> messages = response.items().stream()
                .map(this::toMessage)
                .toList();

        try {
            String body = objectMapper.writeValueAsString(
                    Map.of(
                            "messages", messages,
                            "count", messages.size()
                    )
            );

            return Map.of(
                    "statusCode", 200,
                    "headers", Map.of("Content-Type", "application/json"),
                    "body", body
            );

        } catch (JsonProcessingException e) {
            throw new IllegalStateException("Failed to serialize messages", e);
        }
    }

    private Map<String, String> toMessage(Map<String, AttributeValue> item) {
        return Map.of(
                "id", stringValue(item, "id"),
                "message", stringValue(item, "message"),
                "createdAt", stringValue(item, "createdAt")
        );
    }

    private String stringValue(Map<String, AttributeValue> item, String name) {
        AttributeValue value = item.get(name);
        return value != null && value.s() != null ? value.s() : "";
    }
}