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
                "Content-Type", "application/json; charset=UTF-8"
        );

        exchange.getResponseHeaders().set(
                "Cache-Control", "no-store"
        );

        exchange.sendResponseHeaders(status, bytes.length);

        try (var output = exchange.getResponseBody()) {
            output.write(bytes);
        }
    }
}
