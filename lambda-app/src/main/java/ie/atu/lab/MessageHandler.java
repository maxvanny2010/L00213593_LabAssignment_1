package ie.atu.lab;

import com.amazonaws.services.lambda.runtime.Context;
import com.amazonaws.services.lambda.runtime.RequestHandler;
import software.amazon.awssdk.services.dynamodb.DynamoDbClient;
import software.amazon.awssdk.services.dynamodb.model.ScanRequest;
import software.amazon.awssdk.services.dynamodb.model.ScanResponse;

import java.util.Map;

public class MessageHandler implements RequestHandler<Map<String, Object>, Map<String, Object>> {

    private static final DynamoDbClient dynamoDb = DynamoDbClient.create();

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

        context.getLogger().log(String.join(" ",
                "DynamoDB scan completed. Items returned:", String.valueOf(response.count())));

        return Map.of(
                "statusCode", 200,
                "headers", Map.of(
                        "Content-Type", "application/json"
                ),
                "body", "{\"message\":\"Hello from Java Lambda!\"}"
        );
    }
}
