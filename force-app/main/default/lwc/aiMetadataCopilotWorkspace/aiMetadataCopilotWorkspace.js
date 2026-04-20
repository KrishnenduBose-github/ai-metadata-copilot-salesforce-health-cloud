import { LightningElement } from 'lwc';
import refreshMetadataIndex from '@salesforce/apex/AiMetadataCopilotController.refreshMetadataIndex';
import searchMetadata from '@salesforce/apex/AiMetadataCopilotController.searchMetadata';
import analyzeImpact from '@salesforce/apex/AiMetadataCopilotController.analyzeImpact';
import runSecurityAudit from '@salesforce/apex/AiMetadataCopilotController.runSecurityAudit';
import compareEnvironments from '@salesforce/apex/AiMetadataCopilotController.compareEnvironments';
import generateDocumentation from '@salesforce/apex/AiMetadataCopilotController.generateDocumentation';
import runOptimizationScan from '@salesforce/apex/AiMetadataCopilotController.runOptimizationScan';

export default class AiMetadataCopilotWorkspace extends LightningElement {
    activeTab = 'search';
    isLoading = false;
    errorMessage = '';
    refreshMessage = '';

    searchPrompt = '';
    impactPrompt = '';
    securityPrompt = '';
    sourceEnvironment = 'Current Sandbox';
    targetEnvironment = 'Previous Snapshot';
    documentationMetadataKey = '';
    documentationRequestType = 'ExplainComponent';

    searchResponse;
    impactResponse;
    securityResponse;
    deploymentResponse;
    documentationResponse;
    optimizationResponse;

    searchColumns = [
        { label: 'Metadata Name', fieldName: 'metadataName' },
        { label: 'Metadata Type', fieldName: 'metadataType' },
        { label: 'Usage Type', fieldName: 'usageType' },
        { label: 'Target Key', fieldName: 'metadataKey' },
        { label: 'Context', fieldName: 'context' }
    ];

    securityColumns = [
        { label: 'Finding Type', fieldName: 'findingType' },
        { label: 'Severity', fieldName: 'severity' },
        { label: 'Object', fieldName: 'objectApiName' },
        { label: 'Field', fieldName: 'fieldApiName' },
        { label: 'Permission Artifact', fieldName: 'permissionArtifact' },
        { label: 'Summary', fieldName: 'summary' }
    ];

    deploymentColumns = [
        { label: 'Finding Type', fieldName: 'findingType' },
        { label: 'Severity', fieldName: 'severity' },
        { label: 'Metadata Key', fieldName: 'metadataKey' },
        { label: 'Summary', fieldName: 'summary' },
        { label: 'Recommendation', fieldName: 'recommendation' }
    ];

    optimizationColumns = [
        { label: 'Finding Type', fieldName: 'findingType' },
        { label: 'Severity', fieldName: 'severity' },
        { label: 'Metadata Key', fieldName: 'metadataKey' },
        { label: 'Summary', fieldName: 'summary' },
        { label: 'Recommendation', fieldName: 'recommendation' }
    ];

    documentationTypeOptions = [
        { label: 'Explain Component', value: 'ExplainComponent' },
        { label: 'Release Note', value: 'ReleaseNote' }
    ];

    handleTabChange(event) {
        this.activeTab = event.target.value;
    }

    handleSearchPromptChange(event) {
        this.searchPrompt = event.target.value;
    }

    handleImpactPromptChange(event) {
        this.impactPrompt = event.target.value;
    }

    handleSecurityPromptChange(event) {
        this.securityPrompt = event.target.value;
    }

    handleSourceEnvironmentChange(event) {
        this.sourceEnvironment = event.target.value;
    }

    handleTargetEnvironmentChange(event) {
        this.targetEnvironment = event.target.value;
    }

    handleDocumentationMetadataKeyChange(event) {
        this.documentationMetadataKey = event.target.value;
    }

    handleDocumentationTypeChange(event) {
        this.documentationRequestType = event.detail.value;
    }

    async handleRefresh() {
        await this.runAsync(async () => {
            const result = await refreshMetadataIndex();
            this.refreshMessage =
                'Refresh completed. Snapshot ' + result.snapshotKey +
                ' indexed ' + result.indexedItems +
                ' item(s) and created ' + result.usageRelationships +
                ' usage relationship(s).';

            if (result.messages && result.messages.length > 0) {
                this.errorMessage = result.messages.join(' | ');
            }
        });
    }

    async handleSearch() {
        await this.runAsync(async () => {
            this.searchResponse = await searchMetadata({
                request: {
                    userPrompt: this.searchPrompt
                }
            });
        });
    }

    async handleImpact() {
        await this.runAsync(async () => {
            this.impactResponse = await analyzeImpact({
                request: {
                    userPrompt: this.impactPrompt
                }
            });
        });
    }

    async handleSecurity() {
        await this.runAsync(async () => {
            this.securityResponse = await runSecurityAudit({
                request: {
                    userPrompt: this.securityPrompt
                }
            });
        });
    }

    async handleDeploymentCompare() {
        await this.runAsync(async () => {
            this.deploymentResponse = await compareEnvironments({
                request: {
                    sourceEnvironment: this.sourceEnvironment,
                    targetEnvironment: this.targetEnvironment
                }
            });
        });
    }

    async handleDocumentation() {
        await this.runAsync(async () => {
            this.documentationResponse = await generateDocumentation({
                request: {
                    metadataKey: this.documentationMetadataKey,
                    requestType: this.documentationRequestType
                }
            });
        });
    }

    async handleOptimization() {
        await this.runAsync(async () => {
            this.optimizationResponse = await runOptimizationScan({
                request: {
                    scanType: 'Full'
                }
            });
        });
    }

    async runAsync(operation) {
        this.isLoading = true;
        this.errorMessage = '';
        this.refreshMessage = '';

        try {
            await operation();
        } catch (error) {
            this.errorMessage = this.reduceError(error);
        } finally {
            this.isLoading = false;
        }
    }

    reduceError(error) {
        if (error && error.body && error.body.message) {
            return error.body.message;
        }

        if (error && error.message) {
            return error.message;
        }

        return 'An unexpected error occurred.';
    }
}
