package ie.atu.lab;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;

import java.util.Map;

public final class ApiResponse {

    private static final ObjectMapper JSON = new ObjectMapper();

    private ApiResponse() {
    }

    public static Map<String, Object> of(int statusCode, Object body) {
        try {
            return Map.of(
                    AppConstants.Fields.STATUS_CODE, statusCode,
                    AppConstants.Fields.HEADERS, Map.of(AppConstants.Http.CONTENT_TYPE, AppConstants.Http.APPLICATION_JSON),
                    AppConstants.Fields.BODY, JSON.writeValueAsString(body)
            );
        } catch (JsonProcessingException e) {
            throw new IllegalStateException(AppConstants.Errors.SERIALIZATION_FAILED, e);
        }
    }
}
