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
