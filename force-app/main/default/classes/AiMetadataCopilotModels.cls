public with sharing class AiMetadataCopilotModels {
    public class MatchedComponent {
        @AuraEnabled public String metadataKey;
        @AuraEnabled public String metadataName;
        @AuraEnabled public String metadataType;
        @AuraEnabled public String usageType;
        @AuraEnabled public String context;
    }

    public class Recommendation {
        @AuraEnabled public String title;
        @AuraEnabled public String detail;
    }

    public class MetadataSearchRequest {
        @AuraEnabled public String userPrompt;
        @AuraEnabled public String queryText;
        @AuraEnabled public String queryType;
    }

    public class MetadataSearchResponse {
        @AuraEnabled public String summary;
        @AuraEnabled public String severity;
        @AuraEnabled public String explanation;
        @AuraEnabled public Decimal score;
        @AuraEnabled public String normalizedQueryText;
        @AuraEnabled public String normalizedQueryType;
        @AuraEnabled public List<MatchedComponent> matchedComponents;
        @AuraEnabled public List<String> recommendations;
    }

    public class ImpactAnalysisRequest {
        @AuraEnabled public String userPrompt;
        @AuraEnabled public String metadataKey;
        @AuraEnabled public String queryText;
        @AuraEnabled public String queryType;
    }

    public class ImpactAnalysisResponse {
        @AuraEnabled public String summary;
        @AuraEnabled public String severity;
        @AuraEnabled public String explanation;
        @AuraEnabled public Decimal score;
        @AuraEnabled public List<String> deploymentCautions;
        @AuraEnabled public List<String> regressionTestAreas;
        @AuraEnabled public List<MatchedComponent> impactedComponents;
        @AuraEnabled public Id assessmentId;
    }

    public class SecurityAuditRequest {
        @AuraEnabled public String userPrompt;
        @AuraEnabled public String objectApiName;
        @AuraEnabled public String fieldApiName;
    }

    public class SecurityFindingRow {
        @AuraEnabled public String findingType;
        @AuraEnabled public String severity;
        @AuraEnabled public String objectApiName;
        @AuraEnabled public String fieldApiName;
        @AuraEnabled public String permissionArtifact;
        @AuraEnabled public String summary;
        @AuraEnabled public String recommendation;
    }

    public class SecurityAuditResponse {
        @AuraEnabled public String summary;
        @AuraEnabled public String severity;
        @AuraEnabled public String explanation;
        @AuraEnabled public Decimal score;
        @AuraEnabled public String runKey;
        @AuraEnabled public List<SecurityFindingRow> findings;
        @AuraEnabled public List<String> recommendations;
    }

    public class DeploymentCompareRequest {
        @AuraEnabled public String sourceEnvironment;
        @AuraEnabled public String targetEnvironment;
        @AuraEnabled public String metadataScope;
    }

    public class DeploymentFindingRow {
        @AuraEnabled public String findingType;
        @AuraEnabled public String severity;
        @AuraEnabled public String metadataKey;
        @AuraEnabled public String summary;
        @AuraEnabled public String recommendation;
    }

    public class DeploymentCompareResponse {
        @AuraEnabled public String summary;
        @AuraEnabled public String severity;
        @AuraEnabled public Decimal readinessScore;
        @AuraEnabled public String explanation;
        @AuraEnabled public String assessmentKey;
        @AuraEnabled public List<DeploymentFindingRow> findings;
        @AuraEnabled public List<String> rollbackChecklist;
        @AuraEnabled public List<String> testChecklist;
    }

    public class DocumentationRequest {
        @AuraEnabled public String requestType;
        @AuraEnabled public String metadataKey;
        @AuraEnabled public String userPrompt;
    }

    public class DocumentationResponse {
        @AuraEnabled public String summary;
        @AuraEnabled public String technicalSummary;
        @AuraEnabled public String businessSummary;
        @AuraEnabled public String explanation;
        @AuraEnabled public Id requestId;
    }

    public class OptimizationScanRequest {
        @AuraEnabled public String scanType;
    }

    public class OptimizationFindingRow {
        @AuraEnabled public String findingType;
        @AuraEnabled public String severity;
        @AuraEnabled public String metadataKey;
        @AuraEnabled public String summary;
        @AuraEnabled public String recommendation;
    }

    public class OptimizationScanResponse {
        @AuraEnabled public String summary;
        @AuraEnabled public String severity;
        @AuraEnabled public Decimal score;
        @AuraEnabled public String explanation;
        @AuraEnabled public List<OptimizationFindingRow> findings;
    }

    public class RefreshResponse {
        @AuraEnabled public String snapshotKey;
        @AuraEnabled public Integer indexedItems;
        @AuraEnabled public Integer usageRelationships;
        @AuraEnabled public List<String> messages;
    }
}
