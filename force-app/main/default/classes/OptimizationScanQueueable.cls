public with sharing class OptimizationScanQueueable implements Queueable {
    private AiMetadataCopilotModels.OptimizationScanRequest request;

    public OptimizationScanQueueable(AiMetadataCopilotModels.OptimizationScanRequest request) {
        this.request = request;
    }

    public void execute(QueueableContext context) {
        try {
            new AiAgentActionService().runOptimizationScan(request);
        } catch (Exception ex) {
            System.debug(LoggingLevel.ERROR, 'OptimizationScanQueueable failed: ' + ex.getMessage());
        }
    }
}
