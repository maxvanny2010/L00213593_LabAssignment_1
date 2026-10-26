package ie.atu.lab;

import com.sun.net.httpserver.HttpServer;
import software.amazon.awssdk.regions.Region;
import software.amazon.awssdk.services.dynamodb.DynamoDbClient;

import java.io.IOException;
import java.net.InetSocketAddress;

public class MessageHttpServer {

    public static void main(String[] args) throws IOException {

        String host = System.getenv().getOrDefault(
                AppConstants.Defaults.HOST_ENV,
                AppConstants.Defaults.HOST
        );

        int port = Integer.parseInt(
                System.getenv().getOrDefault(
                        AppConstants.Defaults.PORT_ENV,
                        AppConstants.Defaults.PORT
                )
        );

        String tableName = System.getenv().getOrDefault(
                AppConstants.Fields.TABLE_NAME,
                AppConstants.Defaults.TABLE_NAME
        );

        String region = System.getenv().getOrDefault(
                AppConstants.Defaults.AWS_REGION_ENV,
                AppConstants.Defaults.AWS_REGION
        );

        DynamoDbClient dynamoDb = DynamoDbClient.builder()
                .region(Region.of(region))
                .build();

        MessageRepository repository = new MessageRepository(dynamoDb, tableName);

        MessageService service = new MessageService(repository);

        HttpServer server = HttpServer.create(new InetSocketAddress(host, port), 0);
        server.createContext(AppConstants.Routes.HEALTH, new HealthHandler());
        server.createContext(AppConstants.Routes.MESSAGE, new MessageHttpHandler(service));

        Runtime.getRuntime().addShutdownHook(
                new Thread(() -> {
                    server.stop(0);
                    dynamoDb.close();
                })
        );

        server.start();

        System.out.println(AppConstants.Logs.HTTP_SERVER_STARTED + host + ":" + port);
    }
}