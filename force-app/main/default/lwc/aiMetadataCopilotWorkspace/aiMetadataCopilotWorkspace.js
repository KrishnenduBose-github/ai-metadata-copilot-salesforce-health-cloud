import { LightningElement } from 'lwc';
import refreshMetadataIndex from '@salesforce/apex/AiMetadataCopilotController.refreshMetadataIndex';
import searchMetadata from '@salesforce/apex/AiMetadataCopilotController.searchMetadata';
import searchMetadataDirect from '@salesforce/apex/AiMetadataCopilotController.searchMetadataDirect';
import analyzeImpact from '@salesforce/apex/AiMetadataCopilotController.analyzeImpact';
import analyzeImpactDirect from '@salesforce/apex/AiMetadataCopilotController.analyzeImpactDirect';
import runSecurityAudit from '@salesforce/apex/AiMetadataCopilotController.runSecurityAudit';
import runSecurityAuditDirect from '@salesforce/apex/AiMetadataCopilotController.runSecurityAuditDirect';
import compareEnvironments from '@salesforce/apex/AiMetadataCopilotController.compareEnvironments';
import runOptimizationScan from '@salesforce/apex/AiMetadataCopilotController.runOptimizationScan';
import checkHealth from '@salesforce/apex/AiMetadataCopilotController.checkHealth';

export default class AiMetadataCopilotWorkspace extends LightningElement {
    activeTab = 'search';
    isLoading = false;
    errorMessage = '';

    searchMode = 'simple';
    impactMode = 'simple';
    searchPrompt = '';
    impactPrompt = '';
    searchQueryText = '';
    searchQueryType = 'FieldUsage';
    impactQueryText = '';
    impactQueryType = 'FieldUsage';
    securityPrompt = '';
    safetyFilter = true;
    sourceEnvironment = 'Current Sandbox';
    targetEnvironment = 'Previous Snapshot';

    searchResponse;
    impactResponse;
    securityResponse;
    deploymentResponse;
    optimizationResponse;
    healthStatus;
    refreshResult;

    queryTypeOptions = [
        { label: 'Field Usage', value: 'FieldUsage' },
        { label: 'Object Usage', value: 'ObjectUsage' }
    ];

    modeOptions = [
        { label: 'Direct API Name', value: 'simple' },
        { label: 'Natural Language', value: 'natural' }
    ];

    searchColumns = [
        { label: 'Source Name', fieldName: 'metadataName' },
        { label: 'Metadata Type', fieldName: 'metadataType' },
        { label: 'Usage Type', fieldName: 'usageType' },
        { label: 'Target', fieldName: 'metadataKey' },
        { label: 'Context', fieldName: 'context' }
    ];

    securityColumns = [
        { label: 'Finding Type', fieldName: 'findingType' },
        { label: 'Severity', fieldName: 'severity' },
        { label: 'Object', fieldName: 'objectApiName' },
        { label: 'Field', fieldName: 'fieldApiName' },
        { label: 'Permission', fieldName: 'permissionArtifact' },
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
        { label: 'Summary', fieldName: 'summary' }
    ];

    get hasSearchResults() {
        return this.searchResponse && this.searchResponse.matchedComponents && this.searchResponse.matchedComponents.length > 0;
    }

    get hasImpactResults() {
        return this.impactResponse && this.impactResponse.impactedComponents && this.impactResponse.impactedComponents.length > 0;
    }

    get hasSecurityResults() {
        return this.securityResponse && this.securityResponse.findings && this.securityResponse.findings.length > 0;
    }

    get hasDeploymentResults() {
        return this.deploymentResponse && this.deploymentResponse.findings && this.deploymentResponse.findings.length > 0;
    }

    get hasOptimizationResults() {
        return this.optimizationResponse && this.optimizationResponse.findings && this.optimizationResponse.findings.length > 0;
    }

    get healthSummary() {
        if (!this.healthStatus) return 'Loading...';
        const h = this.healthStatus;
        return `Items: ${h.indexedItemCount || 0} | Relationships: ${h.usageRecordCount || 0} | Snapshots: ${h.snapshotCount || 0}`;
    }

    get refreshStatusClass() {
        if (!this.refreshResult) return 'alert alert-success';
        return this.refreshResult.status === 'Success' ? 'alert alert-success' : 'alert alert-warn';
    }

    get refreshSummary() {
        if (!this.refreshResult) return '';
        const status = this.refreshResult.status || 'Success';
        return `${status}: ${this.refreshResult.indexedItems || 0} indexed, ${this.refreshResult.usageRelationships || 0} relationships`;
    }

    get refreshWarning() {
        return this.refreshResult && this.refreshResult.warningSummary ? this.refreshResult.warningSummary : '';
    }

    get isSearchSimple() { return this.searchMode === 'simple'; }
    get isImpactSimple() { return this.impactMode === 'simple'; }

    connectedCallback() {
        this.loadHealthStatus();
    }

    handleTabChange(event) { this.activeTab = event.target.value; }
    handleSearchModeChange(event) { this.searchMode = this.readInput(event); }
    handleImpactModeChange(event) { this.impactMode = this.readInput(event); }

    handleSearchPromptChange(event) { this.searchPrompt = this.readInput(event); }
    handleImpactPromptChange(event) { this.impactPrompt = this.readInput(event); }
    handleSearchQueryTextChange(event) { this.searchQueryText = this.readInput(event); }
    handleSearchQueryTypeChange(event) { this.searchQueryType = this.readInput(event); }
    handleImpactQueryTextChange(event) { this.impactQueryText = this.readInput(event); }
    handleImpactQueryTypeChange(event) { this.impactQueryType = this.readInput(event); }
    handleSecurityPromptChange(event) { this.securityPrompt = this.readInput(event); }
    handleSourceEnvChange(event) { this.sourceEnvironment = this.readInput(event); }
    handleTargetEnvChange(event) { this.targetEnvironment = this.readInput(event); }

    readInput(event) {
        if (event && event.detail && event.detail.value !== undefined) return event.detail.value;
        return event && event.target ? event.target.value : '';
    }

    readField(fieldName, fallbackValue) {
        const input = this.template.querySelector(`[data-field="${fieldName}"]`);
        if (input && input.value !== undefined) return input.value;
        return fallbackValue || '';
    }

    syncCurrentInputs() {
        this.searchPrompt = this.readField('searchPrompt', this.searchPrompt);
        this.impactPrompt = this.readField('impactPrompt', this.impactPrompt);
        this.searchQueryText = this.readField('searchQueryText', this.searchQueryText);
        this.searchQueryType = this.readField('searchQueryType', this.searchQueryType);
        this.impactQueryText = this.readField('impactQueryText', this.impactQueryText);
        this.impactQueryType = this.readField('impactQueryType', this.impactQueryType);
        this.securityPrompt = this.readField('securityPrompt', this.securityPrompt);
        this.sourceEnvironment = this.readField('sourceEnvironment', this.sourceEnvironment);
        this.targetEnvironment = this.readField('targetEnvironment', this.targetEnvironment);
    }

    async loadHealthStatus() {
        try {
            this.healthStatus = await checkHealth();
        } catch (error) {
            this.healthStatus = { isHealthy: false, indexedItemCount: 0, usageRecordCount: 0, warnings: [this.reduceError(error)], recommendations: [] };
        }
    }

    async handleRefresh() {
        this.refreshResult = null;
        await this.runOp(async () => {
            this.refreshResult = await refreshMetadataIndex();
        });
        await this.loadHealthStatus();
    }

    async handleSearch() {
        await this.runOp(async () => {
            this.syncCurrentInputs();
            if (this.isSearchSimple) {
                const queryText = this.searchQueryText ? this.searchQueryText.trim() : '';
                if (!queryText) {
                    throw new Error('Enter a field or object API name.');
                }
                this.searchResponse = await searchMetadataDirect({
                    queryText,
                    queryType: this.searchQueryType
                });
            } else {
                const userPrompt = this.searchPrompt ? this.searchPrompt.trim() : '';
                if (!userPrompt) {
                    throw new Error('Enter a metadata question.');
                }
                this.searchResponse = await searchMetadata({
                    request: { userPrompt }
                });
            }
        }, () => { this.searchResponse = null; });
    }

    async handleImpact() {
        await this.runOp(async () => {
            this.syncCurrentInputs();
            if (this.isImpactSimple) {
                const queryText = this.impactQueryText ? this.impactQueryText.trim() : '';
                if (!queryText) {
                    throw new Error('Enter a field or object API name.');
                }
                this.impactResponse = await analyzeImpactDirect({
                    queryText,
                    queryType: this.impactQueryType
                });
            } else {
                const userPrompt = this.impactPrompt ? this.impactPrompt.trim() : '';
                if (!userPrompt) {
                    throw new Error('Enter an impact question.');
                }
                this.impactResponse = await analyzeImpact({
                    request: { userPrompt }
                });
            }
        }, () => { this.impactResponse = null; });
    }

    async handleSecurity() {
        await this.runOp(async () => {
            this.syncCurrentInputs();
            const userPrompt = this.securityPrompt ? this.securityPrompt.trim() : '';
            if (!userPrompt) {
                throw new Error('Enter a security question or field name.');
            }
            this.securityResponse = await runSecurityAuditDirect({ userPrompt });
        }, () => { this.securityResponse = null; });
    }

    async handleDeploymentCompare() {
        await this.runOp(async () => {
            this.syncCurrentInputs();
            const sourceEnvironment = this.sourceEnvironment ? this.sourceEnvironment.trim() : '';
            const targetEnvironment = this.targetEnvironment ? this.targetEnvironment.trim() : '';
            if (!sourceEnvironment) throw new Error('Enter a source environment.');
            if (!targetEnvironment) throw new Error('Enter a target environment.');
            this.deploymentResponse = await compareEnvironments({
                request: {
                    sourceEnvironment,
                    targetEnvironment
                }
            });
        }, () => { this.deploymentResponse = null; });
    }

    async handleOptimization() {
        await this.runOp(async () => {
            this.optimizationResponse = await runOptimizationScan({ request: { scanType: 'Full' } });
        }, () => { this.optimizationResponse = null; });
    }

    async runOp(operation, onError) {
        this.isLoading = true;
        this.errorMessage = '';
        try {
            await operation();
        } catch (error) {
            if (onError) onError();
            this.errorMessage = this.reduceError(error);
        } finally {
            this.isLoading = false;
        }
    }

    reduceError(error) {
        if (error && error.body && error.body.message) return error.body.message;
        if (error && error.message) return error.message;
        return 'An unexpected error occurred.';
    }
}
