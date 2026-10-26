package ie.atu.lab;

import com.fasterxml.jackson.databind.JsonNode;
import com.sun.net.httpserver.HttpExchange;
import com.sun.net.httpserver.HttpHandler;

import java.io.IOException;
import java.util.List;
import java.util.Locale;
import java.util.Map;

public class MessageHttpHandler implements HttpHandler {

    private final MessageService service;

    public MessageHttpHandler(MessageService service) {
        this.service = service;
    }

    @Override
    public void handle(HttpExchange exchange) throws IOException {
        if (!AppConstants.Routes.MESSAGE.equals(
                exchange.getRequestURI().getPath())) {
            JsonHttpResponse.send(
                    exchange,
                    AppConstants.Http.NOT_FOUND,
                    Map.of(
                            AppConstants.Fields.ERROR,
                            AppConstants.Errors.NOT_FOUND
                    )
            );
            return;
        }

        try {
            switch (exchange.getRequestMethod()) {
                case AppConstants.Http.GET -> getMessages(exchange);
                case AppConstants.Http.POST -> createMessage(exchange);
                default -> {
                    exchange.getResponseHeaders().set(
                            AppConstants.Http.ALLOW,
                            AppConstants.Http.ALLOWED_MESSAGE_METHODS
                    );
                    JsonHttpResponse.send(
                            exchange,
                            AppConstants.Http.METHOD_NOT_ALLOWED,
                            Map.of(AppConstants.Fields.ERROR, AppConstants.Errors.METHOD_NOT_ALLOWED)
                    );
                }
            }

        } catch (IllegalArgumentException e) {
            JsonHttpResponse.send(
                    exchange,
                    AppConstants.Http.BAD_REQUEST,
                    Map.of(AppConstants.Fields.ERROR, e.getMessage())
            );
        } catch (Exception e) {
            System.err.println(AppConstants.Logs.HTTP_REQUEST_FAILED + e);
            JsonHttpResponse.send(
                    exchange,
                    AppConstants.Http.INTERNAL_SERVER_ERROR,
                    Map.of(AppConstants.Fields.ERROR, AppConstants.Errors.INTERNAL_SERVER_ERROR)
            );
        }
    }

    private void getMessages(HttpExchange exchange) throws IOException {
        List<Message> messages = service.getMessages();
        JsonHttpResponse.send(
                exchange,
                AppConstants.Http.OK,
                Map.of(
                        AppConstants.Fields.COUNT,
                        messages.size(),
                        AppConstants.Fields.MESSAGES,
                        messages
                )
        );
    }

    private void createMessage(HttpExchange exchange) throws IOException {
        String contentType = exchange.getRequestHeaders()
                .getFirst(AppConstants.Http.CONTENT_TYPE);

        if (contentType == null ||
                !contentType.toLowerCase(Locale.ROOT)
                        .startsWith(AppConstants.Http.APPLICATION_JSON)) {
            JsonHttpResponse.send(
                    exchange,
                    AppConstants.Http.UNSUPPORTED_MEDIA_TYPE,
                    Map.of(AppConstants.Fields.ERROR, AppConstants.Errors.JSON_CONTENT_TYPE_REQUIRED)
            );
            return;
        }

        byte[] body = exchange.getRequestBody().readNBytes(AppConstants.Limits.MAX_HTTP_BODY_BYTES + 1);

        if (body.length > AppConstants.Limits.MAX_HTTP_BODY_BYTES) {
            JsonHttpResponse.send(
                    exchange,
                    AppConstants.Http.REQUEST_TOO_LARGE,
                    Map.of(AppConstants.Fields.ERROR, AppConstants.Errors.REQUEST_TOO_LARGE)
            );
            return;
        }

        JsonNode json;

        try {
            json = JsonHttpResponse.mapper().readTree(body);
        } catch (IOException e) {
            JsonHttpResponse.send(
                    exchange,
                    AppConstants.Http.BAD_REQUEST,
                    Map.of(AppConstants.Fields.ERROR, AppConstants.Errors.INVALID_HTTP_JSON)
            );
            return;
        }

        JsonNode messageNode = json == null
                ? null
                : json.get(AppConstants.Fields.MESSAGE);

        if (messageNode == null || !messageNode.isTextual()) {
            JsonHttpResponse.send(
                    exchange,
                    AppConstants.Http.BAD_REQUEST,
                    Map.of(AppConstants.Fields.ERROR, AppConstants.Errors.MESSAGE_MUST_BE_STRING)
            );
            return;
        }

        MessageRequest request = new MessageRequest(messageNode.asText());
        Message created = service.createMessage(request.message());
        JsonHttpResponse.send(exchange, AppConstants.Http.CREATED, created);
    }
}