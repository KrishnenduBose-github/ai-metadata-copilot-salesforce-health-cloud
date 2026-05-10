public with sharing class DeploymentCompareQueueable implements Queueable {
    private AiMetadataCopilotModels.DeploymentCompareRequest request;

    public DeploymentCompareQueueable(AiMetadataCopilotModels.DeploymentCompareRequest request) {
        this.request = request;
    }

    public void execute(QueueableContext context) {
        try {
            new DeploymentRiskAssessmentService().assess(request);
        } catch (Exception ex) {
            System.debug(LoggingLevel.ERROR, 'DeploymentCompareQueueable failed: ' + ex.getMessage());
        }
    }
}
