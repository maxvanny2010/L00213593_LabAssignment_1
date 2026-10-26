package ie.atu.lab;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.sun.net.httpserver.HttpExchange;

import java.io.IOException;

public final class JsonHttpResponse {

    private static final ObjectMapper JSON = new ObjectMapper();

    private JsonHttpResponse() {
    }

    public static ObjectMapper mapper() {
        return JSON;
    }

    public static void send(
            HttpExchange exchange,
            int status,
            Object body
    ) throws IOException {

        byte[] bytes = JSON.writeValueAsBytes(body);

        exchange.getResponseHeaders().set(
                AppConstants.Http.CONTENT_TYPE,
                AppConstants.Http.APPLICATION_JSON_UTF8
        );

        exchange.getResponseHeaders().set(
                AppConstants.Http.CACHE_CONTROL,
                AppConstants.Http.NO_STORE
        );

        exchange.sendResponseHeaders(status, bytes.length);

        try (var output = exchange.getResponseBody()) {
            output.write(bytes);
        }
    }
}