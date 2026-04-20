public with sharing class DeploymentCompareQueueable implements Queueable {
    private AiMetadataCopilotModels.DeploymentCompareRequest request;

    public DeploymentCompareQueueable(AiMetadataCopilotModels.DeploymentCompareRequest request) {
        this.request = request;
    }

    public void execute(QueueableContext context) {
        new DeploymentRiskAssessmentService().assess(request);
    }
}
