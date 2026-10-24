package ie.atu.lab;

import com.sun.net.httpserver.HttpExchange;
import com.sun.net.httpserver.HttpHandler;

import java.io.IOException;
import java.util.Map;

public class HealthHandler implements HttpHandler {

    @Override
    public void handle(HttpExchange exchange) throws IOException {
        if (!"/health".equals(exchange.getRequestURI().getPath())) {
            JsonHttpResponse.send(exchange, 404,
                    Map.of("error", "Not found"));
            return;
        }

        if (!"GET".equals(exchange.getRequestMethod())) {
            exchange.getResponseHeaders().set("Allow", "GET");
            JsonHttpResponse.send(exchange, 405,
                    Map.of("error", "Method not allowed"));
            return;
        }

        JsonHttpResponse.send(exchange, 200,
                Map.of("status", "UP", "service", "ec2-app"));
    }
}
