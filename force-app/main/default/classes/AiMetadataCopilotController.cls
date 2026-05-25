public with sharing class AiMetadataCopilotController {
    @AuraEnabled
    public static AiMetadataCopilotModels.RefreshResponse refreshMetadataIndex() {
        MetadataExtractionOrchestrator.RefreshRunResult result =
            new MetadataExtractionOrchestrator().refreshMetadata('Current Sandbox');

        AiMetadataCopilotModels.RefreshResponse response =
            new AiMetadataCopilotModels.RefreshResponse();
        response.snapshotKey = result.snapshotKey;
        response.status = result.status;
        response.warningSummary = result.warningSummary;
        response.indexedItems = result.indexedItems;
        response.indexedSkippedCount = result.indexedSkippedCount;
        response.usageRelationships = result.usageRelationships;
        response.usageSkippedCount = result.usageSkippedCount;
        response.snapshotSaved = result.snapshotSaved;
        response.retentionCleanupApplied = result.retentionCleanupApplied;
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
    public static AiMetadataCopilotModels.MetadataSearchResponse searchMetadataDirect(
        String queryText,
        String queryType
    ) {
        AiMetadataCopilotModels.MetadataSearchRequest request =
            new AiMetadataCopilotModels.MetadataSearchRequest();
        request.queryText = trimToNull(queryText);
        request.queryType = trimToNull(queryType);
        return new AiAgentActionService().searchMetadata(request);
    }

    @AuraEnabled
    public static AiMetadataCopilotModels.ImpactAnalysisResponse analyzeImpact(
        AiMetadataCopilotModels.ImpactAnalysisRequest request
    ) {
        return new AiAgentActionService().analyzeImpact(request);
    }

    @AuraEnabled
    public static AiMetadataCopilotModels.ImpactAnalysisResponse analyzeImpactDirect(
        String queryText,
        String queryType
    ) {
        AiMetadataCopilotModels.ImpactAnalysisRequest request =
            new AiMetadataCopilotModels.ImpactAnalysisRequest();
        request.queryText = trimToNull(queryText);
        request.queryType = trimToNull(queryType);
        return new AiAgentActionService().analyzeImpact(request);
    }

    @AuraEnabled
    public static AiMetadataCopilotModels.SecurityAuditResponse runSecurityAudit(
        AiMetadataCopilotModels.SecurityAuditRequest request
    ) {
        return new AiAgentActionService().runSecurityAudit(request);
    }

    @AuraEnabled
    public static AiMetadataCopilotModels.SecurityAuditResponse runSecurityAuditDirect(
        String userPrompt
    ) {
        AiMetadataCopilotModels.SecurityAuditRequest request =
            new AiMetadataCopilotModels.SecurityAuditRequest();
        request.userPrompt = trimToNull(userPrompt);
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

    private static String trimToNull(String value) {
        return String.isBlank(value) ? null : value.trim();
    }
}
