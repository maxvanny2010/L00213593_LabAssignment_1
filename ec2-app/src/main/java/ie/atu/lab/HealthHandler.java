package ie.atu.lab;

import com.sun.net.httpserver.HttpExchange;
import com.sun.net.httpserver.HttpHandler;

import java.io.IOException;
import java.util.Map;

public class HealthHandler implements HttpHandler {

    @Override
    public void handle(HttpExchange exchange) throws IOException {

        if (!AppConstants.Routes.HEALTH.equals(exchange.getRequestURI().getPath())) {
            JsonHttpResponse.send(
                    exchange,
                    AppConstants.Http.NOT_FOUND,
                    Map.of(AppConstants.Fields.ERROR, AppConstants.Errors.NOT_FOUND)
            );
            return;
        }

        if (!AppConstants.Http.GET.equals(exchange.getRequestMethod())) {
            exchange.getResponseHeaders().set(
                    AppConstants.Http.ALLOW,
                    AppConstants.Http.GET
            );

            JsonHttpResponse.send(
                    exchange,
                    AppConstants.Http.METHOD_NOT_ALLOWED,
                    Map.of(AppConstants.Fields.ERROR, AppConstants.Errors.METHOD_NOT_ALLOWED)
            );
            return;
        }

        JsonHttpResponse.send(
                exchange,
                AppConstants.Http.OK,
                Map.of(
                        AppConstants.Fields.STATUS,
                        AppConstants.Defaults.HEALTH_STATUS,
                        AppConstants.Fields.SERVICE,
                        AppConstants.Defaults.SERVICE_NAME
                )
        );
    }
}