const API_URL = window.APP_CONFIG.API_URL;
const loadButton = document.getElementById("load-messages");
const statusElement = document.getElementById("message-status");
const messageList = document.getElementById("message-list");

async function loadMessages() {
    loadButton.disabled = true;
    statusElement.textContent = "Loading messages...";
    messageList.replaceChildren();

    try {
        const response = await fetch(API_URL);

        if (!response.ok) {
            throw new Error(`HTTP ${response.status}`);
        }

        const data = await response.json();
        const messages = Array.isArray(data.messages) ? data.messages : [];

        if (messages.length === 0) {
            statusElement.textContent = "No messages found.";
            return;
        }

        for (const message of messages) {
            const item = document.createElement("li");
            item.textContent = message.message;
            messageList.appendChild(item);
        }

        statusElement.textContent = `${messages.length} message(s) loaded.`;
    } catch (error) {
        console.error("Failed to load messages:", error);
        statusElement.textContent = `Unable to load messages: ${error.message}`;
    } finally {
        loadButton.disabled = false;
    }
}

loadButton.addEventListener("click", loadMessages);
