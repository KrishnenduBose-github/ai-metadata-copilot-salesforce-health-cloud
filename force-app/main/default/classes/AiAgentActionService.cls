public with sharing class AiAgentActionService {
    private MetadataNormalizationService normalizationService = new MetadataNormalizationService();
    private MetadataSearchService metadataSearchService = new MetadataSearchService();
    private MetadataImpactAnalysisService metadataImpactAnalysisService =
        new MetadataImpactAnalysisService(metadataSearchService);
    private MetadataExplainabilityService explainabilityService = new MetadataExplainabilityService();
    private AiPromptGroundingService promptGroundingService = new AiPromptGroundingService();
    private AiGuardrailService guardrailService = new AiGuardrailService();
    private AiResponseFormatter responseFormatter = new AiResponseFormatter();

    public AiMetadataCopilotModels.MetadataSearchResponse searchMetadata(
        AiMetadataCopilotModels.MetadataSearchRequest request
    ) {
        if (String.isBlank(request.queryText)) {
            request = normalizationService.normalizeSearchRequest(request.userPrompt);
        }

        guardrailService.validateReadOnlyPrompt(request.userPrompt);

        List<MetadataSearchService.SearchResultRow> rows = request.queryType == 'ObjectUsage'
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
        response.summary =
            'Found ' + String.valueOf(rows.size()) + ' grounded metadata relationship(s) for ' + request.queryText + '.';
        response.explanation = explainabilityService.buildSearchExplanation(components);
        response.recommendations = explainabilityService.buildSearchRecommendations(
            request.queryType,
            rows.size()
        );
        return response;
    }

    public AiMetadataCopilotModels.ImpactAnalysisResponse analyzeImpact(
        AiMetadataCopilotModels.ImpactAnalysisRequest request
    ) {
        if (String.isBlank(request.queryText)) {
            request = normalizationService.normalizeImpactRequest(request.userPrompt);
        }

        MetadataImpactAnalysisService.ImpactSummaryResult summaryResult = request.queryType == 'ObjectUsage'
            ? metadataImpactAnalysisService.analyzeObjectUsage(request.queryText)
            : metadataImpactAnalysisService.analyzeFieldUsage(request.queryText);
        List<MetadataSearchService.SearchResultRow> rows = request.queryType == 'ObjectUsage'
            ? metadataSearchService.searchObjectUsage(request.queryText)
            : metadataSearchService.searchFieldUsage(request.queryText);
        List<AiMetadataCopilotModels.MatchedComponent> impactedComponents =
            promptGroundingService.buildGroundedComponents(rows);

        AiMetadataCopilotModels.ImpactAnalysisResponse response =
            new AiMetadataCopilotModels.ImpactAnalysisResponse();
        response.summary = summaryResult.summary;
        response.severity = summaryResult.impactLevel;
        response.score = responseFormatter.toScore(rows.size(), 12, 100);
        response.explanation = explainabilityService.buildSearchExplanation(impactedComponents);
        response.impactedComponents = impactedComponents;
        response.assessmentId = summaryResult.assessmentId;
        response.deploymentCautions = explainabilityService.buildImpactRecommendations(summaryResult.impactLevel);
        response.regressionTestAreas = new RegressionTestRecommendationService().buildImpactAreas(
            request.queryText,
            impactedComponents
        );
        return response;
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
        if (findings.isEmpty() || !Schema.sObjectType.Optimization_Finding__c.isCreateable()) {
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

        insert recordsToUpsert;
    }

}
