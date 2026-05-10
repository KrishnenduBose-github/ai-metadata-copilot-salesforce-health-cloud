public with sharing class MetadataRefreshQueueable implements Queueable {
    public void execute(QueueableContext context) {
        try {
            new MetadataExtractionOrchestrator().refreshMetadata('Current Sandbox');
        } catch (Exception ex) {
            System.debug(LoggingLevel.ERROR, 'MetadataRefreshQueueable failed: ' + ex.getMessage());
        }
    }
}
