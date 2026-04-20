public with sharing class MetadataRefreshQueueable implements Queueable {
    public void execute(QueueableContext context) {
        new MetadataExtractionOrchestrator().refreshMetadata('Current Sandbox');
    }
}
