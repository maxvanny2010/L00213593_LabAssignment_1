package ie.atu.lab;

import java.time.Instant;
import java.util.List;
import java.util.UUID;

public class MessageService {

    private final MessageRepository repository;

    public MessageService(MessageRepository repository) {
        this.repository = repository;
    }

    public List<Message> getMessages() {
        return repository.findFirstPage(AppConstants.Limits.SCAN_PAGE_SIZE);
    }

    public Message createMessage(String text) {
        if (text == null) {
            throw new IllegalArgumentException(AppConstants.Errors.MESSAGE_MUST_BE_STRING);
        }

        String trimmed = text.trim();
        if (trimmed.isEmpty() || trimmed.length() > AppConstants.Limits.MAX_MESSAGE_LENGTH) {
            throw new IllegalArgumentException(AppConstants.Errors.MESSAGE_LENGTH);
        }

        Message message = new Message(
                UUID.randomUUID().toString(),
                trimmed,
                Instant.now().toString()
        );

        repository.save(message);
        return message;
    }
}
