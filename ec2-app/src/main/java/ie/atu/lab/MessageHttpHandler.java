package ie.atu.lab;

import com.fasterxml.jackson.databind.JsonNode;
import com.sun.net.httpserver.HttpExchange;
import com.sun.net.httpserver.HttpHandler;

import java.io.IOException;
import java.util.List;
import java.util.Locale;
import java.util.Map;

public class MessageHttpHandler implements HttpHandler {

    private static final int MAX_BODY_SIZE = 4096;

    private final MessageService service;

    public MessageHttpHandler(MessageService service) {
        this.service = service;
    }

    @Override
    public void handle(HttpExchange exchange) throws IOException {
        if (!"/message".equals(exchange.getRequestURI().getPath())) {
            JsonHttpResponse.send(exchange, 404,
                    Map.of("error", "Not found"));
            return;
        }

        try {
            switch (exchange.getRequestMethod()) {
                case "GET" -> getMessages(exchange);
                case "POST" -> createMessage(exchange);
                default -> {
                    exchange.getResponseHeaders().set(
                            "Allow", "GET, POST"
                    );
                    JsonHttpResponse.send(exchange, 405,
                            Map.of("error", "Method not allowed"));
                }
            }
        } catch (IllegalArgumentException e) {
            JsonHttpResponse.send(exchange, 400,
                    Map.of("error", e.getMessage()));
        } catch (Exception e) {
            System.err.println("Message request failed: " + e);

            JsonHttpResponse.send(exchange, 500,
                    Map.of("error", "Internal server error"));
        }
    }

    private void getMessages(HttpExchange exchange) throws IOException {
        List<Message> messages = service.getMessages();

        JsonHttpResponse.send(exchange, 200, Map.of(
                "count", messages.size(),
                "messages", messages
        ));
    }

    private void createMessage(HttpExchange exchange) throws IOException {
        String contentType = exchange.getRequestHeaders()
                .getFirst("Content-Type");

        if (contentType == null ||
                !contentType.toLowerCase(Locale.ROOT)
                        .startsWith("application/json")) {
            JsonHttpResponse.send(exchange, 415,
                    Map.of("error", "JSON content type required"));
            return;
        }

        byte[] body = exchange.getRequestBody()
                .readNBytes(MAX_BODY_SIZE + 1);

        if (body.length > MAX_BODY_SIZE) {
            JsonHttpResponse.send(exchange, 413,
                    Map.of("error", "Request too large"));
            return;
        }

        JsonNode json;

        try {
            json = JsonHttpResponse.mapper().readTree(body);
        } catch (IOException e) {
            JsonHttpResponse.send(exchange, 400,
                    Map.of("error", "Invalid JSON"));
            return;
        }

        JsonNode messageNode = json == null
                ? null
                : json.get("message");

        if (messageNode == null || !messageNode.isTextual()) {
            JsonHttpResponse.send(exchange, 400,
                    Map.of("error", "Message must be a string"));
            return;
        }

        MessageRequest request =
                new MessageRequest(messageNode.asText());

        Message created = service.createMessage(request.message());

        JsonHttpResponse.send(exchange, 201, created);
    }
}
