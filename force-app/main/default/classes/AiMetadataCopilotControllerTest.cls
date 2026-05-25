@IsTest
private class AiMetadataCopilotControllerTest {
    @TestSetup
    static void setupData() {
        MetadataCopilotTestDataFactory.createFullScenario();
    }

    @IsTest
    static void searchMetadataReturnsGroundedFieldUsage() {
        Test.startTest();
        AiMetadataCopilotModels.MetadataSearchResponse response =
            AiMetadataCopilotController.searchMetadata(
                MetadataCopilotTestDataFactory.searchRequest(
                    'Where is Account.CustomerPriority__c used?'
                )
            );
        Test.stopTest();

        System.assertEquals('Account.CustomerPriority__c', response.normalizedQueryText);
        System.assertEquals('FieldUsage', response.normalizedQueryType);
        System.assert(response.matchedComponents.size() > 0, 'Expected at least one field usage match.');
        System.assertNotEquals(null, response.summary);
    }

    @IsTest
    static void searchResponseContainsUniqueUsageIds() {
        Test.startTest();
        AiMetadataCopilotModels.MetadataSearchResponse response =
            AiMetadataCopilotController.searchMetadata(
                MetadataCopilotTestDataFactory.searchRequest(
                    'Where is Account.CustomerPriority__c used?'
                )
            );
        Test.stopTest();

        System.assert(response.matchedComponents.size() > 0, 'Expected at least one matched component.');
        Set<Id> usageIds = new Set<Id>();
        for (AiMetadataCopilotModels.MatchedComponent component : response.matchedComponents) {
            System.assertNotEquals(null, component.usageId, 'Every matched component must have a non-null usageId.');
            System.assert(!usageIds.contains(component.usageId), 'usageId must be unique across all matched components.');
            usageIds.add(component.usageId);
        }
    }

    @IsTest
    static void searchMetadataDirectReturnsGroundedFieldUsage() {
        Test.startTest();
        AiMetadataCopilotModels.MetadataSearchResponse response =
            AiMetadataCopilotController.searchMetadataDirect(
                'Account.CustomerPriority__c',
                'FieldUsage'
            );
        Test.stopTest();

        System.assertEquals('Account.CustomerPriority__c', response.normalizedQueryText);
        System.assertEquals('FieldUsage', response.normalizedQueryType);
        System.assert(response.matchedComponents.size() > 0, 'Expected direct search to return field usage.');
    }

    @IsTest
    static void searchMetadataDirectTrimsVisibleFieldInput() {
        Test.startTest();
        AiMetadataCopilotModels.MetadataSearchResponse response =
            AiMetadataCopilotController.searchMetadataDirect(
                '  Account.CustomerPriority__c  ',
                'FieldUsage'
            );
        Test.stopTest();

        System.assertEquals('Account.CustomerPriority__c', response.normalizedQueryText);
        System.assertEquals('FieldUsage', response.normalizedQueryType);
        System.assert(response.matchedComponents.size() > 0, 'Whitespace around UI input should not lose matches.');
    }

    @IsTest
    static void searchMetadataDirectBlankInputReturnsHelpfulState() {
        Test.startTest();
        AiMetadataCopilotModels.MetadataSearchResponse response =
            AiMetadataCopilotController.searchMetadataDirect(
                '   ',
                'FieldUsage'
            );
        Test.stopTest();

        System.assertEquals(0, response.matchedComponents.size());
        System.assert(response.summary.contains('No search input provided'), 'Blank direct input should be explicit.');
        System.assertNotEquals(null, response.recommendations);
        System.assert(response.recommendations.size() > 0, 'Blank direct input should guide the user.');
    }

    @IsTest
    static void searchMetadataDirectQualifiedInputIgnoresSameFieldOnOtherObject() {
        Metadata_Item__c apexItem = [
            SELECT Id, Metadata_Key__c
            FROM Metadata_Item__c
            WHERE Metadata_Type__c = 'ApexClass'
            LIMIT 1
        ];
        insertFieldUsage(
            apexItem,
            'Lead.CustomerPriority__c',
            'CustomField:Lead.CustomerPriority__c',
            'Lead',
            'CustomerPriority__c',
            'CustomerPriority__c'
        );
        insertFieldUsage(
            apexItem,
            'Case.CustomerPriority__c',
            'CustomField:Case.CustomerPriority__c',
            'Case',
            'CustomerPriority__c',
            'CustomerPriority__c'
        );

        Test.startTest();
        AiMetadataCopilotModels.MetadataSearchResponse response =
            AiMetadataCopilotController.searchMetadataDirect(
                'Account.CustomerPriority__c',
                'FieldUsage'
            );
        Test.stopTest();

        System.assert(response.matchedComponents.size() > 0, 'Expected Account field usage matches.');
        for (AiMetadataCopilotModels.MatchedComponent component : response.matchedComponents) {
            System.assertEquals(
                'CustomField:Account.CustomerPriority__c',
                component.metadataKey,
                'Direct qualified searches must not broaden to Case.CustomerPriority__c.'
            );
        }
    }

    @IsTest
    static void qualifiedFieldSearchDoesNotReturnOtherObjectsWithSameFieldName() {
        Metadata_Item__c apexItem = [
            SELECT Id, Metadata_Key__c
            FROM Metadata_Item__c
            WHERE Metadata_Type__c = 'ApexClass'
            LIMIT 1
        ];
        Metadata_Item__c contactField = new Metadata_Item__c(
            Name = 'Contact.CustomerPriority__c',
            Metadata_Key__c = 'CustomField:Contact.CustomerPriority__c',
            Metadata_Type__c = 'CustomField',
            Api_Name__c = 'Contact.CustomerPriority__c',
            Developer_Name__c = 'CustomerPriority',
            Object_API_Name__c = 'Contact',
            Field_API_Name__c = 'CustomerPriority__c',
            Status__c = 'Active',
            Last_Indexed_On__c = System.now()
        );
        insert contactField;
        insert new Metadata_Usage__c(
            Usage_Key__c = apexItem.Metadata_Key__c + '->UsesField:Contact.CustomerPriority__c',
            Source_Metadata__c = apexItem.Id,
            Target_Metadata__c = contactField.Id,
            Source_Key__c = apexItem.Metadata_Key__c,
            Target_Key__c = contactField.Metadata_Key__c,
            Usage_Type__c = 'UsesField',
            Source_Type__c = 'ApexClass',
            Target_Type__c = 'CustomField',
            Match_Text__c = 'CustomerPriority__c',
            Context_Snippet__c = 'Matched token: CustomerPriority__c',
            Last_Analyzed_On__c = System.now()
        );

        Test.startTest();
        AiMetadataCopilotModels.MetadataSearchResponse response =
            AiMetadataCopilotController.searchMetadata(
                MetadataCopilotTestDataFactory.searchRequest(
                    'Where is Account.CustomerPriority__c used?'
                )
            );
        Test.stopTest();

        System.assert(response.matchedComponents.size() > 0, 'Expected Account field usage matches.');
        for (AiMetadataCopilotModels.MatchedComponent component : response.matchedComponents) {
            System.assertEquals(
                'CustomField:Account.CustomerPriority__c',
                component.metadataKey,
                'Qualified field searches must stay scoped to the requested object.'
            );
        }
    }

    @IsTest
    static void emptySearchReturnsGracefulState() {
        Test.startTest();
        AiMetadataCopilotModels.MetadataSearchResponse response =
            AiMetadataCopilotController.searchMetadata(
                MetadataCopilotTestDataFactory.searchRequest('Where is NonExistentField__c used?')
            );
        Test.stopTest();

        System.assertNotEquals(null, response);
        System.assertEquals(0, response.matchedComponents.size());
        System.assertNotEquals(null, response.summary);
        System.assertNotEquals(null, response.explanation);
        System.assert(!response.summary.contains('null'), 'Summary should never contain literal null string.');
    }

    @IsTest
    static void unparseablePromptReturnsHelpfulMessage() {
        Test.startTest();
        AiMetadataCopilotModels.MetadataSearchResponse response =
            AiMetadataCopilotController.searchMetadata(
                MetadataCopilotTestDataFactory.searchRequest('...')
            );
        Test.stopTest();

        System.assertNotEquals(null, response);
        System.assertEquals(0, response.matchedComponents.size());
        System.assert(response.summary.contains('Could not identify'), 'Should return helpful guidance.');
        System.assertNotEquals(null, response.recommendations);
        System.assert(response.recommendations.size() > 0, 'Should have recommendations.');
    }

    @IsTest
    static void searchMetadataReturnsGroundedObjectUsage() {
        Test.startTest();
        AiMetadataCopilotModels.MetadataSearchResponse response =
            AiMetadataCopilotController.searchMetadata(
                MetadataCopilotTestDataFactory.searchRequest('Show all components related to Account')
            );
        Test.stopTest();

        System.assertEquals('ObjectUsage', response.normalizedQueryType);
        System.assertEquals('Account', response.normalizedQueryText);
        System.assert(response.matchedComponents.size() > 0, 'Expected at least one object usage match.');
    }

    @IsTest
    static void analyzeImpactReturnsAssessmentAndRecommendations() {
        Test.startTest();
        AiMetadataCopilotModels.ImpactAnalysisResponse response =
            AiMetadataCopilotController.analyzeImpact(
                MetadataCopilotTestDataFactory.impactRequest(
                    'If I rename Account.CustomerPriority__c what breaks?'
                )
            );
        Test.stopTest();

        System.assertNotEquals(null, response.assessmentId);
        System.assert(response.impactedComponents.size() > 0, 'Expected impacted components.');
        System.assert(response.deploymentCautions.size() > 0, 'Expected deployment cautions.');
        System.assert(response.regressionTestAreas.size() > 0, 'Expected regression test areas.');
    }

    @IsTest
    static void analyzeImpactDirectReturnsImpactedComponents() {
        Test.startTest();
        AiMetadataCopilotModels.ImpactAnalysisResponse response =
            AiMetadataCopilotController.analyzeImpactDirect(
                'Account.CustomerPriority__c',
                'FieldUsage'
            );
        Test.stopTest();

        System.assert(response.impactedComponents.size() > 0, 'Expected direct impact to return impacted components.');
        System.assert(response.summary.contains('Account.CustomerPriority__c'));
    }

    @IsTest
    static void analyzeImpactDirectTrimsVisibleFieldInput() {
        Test.startTest();
        AiMetadataCopilotModels.ImpactAnalysisResponse response =
            AiMetadataCopilotController.analyzeImpactDirect(
                '  Account.CustomerPriority__c  ',
                'FieldUsage'
            );
        Test.stopTest();

        System.assert(response.impactedComponents.size() > 0, 'Whitespace around impact input should not lose matches.');
        System.assert(response.summary.contains('Account.CustomerPriority__c'));
    }

    @IsTest
    static void analyzeImpactReusesExistingAssessmentForSameQuery() {
        insert new Impact_Assessment__c(
            Query_Text__c = 'Account.CustomerPriority__c',
            Query_Type__c = 'FieldUsage',
            Summary__c = 'Old summary',
            Impact_Level__c = 'Low',
            Match_Count__c = 0
        );

        Integer beforeCount = [SELECT COUNT() FROM Impact_Assessment__c];

        Test.startTest();
        AiMetadataCopilotModels.ImpactAnalysisResponse response =
            AiMetadataCopilotController.analyzeImpact(
                MetadataCopilotTestDataFactory.impactRequest(
                    'If I rename Account.CustomerPriority__c what breaks?'
                )
            );
        Test.stopTest();

        Integer afterCount = [SELECT COUNT() FROM Impact_Assessment__c];
        Impact_Assessment__c updatedAssessment = [
            SELECT Id, Summary__c, Match_Count__c
            FROM Impact_Assessment__c
            WHERE Id = :response.assessmentId
        ];

        System.assertEquals(beforeCount, afterCount, 'Expected the service to reuse an existing assessment record.');
        System.assert(updatedAssessment.Match_Count__c > 0, 'Expected the reused assessment to be updated.');
        System.assert(updatedAssessment.Summary__c.contains('Account.CustomerPriority__c'));
    }

    @IsTest
    static void analyzeImpactWithUnparseablePromptReturnsEmptyGracefully() {
        Test.startTest();
        AiMetadataCopilotModels.ImpactAnalysisResponse response =
            AiMetadataCopilotController.analyzeImpact(
                MetadataCopilotTestDataFactory.impactRequest('?')
            );
        Test.stopTest();

        System.assertNotEquals(null, response);
        System.assertEquals(0, response.impactedComponents.size());
        System.assertNotEquals(null, response.summary);
    }

    @IsTest
    static void healthCheckReturnsStatus() {
        Test.startTest();
        MetadataHealthService.HealthStatus status = AiMetadataCopilotController.checkHealth();
        Test.stopTest();

        System.assertNotEquals(null, status);
        System.assert(status.indexedItemCount >= 0, 'indexedItemCount should be non-negative.');
        System.assert(status.usageRecordCount >= 0, 'usageRecordCount should be non-negative.');
        System.assertNotEquals(null, status.warnings);
        System.assertNotEquals(null, status.recommendations);
    }

    @IsTest
    static void runSecurityAuditPersistsAuditRun() {
        Test.startTest();
        AiMetadataCopilotModels.SecurityAuditResponse response =
            AiMetadataCopilotController.runSecurityAudit(
                MetadataCopilotTestDataFactory.securityRequest(
                    'Who can access Account.CustomerPriority__c?'
                )
            );
        Test.stopTest();

        System.assertNotEquals(null, response.runKey);
        System.assertNotEquals(null, response.summary);
        System.assertEquals(1, [
            SELECT COUNT()
            FROM Security_Audit_Run__c
            WHERE Run_Key__c = :response.runKey
        ]);
    }

    @IsTest
    static void runSecurityAuditDirectStaysOnRequestedField() {
        Test.startTest();
        AiMetadataCopilotModels.SecurityAuditResponse response =
            AiMetadataCopilotController.runSecurityAuditDirect('Account.CustomerPriority__c');
        Test.stopTest();

        System.assertNotEquals(null, response.runKey);
        for (AiMetadataCopilotModels.SecurityFindingRow finding : response.findings) {
            System.assertEquals('Account', finding.objectApiName);
            System.assertEquals('CustomerPriority__c', finding.fieldApiName);
        }
    }

    @IsTest
    static void sensitiveClassificationReturnsExactConfiguredFieldScope() {
        Test.startTest();
        List<SensitiveDataClassificationService.SensitiveTarget> targets =
            new SensitiveDataClassificationService().getSensitiveTargets('Account', 'CustomerPriority__c');
        Test.stopTest();

        System.assertEquals(1, targets.size(), 'Expected the configured Account.CustomerPriority__c rule.');
        System.assertEquals('Account', targets[0].objectApiName);
        System.assertEquals('CustomerPriority__c', targets[0].fieldApiName);
    }

    @IsTest
    static void sensitiveClassificationFallsBackToRequestedObjectOnly() {
        Test.startTest();
        List<SensitiveDataClassificationService.SensitiveTarget> targets =
            new SensitiveDataClassificationService().getSensitiveTargets('Account', 'Unconfigured_Field__c');
        Test.stopTest();

        System.assertEquals(1, targets.size(), 'Object-qualified fallback should stay on the requested object.');
        System.assertEquals('Account', targets[0].objectApiName);
        System.assertEquals('Unconfigured_Field__c', targets[0].fieldApiName);
    }

    @IsTest
    static void fieldOnlySecurityScopeFallsBackToIndexedOwner() {
        insert new Metadata_Item__c(
            Name = 'Case.Unconfigured_Field__c',
            Metadata_Key__c = 'CustomField:Case.Unconfigured_Field__c',
            Metadata_Type__c = 'CustomField',
            Api_Name__c = 'Case.Unconfigured_Field__c',
            Developer_Name__c = 'Unconfigured_Field',
            Object_API_Name__c = 'Case',
            Field_API_Name__c = 'Unconfigured_Field__c',
            Status__c = 'Active',
            Last_Indexed_On__c = System.now()
        );

        Test.startTest();
        List<SensitiveDataClassificationService.SensitiveTarget> targets =
            new SensitiveDataClassificationService().getSensitiveTargets(null, 'Unconfigured_Field__c');
        Test.stopTest();

        System.assertEquals(1, targets.size(), 'Field-only fallback should use the indexed owning object.');
        System.assertEquals('Case', targets[0].objectApiName);
        System.assertEquals('Unconfigured_Field__c', targets[0].fieldApiName);
    }

    @IsTest
    static void fieldOnlySecurityScopeDoesNotExpandToAllBaselineObjectsWhenUnresolved() {
        Test.startTest();
        List<SensitiveDataClassificationService.SensitiveTarget> targets =
            new SensitiveDataClassificationService().getSensitiveTargets(null, 'Unindexed_Test_Field__c');
        Test.stopTest();

        System.assertEquals(
            0,
            targets.size(),
            'Unresolved field-only security audits should not scan every Health Cloud baseline object.'
        );
    }

    @IsTest
    static void runSecurityAuditDirectTrimsQualifiedFieldInput() {
        Test.startTest();
        AiMetadataCopilotModels.SecurityAuditResponse response =
            AiMetadataCopilotController.runSecurityAuditDirect('  Account.CustomerPriority__c  ');
        Test.stopTest();

        System.assert(response.findings.size() > 0, 'Expected security findings for trimmed qualified input.');
        for (AiMetadataCopilotModels.SecurityFindingRow finding : response.findings) {
            System.assertEquals('Account', finding.objectApiName);
            System.assertEquals('CustomerPriority__c', finding.fieldApiName);
        }
    }

    @IsTest
    static void compareEnvironmentsReturnsDeploymentAssessment() {
        Test.startTest();
        AiMetadataCopilotModels.DeploymentCompareResponse response =
            AiMetadataCopilotController.compareEnvironments(
                MetadataCopilotTestDataFactory.deploymentRequest()
            );
        Test.stopTest();

        System.assertNotEquals(null, response.assessmentKey);
        System.assertNotEquals(null, response.readinessScore);
        System.assert(response.findings.size() > 0, 'Expected snapshot comparison findings.');
        System.assert(response.rollbackChecklist.size() > 0, 'Expected rollback guidance.');
        System.assert(response.testChecklist.size() > 0, 'Expected test guidance.');
    }

    @IsTest
    static void generateDocumentationUsesIndexedMetadata() {
        Metadata_Item__c item = [
            SELECT Metadata_Key__c
            FROM Metadata_Item__c
            WHERE Metadata_Type__c = 'ApexClass'
            LIMIT 1
        ];

        Test.startTest();
        AiMetadataCopilotModels.DocumentationResponse response =
            AiMetadataCopilotController.generateDocumentation(
                MetadataCopilotTestDataFactory.documentationRequest(item.Metadata_Key__c)
            );
        Test.stopTest();

        System.assertNotEquals(null, response.requestId);
        System.assert(response.technicalSummary.contains('ApexClass'));
        System.assertNotEquals(null, response.businessSummary);
    }

    @IsTest
    static void runOptimizationScanReturnsGroundedFindings() {
        Test.setMock(HttpCalloutMock.class, new ToolingApiMock());

        Test.startTest();
        AiMetadataCopilotModels.OptimizationScanResponse response =
            AiMetadataCopilotController.runOptimizationScan(
                MetadataCopilotTestDataFactory.optimizationRequest()
            );
        Test.stopTest();

        System.assert(response.findings.size() > 0, 'Expected optimization findings.');
        System.assertNotEquals(null, response.summary);
    }

    @IsTest
    static void refreshMetadataIndexUsesToolingMock() {
        Test.setMock(HttpCalloutMock.class, new ToolingApiMock());

        Test.startTest();
        AiMetadataCopilotModels.RefreshResponse response =
            AiMetadataCopilotController.refreshMetadataIndex();
        Test.stopTest();

        System.assertNotEquals(null, response.snapshotKey);
        System.assert(response.indexedItems > 0, 'Expected indexed metadata items.');
        System.assert(response.usageRelationships >= 0, 'Expected usage relationship count.');
    }

    private static void insertFieldUsage(
        Metadata_Item__c sourceItem,
        String fieldName,
        String fieldKey,
        String objectApiName,
        String fieldApiName,
        String matchText
    ) {
        Metadata_Item__c fieldItem = new Metadata_Item__c(
            Name = fieldName,
            Metadata_Key__c = fieldKey,
            Metadata_Type__c = 'CustomField',
            Api_Name__c = fieldName,
            Developer_Name__c = fieldApiName.removeEnd('__c'),
            Object_API_Name__c = objectApiName,
            Field_API_Name__c = fieldApiName,
            Status__c = 'Active',
            Last_Indexed_On__c = System.now()
        );
        insert fieldItem;

        insert new Metadata_Usage__c(
            Usage_Key__c = sourceItem.Metadata_Key__c + '->UsesField:' + fieldName,
            Source_Metadata__c = sourceItem.Id,
            Target_Metadata__c = fieldItem.Id,
            Source_Key__c = sourceItem.Metadata_Key__c,
            Target_Key__c = fieldItem.Metadata_Key__c,
            Usage_Type__c = 'UsesField',
            Source_Type__c = 'ApexClass',
            Target_Type__c = 'CustomField',
            Match_Text__c = matchText,
            Context_Snippet__c = 'Matched token: ' + matchText,
            Last_Analyzed_On__c = System.now()
        );
    }

    private class ToolingApiMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest request) {
            HttpResponse response = new HttpResponse();
            response.setStatusCode(200);
            response.setHeader('Content-Type', 'application/json');
            response.setBody(buildBody(request.getEndpoint()));
            return response;
        }

        private String buildBody(String endpoint) {
            String decodedEndpoint = EncodingUtil.urlDecode(endpoint, 'UTF-8');
            if (decodedEndpoint.contains('FROM ApexClass')) {
                return JSON.serialize(new Map<String, Object>{
                    'totalSize' => 1,
                    'done' => true,
                    'records' => new List<Object>{
                        new Map<String, Object>{
                            'Id' => '01p000000000001AAA',
                            'Name' => 'CustomerPriorityDemoMock',
                            'NamespacePrefix' => null,
                            'Status' => 'Active',
                            'Body' => 'public class CustomerPriorityDemoMock { String idValue = \'001000000000001AAA\'; void m(){ System.debug(Account.CustomerPriority__c); } }'
                        }
                    }
                });
            }

            if (decodedEndpoint.contains('FROM Flow')) {
                return JSON.serialize(new Map<String, Object>{
                    'totalSize' => 2,
                    'done' => true,
                    'records' => new List<Object>{
                        new Map<String, Object>{
                            'Id' => '301000000000001AAA',
                            'MasterLabel' => 'Account Care Flow One',
                            'Status' => 'Active'
                        },
                        new Map<String, Object>{
                            'Id' => '301000000000002AAA',
                            'MasterLabel' => 'Account Care Flow Two',
                            'Status' => 'Active'
                        }
                    }
                });
            }

            return JSON.serialize(new Map<String, Object>{
                'totalSize' => 2,
                'done' => true,
                'records' => new List<Object>{
                    new Map<String, Object>{
                        'Id' => '00N000000000001AAA',
                        'DeveloperName' => 'CustomerPriority',
                        'NamespacePrefix' => null,
                        'TableEnumOrId' => 'Account'
                    },
                    new Map<String, Object>{
                        'Id' => '00N000000000002AAA',
                        'DeveloperName' => 'UnusedMockField',
                        'NamespacePrefix' => null,
                        'TableEnumOrId' => 'Account'
                    }
                }
            });
        }
    }
}
