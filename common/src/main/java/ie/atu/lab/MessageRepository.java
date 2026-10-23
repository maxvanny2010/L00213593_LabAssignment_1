package ie.atu.lab;

import software.amazon.awssdk.services.dynamodb.DynamoDbClient;
import software.amazon.awssdk.services.dynamodb.model.AttributeValue;
import software.amazon.awssdk.services.dynamodb.model.PutItemRequest;
import software.amazon.awssdk.services.dynamodb.model.ScanRequest;
import software.amazon.awssdk.services.dynamodb.model.ScanResponse;

import java.util.List;
import java.util.Map;

public class MessageRepository {

    private final DynamoDbClient dynamoDb;
    private final String tableName;

    public MessageRepository(DynamoDbClient dynamoDb, String tableName) {
        if (tableName == null || tableName.isBlank()) {
            throw new IllegalStateException(AppConstants.Errors.MISSING_TABLE_NAME);
        }
        this.dynamoDb = dynamoDb;
        this.tableName = tableName;
    }

    public List<Message> findFirstPage(int limit) {
        ScanResponse response = dynamoDb.scan(
                ScanRequest.builder()
                        .tableName(tableName)
                        .limit(limit)
                        .build()
        );

        return response.items().stream()
                .map(this::fromItem)
                .toList();
    }

    public void save(Message message) {
        dynamoDb.putItem(
                PutItemRequest.builder()
                        .tableName(tableName)
                        .item(Map.of(
                                AppConstants.Fields.ID, AttributeValue.fromS(message.id()),
                                AppConstants.Fields.MESSAGE, AttributeValue.fromS(message.message()),
                                AppConstants.Fields.CREATED_AT, AttributeValue.fromS(message.createdAt())
                        ))
                        .build()
        );
    }

    private Message fromItem(Map<String, AttributeValue> item) {
        return new Message(
                stringValue(item, AppConstants.Fields.ID),
                stringValue(item, AppConstants.Fields.MESSAGE),
                stringValue(item, AppConstants.Fields.CREATED_AT)
        );
    }

    private String stringValue(Map<String, AttributeValue> item, String name) {
        AttributeValue value = item.get(name);
        return value != null && value.s() != null ? value.s() : "";
    }
}
