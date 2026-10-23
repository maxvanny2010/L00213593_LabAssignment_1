package ie.atu.lab;

import com.amazonaws.services.lambda.runtime.Context;
import com.amazonaws.services.lambda.runtime.RequestHandler;

import java.util.Map;

public class MessageHandler implements RequestHandler<Map<String, Object>, Map<String, Object>> {

    @Override
    public Map<String, Object> handleRequest(Map<String, Object> event, Context context) {

        context.getLogger().log("Message Board request received");

        return Map.of(
                "statusCode", 200,
                "headers", Map.of(
                        "Content-Type", "application/json"
                ),
                "body", "{\"message\":\"Hello from Java Lambda!\"}"
        );
    }
}
