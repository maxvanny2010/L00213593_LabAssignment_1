package ie.atu.lab;

import com.sun.net.httpserver.HttpExchange;
import com.sun.net.httpserver.HttpServer;

import java.io.IOException;
import java.net.InetSocketAddress;
import java.nio.charset.StandardCharsets;

public class MessageHttpServer {

    public static void main(String[] args) throws IOException {
        int port = Integer.parseInt(
                System.getenv().getOrDefault("PORT", "8080")
        );

        HttpServer server = HttpServer.create(
                new InetSocketAddress(port), 0
        );

        server.createContext("/health", exchange -> {
            if (!"GET".equals(exchange.getRequestMethod())) {
                sendResponse(exchange, 405,
                        "{\"error\":\"Method not allowed\"}");
                return;
            }

            sendResponse(exchange, 200,
                    "{\"status\":\"UP\",\"service\":\"ec2-app\"}");
        });

        server.start();

        System.out.println("Java HTTP Server started on port " + port);
    }

    private static void sendResponse(
            HttpExchange exchange,
            int status,
            String json
    ) throws IOException {

        byte[] response = json.getBytes(StandardCharsets.UTF_8);

        exchange.getResponseHeaders().set(
                "Content-Type", "application/json; charset=UTF-8"
        );

        exchange.sendResponseHeaders(status, response.length);

        try (var output = exchange.getResponseBody()) {
            output.write(response);
        }
    }
}
