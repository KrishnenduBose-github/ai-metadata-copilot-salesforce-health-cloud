public with sharing class OptimizationScanQueueable implements Queueable {
    private AiMetadataCopilotModels.OptimizationScanRequest request;

    public OptimizationScanQueueable(AiMetadataCopilotModels.OptimizationScanRequest request) {
        this.request = request;
    }

    public void execute(QueueableContext context) {
        new AiAgentActionService().runOptimizationScan(request);
    }
}
