public with sharing class AiMetadataCopilotModels {
    public class MatchedComponent {
        @AuraEnabled public Id usageId;
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
        @AuraEnabled public List<String> sourceMetadataTypes;
        @AuraEnabled public List<String> usageTypes;
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
        @AuraEnabled public NaturalLanguageInterpretation interpretation;
        @AuraEnabled public List<FilterCount> sourceTypeCounts;
        @AuraEnabled public List<FilterCount> usageTypeCounts;
        @AuraEnabled public List<String> indexedCoverage;
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
        @AuraEnabled public NaturalLanguageInterpretation interpretation;
        @AuraEnabled public DependencyGraphResponse dependencyGraph;
    }

    public class NaturalLanguageInterpretation {
        @AuraEnabled public String intent;
        @AuraEnabled public String queryType;
        @AuraEnabled public String targetApiName;
        @AuraEnabled public Decimal confidence;
        @AuraEnabled public String reason;
        @AuraEnabled public String resolutionMethod;
        @AuraEnabled public Boolean isAmbiguous;
        @AuraEnabled public List<String> alternatives;
    }

    public class FilterCount {
        @AuraEnabled public String label;
        @AuraEnabled public String value;
        @AuraEnabled public Integer count;
    }

    public class DependencyGraphNode {
        @AuraEnabled public String key;
        @AuraEnabled public String label;
        @AuraEnabled public String apiName;
        @AuraEnabled public String metadataType;
        @AuraEnabled public String category;
        @AuraEnabled public Integer depth;
        @AuraEnabled public String direction;
        @AuraEnabled public String confidence;
        @AuraEnabled public String evidence;
        @AuraEnabled public Datetime lastIndexedOn;
    }

    public class DependencyGraphEdge {
        @AuraEnabled public String key;
        @AuraEnabled public String sourceKey;
        @AuraEnabled public String targetKey;
        @AuraEnabled public String relationshipType;
        @AuraEnabled public String direction;
        @AuraEnabled public String confidence;
        @AuraEnabled public String evidence;
    }

    public class DependencyGraphResponse {
        @AuraEnabled public String rootKey;
        @AuraEnabled public String rootLabel;
        @AuraEnabled public List<DependencyGraphNode> nodes;
        @AuraEnabled public List<DependencyGraphEdge> edges;
        @AuraEnabled public Integer directDependencyCount;
        @AuraEnabled public Integer transitiveDependencyCount;
        @AuraEnabled public Integer maxDepth;
        @AuraEnabled public Boolean complete;
        @AuraEnabled public List<String> warnings;
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
        @AuraEnabled public String sourceSnapshotKey;
        @AuraEnabled public String targetSnapshotKey;
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
        @AuraEnabled public String sourceSnapshotKey;
        @AuraEnabled public String targetSnapshotKey;
        @AuraEnabled public Integer addedCount;
        @AuraEnabled public Integer removedCount;
        @AuraEnabled public Integer changedCount;
        @AuraEnabled public Boolean comparisonReady;
    }

    public class SnapshotSummary {
        @AuraEnabled public String snapshotKey;
        @AuraEnabled public String label;
        @AuraEnabled public Integer componentCount;
        @AuraEnabled public Datetime capturedOn;
        @AuraEnabled public String status;
    }

    public class DeploymentWorkspaceState {
        @AuraEnabled public Boolean snapshotStorageReady;
        @AuraEnabled public String setupMessage;
        @AuraEnabled public List<SnapshotSummary> snapshots;
    }

    public class DeploymentCaptureResponse {
        @AuraEnabled public Boolean saved;
        @AuraEnabled public String message;
        @AuraEnabled public SnapshotSummary snapshot;
        @AuraEnabled public DeploymentCompareResponse comparison;
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
        @AuraEnabled public String status;
        @AuraEnabled public String warningSummary;
        @AuraEnabled public Integer indexedItems;
        @AuraEnabled public Integer indexedSkippedCount;
        @AuraEnabled public Integer usageRelationships;
        @AuraEnabled public Integer usageSkippedCount;
        @AuraEnabled public Boolean snapshotSaved;
        @AuraEnabled public Boolean retentionCleanupApplied;
        @AuraEnabled public List<String> messages;
    }
}
