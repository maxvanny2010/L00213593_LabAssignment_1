package ie.atu.lab;

import com.sun.net.httpserver.HttpServer;
import software.amazon.awssdk.regions.Region;
import software.amazon.awssdk.services.dynamodb.DynamoDbClient;

import java.io.IOException;
import java.net.InetSocketAddress;

public class MessageHttpServer {

    public static void main(String[] args) throws IOException {
        String host = System.getenv().getOrDefault("HOST", "127.0.0.1");
        int port = Integer.parseInt(
                System.getenv().getOrDefault("PORT", "8080")
        );

        String tableName = System.getenv().getOrDefault(
                "TABLE_NAME", "ATU-Three-Tier-messages"
        );

        String region = System.getenv().getOrDefault(
                "AWS_REGION", "eu-west-1"
        );

        DynamoDbClient dynamoDb = DynamoDbClient.builder()
                .region(Region.of(region))
                .build();

        MessageRepository repository =
                new MessageRepository(dynamoDb, tableName);

        MessageService service = new MessageService(repository);

        HttpServer server = HttpServer.create(
                new InetSocketAddress(host, port), 0
        );

        server.createContext("/health", new HealthHandler());
        server.createContext("/message", new MessageHttpHandler(service));

        Runtime.getRuntime().addShutdownHook(
                new Thread(() -> {
                    server.stop(0);
                    dynamoDb.close();
                })
        );

        server.start();

        System.out.println(
                "Java HTTP Server started at " + host + ":" + port
        );
    }
}
