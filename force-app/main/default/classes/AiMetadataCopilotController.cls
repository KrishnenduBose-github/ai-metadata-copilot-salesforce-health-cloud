public with sharing class AiMetadataCopilotController {
    @AuraEnabled
    public static AiMetadataCopilotModels.RefreshResponse refreshMetadataIndex() {
        MetadataExtractionOrchestrator.RefreshRunResult result =
            new MetadataExtractionOrchestrator().refreshMetadata('Current Sandbox');

        AiMetadataCopilotModels.RefreshResponse response =
            new AiMetadataCopilotModels.RefreshResponse();
        response.snapshotKey = result.snapshotKey;
        response.indexedItems = result.indexedItems;
        response.usageRelationships = result.usageRelationships;
        response.messages = result.messages;
        return response;
    }

    @AuraEnabled
    public static AiMetadataCopilotModels.MetadataSearchResponse searchMetadata(
        AiMetadataCopilotModels.MetadataSearchRequest request
    ) {
        return new AiAgentActionService().searchMetadata(request);
    }

    @AuraEnabled
    public static AiMetadataCopilotModels.ImpactAnalysisResponse analyzeImpact(
        AiMetadataCopilotModels.ImpactAnalysisRequest request
    ) {
        return new AiAgentActionService().analyzeImpact(request);
    }

    @AuraEnabled
    public static AiMetadataCopilotModels.SecurityAuditResponse runSecurityAudit(
        AiMetadataCopilotModels.SecurityAuditRequest request
    ) {
        return new AiAgentActionService().runSecurityAudit(request);
    }

    @AuraEnabled
    public static AiMetadataCopilotModels.DeploymentCompareResponse compareEnvironments(
        AiMetadataCopilotModels.DeploymentCompareRequest request
    ) {
        return new AiAgentActionService().compareEnvironments(request);
    }

    @AuraEnabled
    public static AiMetadataCopilotModels.DocumentationResponse generateDocumentation(
        AiMetadataCopilotModels.DocumentationRequest request
    ) {
        return new AiAgentActionService().generateDocumentation(request);
    }

    @AuraEnabled
    public static AiMetadataCopilotModels.OptimizationScanResponse runOptimizationScan(
        AiMetadataCopilotModels.OptimizationScanRequest request
    ) {
        return new AiAgentActionService().runOptimizationScan(request);
    }

    @AuraEnabled
    public static MetadataHealthService.HealthStatus checkHealth() {
        return MetadataHealthService.check();
    }
}
