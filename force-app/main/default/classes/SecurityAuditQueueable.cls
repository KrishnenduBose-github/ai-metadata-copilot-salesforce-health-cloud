public with sharing class SecurityAuditQueueable implements Queueable {
    private AiMetadataCopilotModels.SecurityAuditRequest request;

    public SecurityAuditQueueable(AiMetadataCopilotModels.SecurityAuditRequest request) {
        this.request = request;
    }

    public void execute(QueueableContext context) {
        try {
            new SecurityAuditOrchestrator().runAudit(request);
        } catch (Exception ex) {
            System.debug(LoggingLevel.ERROR, 'SecurityAuditQueueable failed: ' + ex.getMessage());
        }
    }
}
