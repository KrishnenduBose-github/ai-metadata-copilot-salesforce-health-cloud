public with sharing class AiAgentActionService {
    @TestVisible
    private MetadataNormalizationService normalizationService;
    @TestVisible
    private MetadataSearchService metadataSearchService;
    @TestVisible
    private MetadataImpactAnalysisService metadataImpactAnalysisService;
    @TestVisible
    private MetadataExplainabilityService explainabilityService;
    @TestVisible
    private AiPromptGroundingService promptGroundingService;
    @TestVisible
    private AiGuardrailService guardrailService;
    @TestVisible
    private AiResponseFormatter responseFormatter;

    public AiAgentActionService() {
        this(
            new MetadataNormalizationService(),
            new MetadataSearchService(),
            new MetadataExplainabilityService(),
            new AiPromptGroundingService(),
            new AiGuardrailService(),
            new AiResponseFormatter()
        );
    }

    @TestVisible
    private AiAgentActionService(
        MetadataNormalizationService normalizationService,
        MetadataSearchService metadataSearchService,
        MetadataExplainabilityService explainabilityService,
        AiPromptGroundingService promptGroundingService,
        AiGuardrailService guardrailService,
        AiResponseFormatter responseFormatter
    ) {
        this.normalizationService = normalizationService;
        this.metadataSearchService = metadataSearchService;
        this.explainabilityService = explainabilityService;
        this.promptGroundingService = promptGroundingService;
        this.guardrailService = guardrailService;
        this.responseFormatter = responseFormatter;
        this.metadataImpactAnalysisService = new MetadataImpactAnalysisService(this.metadataSearchService);
    }

    public AiMetadataCopilotModels.MetadataSearchResponse searchMetadata(
        AiMetadataCopilotModels.MetadataSearchRequest request
    ) {
        MetadataLogger.info('AiAgentActionService', 'searchMetadata invoked: queryText=' + request.queryText + ', userPrompt=' + request.userPrompt);

        if (String.isBlank(request.queryText)) {
            if (String.isBlank(request.userPrompt)) {
                return emptySearchResponse('No search input provided.');
            }
            guardrailService.validateReadOnlyPrompt(request.userPrompt);
            request = normalizationService.normalizeSearchRequest(request.userPrompt);
        } else {
            guardrailService.validateReadOnlyPrompt(request.queryText);
        }

        if (String.isBlank(request.queryText)) {
            MetadataLogger.warn('AiAgentActionService', 'Normalization could not extract a metadata token from: ' + request.userPrompt);
            return emptySearchResponse('Could not identify a metadata token in your query. Try an explicit API name like Account.Industry or Patient_Status__c.');
        }

        List<MetadataSearchService.SearchResultRow> rows = 'ObjectUsage' == request.queryType
            ? metadataSearchService.searchObjectUsage(request.queryText)
            : metadataSearchService.searchFieldUsage(request.queryText);
        List<AiMetadataCopilotModels.MatchedComponent> components =
            promptGroundingService.buildGroundedComponents(rows);

        AiMetadataCopilotModels.MetadataSearchResponse response =
            new AiMetadataCopilotModels.MetadataSearchResponse();
        response.normalizedQueryText = request.queryText;
        response.normalizedQueryType = request.queryType;
        response.matchedComponents = components;
        response.score = responseFormatter.toScore(rows.size(), 10, 100);
        response.severity = responseFormatter.severityFromScore(response.score);
        response.summary = buildSearchSummaryMessage(request, rows.size());
        response.explanation = explainabilityService.buildSearchExplanation(components);
        response.recommendations = explainabilityService.buildSearchRecommendations(
            request.queryType,
            rows.size()
        );

        MetadataLogger.info('AiAgentActionService', 'searchMetadata completed: ' + rows.size() + ' rows for ' + request.queryText);
        return response;
    }

    private static String buildSearchSummaryMessage(
        AiMetadataCopilotModels.MetadataSearchRequest request,
        Integer matchCount
    ) {
        String target = String.isBlank(request.queryText) ? request.userPrompt : request.queryText;
        if (matchCount == 0) {
            return 'No metadata relationships found for "' + target + '". Try refreshing metadata first (Admin tab) if the org changed recently.';
        }
        return 'Found ' + String.valueOf(matchCount) + ' grounded metadata relationship(s) for "' + target + '".';
    }

    public AiMetadataCopilotModels.ImpactAnalysisResponse analyzeImpact(
        AiMetadataCopilotModels.ImpactAnalysisRequest request
    ) {
        MetadataLogger.info('AiAgentActionService', 'analyzeImpact invoked: queryText=' + request.queryText + ', userPrompt=' + request.userPrompt);

        if (String.isBlank(request.queryText)) {
            if (String.isBlank(request.userPrompt)) {
                return emptyImpactResponse('No impact analysis input provided.');
            }
            request = normalizationService.normalizeImpactRequest(request.userPrompt);
        }

        if (String.isBlank(request.queryText)) {
            MetadataLogger.warn('AiAgentActionService', 'Normalization could not extract impact token from: ' + request.userPrompt);
            return emptyImpactResponse('Could not identify a metadata token for impact analysis. Use explicit API name syntax.');
        }

        List<MetadataSearchService.SearchResultRow> rows = 'ObjectUsage' == request.queryType
            ? metadataSearchService.searchObjectUsage(request.queryText)
            : metadataSearchService.searchFieldUsage(request.queryText);
        MetadataImpactAnalysisService.ImpactSummaryResult summaryResult = 'ObjectUsage' == request.queryType
            ? metadataImpactAnalysisService.analyzeObjectUsage(rows, request.queryText)
            : metadataImpactAnalysisService.analyzeFieldUsage(rows, request.queryText);
        List<AiMetadataCopilotModels.MatchedComponent> impactedComponents =
            promptGroundingService.buildGroundedComponents(rows);

        AiMetadataCopilotModels.ImpactAnalysisResponse response =
            new AiMetadataCopilotModels.ImpactAnalysisResponse();
        response.summary = summaryResult.summary;
        response.severity = summaryResult.impactLevel;
        response.score = responseFormatter.toScore(rows.size(), 12, 100);
        response.explanation = rows.isEmpty()
            ? 'No dependent components found for "' + request.queryText + '". Refresh metadata for current results.'
            : explainabilityService.buildSearchExplanation(impactedComponents);
        response.impactedComponents = impactedComponents;
        response.assessmentId = summaryResult.assessmentId;
        response.deploymentCautions = explainabilityService.buildImpactRecommendations(summaryResult.impactLevel);
        response.regressionTestAreas = new RegressionTestRecommendationService().buildImpactAreas(
            request.queryText,
            impactedComponents
        );

        MetadataLogger.info('AiAgentActionService', 'analyzeImpact completed: ' + rows.size() + ' rows for ' + request.queryText);
        return response;
    }

    private static AiMetadataCopilotModels.MetadataSearchResponse emptySearchResponse(String message) {
        AiMetadataCopilotModels.MetadataSearchResponse empty =
            new AiMetadataCopilotModels.MetadataSearchResponse();
        empty.normalizedQueryType = 'FieldUsage';
        empty.matchedComponents = new List<AiMetadataCopilotModels.MatchedComponent>();
        empty.score = 0;
        empty.severity = 'Low';
        empty.summary = message;
        empty.explanation = 'Use Direct API Name mode with explicit field or object names for reliable results.';
        empty.recommendations = new List<String>{
            'Use an exact API name ending with __c for custom fields.',
            'Search by Object.Field format (e.g. Account.Industry).',
            'Refresh metadata before searching if the org recently changed.'
        };
        return empty;
    }

    private static AiMetadataCopilotModels.ImpactAnalysisResponse emptyImpactResponse(String message) {
        AiMetadataCopilotModels.ImpactAnalysisResponse empty =
            new AiMetadataCopilotModels.ImpactAnalysisResponse();
        empty.summary = message;
        empty.severity = 'Low';
        empty.score = 0;
        empty.explanation = 'Use Direct API Name mode with explicit field or object names for reliable results.';
        empty.impactedComponents = new List<AiMetadataCopilotModels.MatchedComponent>();
        empty.deploymentCautions = new List<String>();
        empty.regressionTestAreas = new List<String>();
        return empty;
    }

    public AiMetadataCopilotModels.SecurityAuditResponse runSecurityAudit(
        AiMetadataCopilotModels.SecurityAuditRequest request
    ) {
        if (String.isBlank(request.objectApiName) && String.isBlank(request.fieldApiName)) {
            request = normalizationService.normalizeSecurityRequest(request.userPrompt);
        }

        return new SecurityAuditOrchestrator().runAudit(request);
    }

    public AiMetadataCopilotModels.DeploymentCompareResponse compareEnvironments(
        AiMetadataCopilotModels.DeploymentCompareRequest request
    ) {
        return new DeploymentRiskAssessmentService().assess(request);
    }

    public AiMetadataCopilotModels.DocumentationResponse generateDocumentation(
        AiMetadataCopilotModels.DocumentationRequest request
    ) {
        if (request.requestType == 'ReleaseNote') {
            return new ReleaseNoteGenerationService().generateReleaseNote(request);
        }

        return new MetadataDocumentationService().generate(request);
    }

    public AiMetadataCopilotModels.OptimizationScanResponse runOptimizationScan(
        AiMetadataCopilotModels.OptimizationScanRequest request
    ) {
        List<MetadataExtractionService.ExtractedMetadataItem> extractedItems =
            new MetadataExtractionService().extractAllSupportedMetadata();
        List<AiMetadataCopilotModels.OptimizationFindingRow> findings =
            new List<AiMetadataCopilotModels.OptimizationFindingRow>();

        findings.addAll(new UnusedMetadataScanner().scan());
        findings.addAll(new DuplicateFlowScanner().scan(extractedItems));
        findings.addAll(new TriggerRiskScanner().scan(extractedItems));
        findings.addAll(new HardcodedIdScanner().scan(extractedItems));

        persistOptimizationFindings(findings);

        AiMetadataCopilotModels.OptimizationScanResponse response =
            new AiMetadataCopilotModels.OptimizationScanResponse();
        response.findings = findings;
        response.score = responseFormatter.toScore(findings.size(), 10, 100);
        response.severity = responseFormatter.severityFromScore(response.score);
        response.summary = 'Optimization scanner found ' + String.valueOf(findings.size()) + ' issue(s).';
        response.explanation = findings.isEmpty()
            ? 'No grounded optimization findings were detected in this scan.'
            : 'Findings are grounded in indexed metadata usage and freshly extracted Apex/Flow definitions.';
        return response;
    }

    private void persistOptimizationFindings(
        List<AiMetadataCopilotModels.OptimizationFindingRow> findings
    ) {
        if (
            findings.isEmpty()
            || !MetadataRetentionService.optionalWritesAllowed()
            || !Schema.sObjectType.Optimization_Finding__c.isCreateable()
        ) {
            return;
        }

        List<Optimization_Finding__c> recordsToUpsert = new List<Optimization_Finding__c>();
        Integer findingIndex = 0;
        for (AiMetadataCopilotModels.OptimizationFindingRow finding : findings) {
            Optimization_Finding__c record = new Optimization_Finding__c();
            record.Finding_Key__c = 'Optimization:' + String.valueOf(System.now().getTime()) + ':' + String.valueOf(findingIndex);
            record.Finding_Type__c = finding.findingType;
            record.Severity__c = finding.severity;
            record.Metadata_Key__c = finding.metadataKey;
            record.Summary__c = finding.summary;
            record.Recommendation__c = finding.recommendation;
            record.Status__c = 'Open';
            recordsToUpsert.add(record);
            findingIndex++;
        }

        if (recordsToUpsert.isEmpty()) {
            return;
        }

        try {
            Database.insert(recordsToUpsert, false);
        } catch (Exception ex) {
            MetadataLogger.warn('AiAgentActionService', 'Failed to persist optimization findings: ' + ex.getMessage());
        }
    }

}
