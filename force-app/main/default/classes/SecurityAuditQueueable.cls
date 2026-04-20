public with sharing class SecurityAuditQueueable implements Queueable {
    private AiMetadataCopilotModels.SecurityAuditRequest request;

    public SecurityAuditQueueable(AiMetadataCopilotModels.SecurityAuditRequest request) {
        this.request = request;
    }

    public void execute(QueueableContext context) {
        new SecurityAuditOrchestrator().runAudit(request);
    }
}
